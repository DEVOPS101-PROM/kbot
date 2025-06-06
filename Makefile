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

# Helm parameters
HELM_CHART_DIR := helm
HELM_CHART_NAME := kbot
HELM_RELEASE_NAME := kbot
HELM_NAMESPACE ?= default

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
	@echo "  helm-lint    - Lint Helm chart"
	@echo "  helm-package - Package Helm chart"
	@echo "  helm-install - Install Helm chart"
	@echo "  helm-uninstall - Uninstall Helm chart"
	@echo ""
	@echo "Container runtime can be selected using CONTAINER_RUNTIME variable:"
	@echo "  make image CONTAINER_RUNTIME=docker    # Use Docker (default)"
	@echo "  make image CONTAINER_RUNTIME=podman    # Use Podman"
	@echo ""
	@echo "Helm namespace can be specified using HELM_NAMESPACE variable:"
	@echo "  make helm-install HELM_NAMESPACE=my-namespace"

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

# Helm chart operations
helm-lint:
	@echo "Linting Helm chart..."
	helm lint $(HELM_CHART_DIR)

helm-package:
	@echo "Packaging Helm chart..."
	helm package $(HELM_CHART_DIR)

helm-install:
	@echo "Installing Helm chart..."
	helm upgrade --install $(HELM_RELEASE_NAME) $(HELM_CHART_DIR) \
		--namespace $(HELM_NAMESPACE) \
		--create-namespace \
		--set image.repository=$(REPO)/$(APP_NAME) \
		--set image.tag=$(VERSION)-$(CURR_OS)-$(ARCH)

helm-uninstall:
	@echo "Uninstalling Helm chart..."
	helm uninstall $(HELM_RELEASE_NAME) --namespace $(HELM_NAMESPACE)

.PHONY: help image image-arm image-amd64 push clean helm-lint helm-package helm-install helm-uninstall