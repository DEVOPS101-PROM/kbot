# Makefile for kbot project

# Go parameters
GO      := go
GO_VERSION_REQ := 1.22
GO_INSTALL_VERSION := 1.24.3
GO_LOCAL_INSTALL_DIR := $(PWD)/.go_install
GO_LOCAL_BIN := $(GO_LOCAL_INSTALL_DIR)/go/bin/go
GO_EXT := .tar.gz
CURR_OS := linux
CURR_ARCH := $(shell uname -m)

# Architecture conversion
ARCH := $(shell if [ "$(CURR_ARCH)" = "x86_64" ]; then echo "amd64"; else echo "$(CURR_ARCH)"; fi)

# Container runtime selection
CONTAINER_RUNTIME ?= docker
ifeq ($(CONTAINER_RUNTIME),podman)
    RUNTIME := podman
    BUILDX := build
else
    RUNTIME := docker
    BUILDX := buildx build
endif

# Docker parameters
REPO := ghcr.io
APP_NAME := kbot
VERSION := $(shell git describe --tags --abbrev=0)-$(shell git rev-parse --short HEAD)

# Default target
.DEFAULT_GOAL := help

# Help target
help:
	@echo "Available targets:"
	@echo "  image        - Build container image for current architecture"
	@echo "  image-arm    - Build container image for ARM64"
	@echo "  image-amd64  - Build container image for AMD64"
	@echo "  push         - Push container image to registry"
	@echo "  clean        - Clean up build artifacts and images"
	@echo ""
	@echo "Container runtime can be selected using CONTAINER_RUNTIME variable:"
	@echo "  make image CONTAINER_RUNTIME=docker    # Use Docker (default)"
	@echo "  make image CONTAINER_RUNTIME=podman    # Use Podman"

# Build image for current architecture
image:
	@echo "Building container image for $(CURR_OS)/$(ARCH) using $(CONTAINER_RUNTIME)..."
	$(RUNTIME) $(BUILDX) \
		--platform=$(CURR_OS)/$(ARCH) \
		-f Dockerfile \
		--build-arg TARGETOS="$(CURR_OS)" \
		--build-arg TARGETARCH="$(ARCH)" \
		-t $(REPO)/$(APP_NAME):$(VERSION)-$(CURR_OS)-$(ARCH) \
		. --load
	@echo "Image $(REPO)/$(APP_NAME):$(VERSION)-$(CURR_OS)-$(ARCH) built successfully"

# Build image for ARM64
image-arm:
	@echo "Building container image for linux/arm64 using $(CONTAINER_RUNTIME)..."
	$(RUNTIME) $(BUILDX) \
		--platform=$(CURR_OS)/arm64 \
		-f Dockerfile \
		--build-arg TARGETOS="$(CURR_OS)" \
		--build-arg TARGETARCH="arm64" \
		-t $(REPO)/$(APP_NAME):$(VERSION)-$(CURR_OS)-arm64 \
		. --load
	@echo "Image $(REPO)/$(APP_NAME):$(VERSION)-$(CURR_OS)-arm64 built successfully"

# Build image for AMD64
image-amd64:
	@echo "Building container image for linux/amd64 using $(CONTAINER_RUNTIME)..."
	$(RUNTIME) $(BUILDX) \
		--platform=$(CURR_OS)/amd64 \
		-f Dockerfile \
		--build-arg TARGETOS="$(CURR_OS)" \
		--build-arg TARGETARCH="amd64" \
		-t $(REPO)/$(APP_NAME):$(VERSION)-$(CURR_OS)-amd64 \
		. --load
	@echo "Image $(REPO)/$(APP_NAME):$(VERSION)-$(CURR_OS)-amd64 built successfully"

# Push image to registry
push:
	@echo "Pushing container images to registry using $(CONTAINER_RUNTIME)..."
	$(RUNTIME) push $(REPO)/$(APP_NAME):$(VERSION)-$(CURR_OS)-$(ARCH)
	@echo "Container images pushed successfully"

# Clean up
clean:
	@echo "Cleaning up build artifacts and images..."
	@if [ "$(IMG-RM)" = "true" ]; then \
		echo "Removing container images for $(REPO)/$(APP_NAME):$(VERSION)*" ; \
		$(RUNTIME) rmi -f $$($(RUNTIME) image ls $(REPO)/$(APP_NAME):$(VERSION)* -aq) || true; \
	fi

.PHONY: help image image-arm image-amd64 push clean