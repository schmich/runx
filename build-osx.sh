#!/bin/sh

set -x

if [ ! -d runtime ]; then
  mkdir -p runtime/lib/ruby
  mkdir -p runtime/lib/app
  curl -L --fail https://d6r77u77i8pq3.cloudfront.net/releases/traveling-ruby-20141215-2.1.5-osx.tar.gz | tar -zxv -C runtime/lib/ruby
fi

cp runx.rb runtime/lib/app/runx.rb
go-bindata runtime/...
go build
