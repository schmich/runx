package main

import (
  "fmt"
  "io/ioutil"
  "path"
  "time"
  "os"
  "os/exec"
  "errors"
  "github.com/mitchellh/go-homedir"
)

var version string
var commit string
var payloadHash string

func delay(fn func(), delay time.Duration) chan<- bool {
  cancel := make(chan bool, 1)

  go func () {
    wait := make(chan bool)
    go func () {
      time.Sleep(delay)
      wait <- true
      close(wait)
    }()

    select {
    case <-wait:
      fn()
    case <-cancel:
    }
  }()

  return cancel
}

func deployRuntime() (string, error) {
  if len(payloadHash) == 0 {
    return "", errors.New("Invalid payload hash.")
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
    if file.IsDir() && file.Name() != payloadHash {
      remove := path.Join(runxHome, file.Name())
      os.RemoveAll(remove)
    }
  }

  dir := path.Join(runxHome, payloadHash)
  err = os.Mkdir(dir, 0700)
  if os.IsExist(err) {
    return dir, nil
  }

  cancel := delay(func () {
    log.Println("Preparing for first use.")
  }, 500 * time.Millisecond)

  err = RestoreAssets(dir, "runtime")
  cancel <- true

  if err != nil {
    return "", err
  }

  return dir, nil
}

func main() {
  // We exclude the first argument since it's just the current process path.
  args := os.Args[1:]
  if len(args) == 1 && (args[0] == "-v" || args[0] == "--version") {
    fmt.Fprintln(os.Stderr, "runx", version, commit)
    return
  }

  dir, err := deployRuntime()
  if err != nil {
    log.Fatal(err)
    return
  }

  ruby := setupRuntime(dir)
  script := path.Join(dir, "runtime", "lib", "app", "runx.rb")
  args = append([]string{script}, args...)

  cmd := exec.Command(ruby, args...)
  cmd.Stdout = os.Stdout
  cmd.Stderr = os.Stderr
  cmd.Stdin = os.Stdin
  cmd.Run()
}
