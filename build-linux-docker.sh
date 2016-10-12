#!/bin/sh

version=`grep Version main.go | egrep -o '\d+\.\d+\.\d+'`
target="runx-linux-x64-$version"
docker build -t runx .
docker run -it runx
id=`docker ps -l -q`
docker cp $id:/src/runx "./$target"
docker rm $id
docker run -it --rm -v "`pwd`/$target":/bin/runx golang:1-wheezy bash
docker rmi runx:latest
