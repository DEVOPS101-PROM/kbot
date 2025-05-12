APP=$(shell basename $(shell git remote	get-url origin))
REGISTRY=tirtxika
VERSION=$(shell git describe --tags --abbrev=0)-$(shell git rev-parse --short HEAD)

TARGETOS=linux #linux windows darwin
TARGETARCH=amd64 #arm64 or autoselect -> $(shell if [ $(shell uname -i) = 'x86_64' ]; then echo 'amd64'; fi)

format:
	gofmt -s -w ./

lint:
	golint

install-dep:
	go get

test: 
	go test -v

build: format install-dep

	CGO_ENABLED=0 GOOS=$(TARGETOS) GOARCH=$(TARGETARCH) go build -v -o kbot -ldflags "-X="github.dev/DEVOPS101-PROM/kbot/cmd.appVersion=${VERSION}

image:
	docker build . -t $(REGISTRY)/$(APP):$(VERSION)-$(TARGETARCH)
push:
	docker push $(REGISTRY)/$(APP):$(VERSION)-$(TARGETARCH)
clean: 
	rm -rf kbot
