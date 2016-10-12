#!/bin/sh

docker build -t runx .
docker run -it --rm -v `pwd`:/src runx
docker run -it --rm -v `pwd`/runx:/bin/runx golang:1-wheezy bash
