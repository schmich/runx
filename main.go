package main

import (
  "log"
  "io"
  "io/ioutil"
  "path"
  "os"
  "os/exec"
  "os/signal"
  "hash/fnv"
  "encoding/hex"
  "github.com/kardianos/osext"
  "github.com/mitchellh/go-homedir"
)

func selfDigest() (string, error) {
  var result []byte
  fileName, err := osext.Executable()
  if err != nil {
    return "", err
  }

  file, err := os.Open(fileName)
  if err != nil {
    return "", err
  }
  defer file.Close()

  hash := fnv.New64a()
  if _, err := io.Copy(hash, file); err != nil {
    return "", err
  }

  result = hash.Sum(result)
  digest := hex.EncodeToString(result)

  return digest, nil
}

func deployRuntime() (string, error) {
  digest, err := selfDigest()
  if err != nil {
    return "", err
  }

  home, err := homedir.Dir()
  if err != nil {
    return "", err
  }

  runxHome := path.Join(home, ".runx")
  err = os.Mkdir(runxHome, 0700)
  if err != nil && !os.IsExist(err) {
    return "", err
  }

  files, err := ioutil.ReadDir(runxHome)
  if err != nil {
    return "", err
  }

  for _, file := range files {
    if file.IsDir() && file.Name() != digest {
      remove := path.Join(runxHome, file.Name())
      os.RemoveAll(remove)
    }
  }

  dir := path.Join(runxHome, digest)
  err = os.Mkdir(dir, 0700)
  if os.IsExist(err) {
    return dir, nil
  } else {
    err = RestoreAssets(dir, "runtime")
    if err != nil {
      return "", err
    }

    return dir, nil
  }
}

func main() {
  dir, err := deployRuntime()
  if err != nil {
    log.Fatal(err)
    return
  }

  ruby := setupRuntime(dir)
  script := path.Join(dir, "runtime", "lib", "app", "runx.rb")

  // We want to run "ruby runx.rb [args...]".
  // We exclude the first argument to this process since it's just self.
  args := append([]string{script}, os.Args[1:]...)

  var cmd *exec.Cmd

  interrupt := make(chan os.Signal, 1)
  signal.Notify(interrupt, os.Interrupt)
  go func() {
    <-interrupt
    if cmd != nil {
      cmd.Process.Kill()
    }
  }()

  cmd = exec.Command(ruby, args...)
  cmd.Stdout = os.Stdout
  cmd.Stderr = os.Stderr
  cmd.Stdin = os.Stdin
  cmd.Run()
}
