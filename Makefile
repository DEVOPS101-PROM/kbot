# Makefile for kbot project

# Go parameters
GO      := go
# Go LDFLAGS to strip debug symbols and DWARF info, reducing binary size.

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
$(1)/$(2): $$(OUTPUT_DIR) clean install-dep
	@echo "Building $(APP_NAME) for $(1)/$(2)..."
	@GOOS=$(1) GOARCH=$(2) CGO_ENABLED=0 $(GO) build -ldflags=$(LDFLAGS) -o $(OUTPUT_DIR)/$(APP_NAME)$(if $(filter windows,$(1)),.exe) . 
endef
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
linux: clean install-dep linux/amd64
	@echo "Alias 'linux' ensured linux/amd64 build."

linux/amb64: linux/amd64

# 'make linux-amd64' will build for linux-amd64
linux-amd64: clean install-dep build-linux-amd64

# 'make linux-arm64' will build for linux-arm64 (common for ARM servers/devices)
linux-arm64: clean install-dep build-linux-arm64

# 'make darwin-amd64' will build for darwin-amd64 
darwin-amd64: clean install-dep build-darwin-amd64

# 'make darwin-arm64' will build for darwin-arm64
darwin-arm64: clean install-dep build-darwin-arm64

# 'make windows-amd64' will build for windows-amd64
windows-amd64: clean install-dep build-windows-amd64

# 'make windows-arm64' will build for  windows-arm64
windows-arm64: clean install-dep build-windows-arm64

# Target to run Go tests
test:
	@echo "Running Go tests..."
	$(GO) test -v ./...

# Target to clean up build artifacts
clean:
	@echo "Cleaning up build artifacts..."
	@rm -rf $(OUTPUT_DIR)

# Declare phony targets (targets that are not files)
.PHONY: all test clean linux arm macos windows $(patsubst %,build-%,$(TARGET_PLATFORMS))

