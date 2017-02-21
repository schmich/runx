FROM golang:latest
MAINTAINER Chris Schmich <schmch@gmail.com>
RUN go get github.com/mitchellh/go-homedir \
 && go get github.com/jteeuwen/go-bindata/...
COPY . /src
WORKDIR /src
CMD ["/bin/bash", "-c", "/src/build-linux.sh"]
