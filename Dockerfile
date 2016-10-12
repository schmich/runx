FROM golang:1-wheezy
MAINTAINER Chris Schmich <schmch@gmail.com>
RUN go get github.com/kardianos/osext \
 && go get github.com/mitchellh/go-homedir \
 && go get github.com/jteeuwen/go-bindata/...
WORKDIR /src
CMD ["/bin/bash", "-c", "/src/build-linux.sh"]
