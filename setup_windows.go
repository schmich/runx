package main

import (
  "strings"
  "path"
  "os"
)

func setupRuntime(dir string) string {
  root := path.Join(dir, "runtime", "lib", "ruby")
  ruby := path.Join(root, "bin.real", "ruby.exe")

  version := "2.1.0"
  arch := "i386-mingw32"

  os.Setenv("RUNX_RUBYLIB", os.Getenv("RUBYLIB"))

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

