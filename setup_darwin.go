package main

import (
  "strings"
  "path"
  "os"
)

func setupRuntime(dir string) string {
  root := path.Join(dir, "runtime", "lib", "ruby")
  ruby := path.Join(root, "bin.real", "ruby")

  version := "2.1.0"
  arch := "x86_64-darwin13.0"

  os.Setenv("RUNX_DYLD_LIBRARY_PATH", os.Getenv("DYLD_LIBRARY_PATH"))
  os.Setenv("RUNX_TERMINFO", os.Getenv("TERMINFO"))
  os.Setenv("RUNX_SSL_CERT_DIR", os.Getenv("SSL_CERT_DIR"))
  os.Setenv("RUNX_SSL_CERT_FILE", os.Getenv("SSL_CERT_FILE"))
  os.Setenv("RUNX_RUBYOPT", os.Getenv("RUBYOPT"))
  os.Setenv("RUNX_RUBYLIB", os.Getenv("RUBYLIB"))
  os.Setenv("RUNX_GEM_HOME", os.Getenv("GEM_HOME"))
  os.Setenv("RUNX_GEM_PATH", os.Getenv("GEM_PATH"))
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
