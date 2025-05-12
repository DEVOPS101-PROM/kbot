VERSION=$(shell git describe --tags --abbrev=0)-$(shell git rev-parse --short HEAD)
TARGETOS=linux
RAWARCH=$(shell uname -i)
ARCH=$(shell if [ $(RAWARCH) = 'x86_64' ]; then echo 'amd64'; fi)

format:
	gofmt -s -w ./

lint:
	golint

install-dep:
	go get

test: 
	go test -v

build: format install-dep

	CGO_ENABLE=0 GOOS=$(TARGETOS) GOARCH=$(ARCH) go build -v -o kbot -ldflags "-X="github.dev/DEVOPS101-PROM/kbot/cmd.appVersion=${VERSION}

clean: 
	rm -rf kbot
