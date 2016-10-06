package main

import (
  "strings"
  "log"
  "io"
  "path"
  "os"
  "os/exec"
  "os/signal"
  "hash/fnv"
  "encoding/hex"
  "github.com/kardianos/osext"
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

  runxDir := "runx-" + digest
  dir := path.Join(os.TempDir(), runxDir)
  err = os.Mkdir(dir, 0700)
  if os.IsExist(err) {
    return dir, nil
  } else {
    err = RestoreAssets(dir, "win32")
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

  ruby := path.Join(dir, "win32", "lib", "ruby", "bin.real", "ruby.exe")
  script := path.Join(dir, "win32", "lib", "app", "runx.rb")

  version := "2.1.0"
  arch := "i386-mingw32"

  rubyLib := strings.Join([]string{
    path.Join(dir, "win32", "lib", "ruby", "lib", "ruby", "site_ruby", version),
    path.Join(dir, "win32", "lib", "ruby", "lib", "ruby", "site_ruby", version, arch),
    path.Join(dir, "win32", "lib", "ruby", "lib", "ruby", "site_ruby"),
    path.Join(dir, "win32", "lib", "ruby", "lib", "ruby", "vendor_ruby", version),
    path.Join(dir, "win32", "lib", "ruby", "lib", "ruby", "vendor_ruby", version, arch),
    path.Join(dir, "win32", "lib", "ruby", "lib", "ruby", "vendor_ruby"),
    path.Join(dir, "win32", "lib", "ruby", "lib", "ruby", version),
    path.Join(dir, "win32", "lib", "ruby", "lib", "ruby", version, arch),
  }, ";")
  os.Setenv("RUBYLIB", rubyLib) 

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
