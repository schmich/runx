#!/bin/sh

set -x

package=traveling-ruby-20150210-2.1.5-osx.tar.gz

if [ ! -d runtime ]; then
  mkdir -p runtime/lib/ruby
  mkdir -p runtime/lib/app
  curl -L --fail "https://d6r77u77i8pq3.cloudfront.net/releases/$package" | tar -zxv -C runtime/lib/ruby
fi

cp runx.rb runtime/lib/app/runx.rb
go-bindata runtime/...
go build -ldflags "-w -s"
