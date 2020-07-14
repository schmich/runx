FROM golang:latest

MAINTAINER Chris Schmich <schmch@gmail.com>

RUN go get github.com/mitchellh/go-homedir \
 && go get github.com/jteeuwen/go-bindata/... \
 && apt-get update \
 && apt-get install -y ruby

WORKDIR /src

CMD ["/bin/sh"]
