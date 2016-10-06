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

  dir := path.Join(home, ".runx", digest)
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

func setupWin32(dir string) string {
  root := path.Join(dir, "runtime", "lib", "ruby")
  ruby := path.Join(root, "bin.real", "ruby.exe")

  version := "2.1.0"
  arch := "i386-mingw32"

  rubyLib := strings.Join([]string{
    path.Join(root, "lib", "ruby", "site_ruby", version),
    path.Join(root, "lib", "ruby", "site_ruby", version, arch),
    path.Join(root, "lib", "ruby", "site_ruby"),
    path.Join(root, "lib", "ruby", "vendor_ruby", version),
    path.Join(root, "lib", "ruby", "vendor_ruby", version, arch),
    path.Join(root, "lib", "ruby", "vendor_ruby"),
    path.Join(root, "lib", "ruby", version),
    path.Join(root, "lib", "ruby", version, arch),
  }, ";")
  os.Setenv("RUBYLIB", rubyLib)

  return ruby
}

func setupOsx(dir string) string {
  root := path.Join(dir, "runtime", "lib", "ruby")
  ruby := path.Join(root, "bin.real", "ruby")

  version := "2.1.0"
  arch := "x86_64-darwin13.0"

  os.Setenv("ORIG_DYLD_LIBRARY_PATH", os.Getenv("LD_LIBRARY_PATH"))
  os.Setenv("ORIG_TERMINFO", os.Getenv("TERMINFO"))
  os.Setenv("ORIG_SSL_CERT_DIR", os.Getenv("SSL_CERT_DIR"))
  os.Setenv("ORIG_SSL_CERT_FILE", os.Getenv("SSL_CERT_FILE"))
  os.Setenv("ORIG_RUBYOPT", os.Getenv("RUBYOPT"))
  os.Setenv("ORIG_RUBYLIB", os.Getenv("RUBYLIB"))
  os.Unsetenv("DYLD_LIBRARY_PATH")
  os.Setenv("TERMINFO", "/usr/share/terminfo")
  os.Unsetenv("SSL_CERT_DIR")
  os.Setenv("SSL_CERT_FILE", path.Join(root, "lib", "ca-bundle.crt"))
  os.Setenv("RUBYOPT", "-r" + path.Join(root, "lib", "restore_environment"))
  os.Setenv("GEM_HOME", path.Join(root, "lib", "ruby", "gems", version))
  os.Setenv("GEM_PATH", path.Join(root, "lib", "ruby", "gems", version))

  rubyLib := strings.Join([]string{
    path.Join(root, "lib", "ruby", "site_ruby", version),
    path.Join(root, "lib", "ruby", "site_ruby", version, arch),
    path.Join(root, "lib", "ruby", "site_ruby"),
    path.Join(root, "lib", "ruby", "vendor_ruby", version),
    path.Join(root, "lib", "ruby", "vendor_ruby", version, arch),
    path.Join(root, "lib", "ruby", "vendor_ruby"),
    path.Join(root, "lib", "ruby", version),
    path.Join(root, "lib", "ruby", version, arch),
  }, ":")
  os.Setenv("RUBYLIB", rubyLib)

  return ruby
}

func main() {
  dir, err := deployRuntime()
  if err != nil {
    log.Fatal(err)
    return
  }

  ruby := setupOsx(dir)
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
