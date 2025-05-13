# Makefile for kbot project

# Go parameters
GO      := go
# Go LDFLAGS to strip debug symbols and DWARF info, reducing binary size.
WITHDOCKER ?= false
REPO	:= github.dev/devops101-prom
VERSION=$(shell git describe --tags --abbrev=0)-$(shell git rev-parse --short HEAD)
LDFLAGS := "-s -w  -X=github.dev/DEVOPS101-PROM/kbot/cmd.appVersion=${VERSION}"
APP_NAME   := kbot
OUTPUT_DIR := ./bin

# Default target when 'make' is run without arguments
.DEFAULT_GOAL := all

# Define all target OS/Arch combinations
# Format: <os>-<arch>
TARGET_PLATFORMS := \
	linux/amd64 \
	linux/arm64 \
	darwin/amd64 \
	darwin/arm64 \
	windows/amd64 \
	windows/arm64

all: 
	@echo "Allowed target OS/Arch combinations:"
	
	@for targets in $(TARGET_PLATFORMS) ; do \
	echo $$targets ; \
	done
	@echo "\nRUN ~build-all~ for build all allowed target OS/Arch combinations"

# Rule to create the output directory if it doesn't exist
$(OUTPUT_DIR):
	@echo "Creating output directory: $(OUTPUT_DIR)"
	@mkdir -p $@

# Generic build rule template for Go binaries
# $(1) = OS, $(2) = ARCH
define GO_BUILD_template
$(1)/$(2): $$(OUTPUT_DIR) install-dep
	@echo "Building $(APP_NAME) for $(1)/$(2)..."
	@GOOS=$(1) GOARCH=$(2) CGO_ENABLED=0 $(GO) build -ldflags=$(LDFLAGS) -o $(OUTPUT_DIR)/$(APP_NAME)-$(1)-$(2)$(if $(filter windows,$(1)),.exe) .
	@if [ "$(WITHDOCKER)" = "true" ]; then \
		echo "Building Docker image for $(1)/$(2)..." ; \
		docker buildx build -f Dockerfile.mk --platform=$(1)/$(2) --build-arg TARGETOS=$(1) --build-arg TARGETARCH=$(2) -t $(REPO)/$(APP_NAME):$(VERSION).$(1)-$(2) . --load ; \
		echo "imge: $(REPO)/$(APP_NAME):$(VERSION).$(1)-$(2)"; \
	else \
		echo "Docker build skipped."; \
	fi
	@echo "Build for $(1)/$(2) complete." 
endef
# .$(1)-$(2)
#	@GOOS=$(1) GOARCH=$(2) CGO_ENABLED=0 $(GO) build -ldflags=$(LDFLAGS) -o $(OUTPUT_DIR)/$(APP_NAME)-$(1)-$(2)$(if $(filter windows,$(1)),.exe) .
# Phony target 'build-all' to build all defined target platforms
# build-all: $(patsubst %,build-%,$(TARGET_PLATFORMS))

# Instantiate the generic build rule for each target platform
$(foreach pair,$(TARGET_PLATFORMS),$(eval $(call GO_BUILD_template,$(firstword $(subst /, ,$(pair))),$(lastword $(subst /, ,$(pair))))))

# Install GO dependencies 
install-dep: 
	go get
# Alias targets for convenience

# 'make linux' will build for linux-amd64
linux: install-dep linux/amd64
	@echo "Alias 'linux' ensured linux/amd64 build."
# 'make linux/amd64' will build for linux/amd64
arm: linux/arm64
	@echo "Alias 'arm' ensured linux/arm64 build."
windows: windows/amd64
	@echo "Alias 'windows' ensured windows/amd64 build."
macos: darwin/amd64
	@echo "Alias 'macos' ensured darwin/amd64 build."

# Target to run Go tests
test:
	@echo "Running Go tests..."
	$(GO) test -v ./...

docker-push:
	@echo "Pushing Docker image to registry..."
	@docker push $(APP_NAME):$(VERSION).$(1)-$(2)
	@echo "Docker image pushed."
# Target to clean up build artifacts
clean:
	@echo "Cleaning up build artifacts..."
	@rm -rf $(OUTPUT_DIR) || true
	@if [ "$(IMG-RM)" = "true" ]; then \
		echo "RM Docker image $(REPO)/$(APP_NAME):$(VERSION)" ; \
		docker image ls $(REPO)/$(APP_NAME):$(VERSION)* -aq ; \
		docker rmi -f $$(docker image ls $(REPO)/$(APP_NAME):$(VERSION)* -aq ) || true; \
	fi

# Declare phony targets (targets that are not files)
.PHONY: all test clean linux arm macos windows $(patsubst %,build-%,$(TARGET_PLATFORMS))

