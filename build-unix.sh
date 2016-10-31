#!/bin/sh

set -x

package=$1

if [ ! -d runtime ]; then
  mkdir -p runtime/lib/ruby
  mkdir -p runtime/lib/app
  curl -L --fail "https://d6r77u77i8pq3.cloudfront.net/releases/$package" | tar -zxv -C runtime/lib/ruby
fi

cp runx.rb runtime/lib/app/runx.rb
go-bindata runtime/...

version=`git tag | tail -n1`
commit=`git rev-parse HEAD`
payloadHash=`shasum -a 256 bindata.go | awk '{ print $1 }' | head -c 8`
go build -ldflags "-w -s -X main.version=$version -X main.commit=$commit -X main.payloadDir=$version.$payloadHash" -o runx
