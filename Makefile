SHELL := /bin/bash

MAKEFLAGS += --no-builtin-rules
.SUFFIXES:

VERSION  := $(or $(shell git describe --tags --abbrev=0), "v0.0.0")
REVISION := $(shell git rev-parse --verify HEAD)

DIST_DIR := $(shell pwd)/dist

# Main targets

.PHONY: build
build: lambda-build sam-build

.PHONY: run
run: build
	@$(call sam-cmd, local start-api --docker-volume-basedir "$(LAMBDA_DIST)/" --host 0.0.0.0)


# Golang

GOFLAGS    := -a -tags netgo -installsuffix netgo -ldflags="-s -w -X \"main.Version=$(VERSION)\" -X \"main.Revision=$(REVISION)\" -extldflags \"-static\""

.PHONY: go-deps
go-deps:
	@go get -u github.com/golang/dep/cmd/dep
	@dep ensure -v

.PHONY: go-test
go-test:
	@go test ./... -cover -race

.PHONY: go-lint
go-lint:
	@go get -u golang.org/x/lint/golint
	@golint -set_exit_status $(shell go list ./... | grep -v /vender/)
	@go vet ./...


# AWS Lambda Functions

LAMBDA_SRC  := $(shell pwd)/cmd/lambda
LAMBDA_DIST := $(DIST_DIR)/$(VERSION)
LAMBDA_FUNCTIONS := $(notdir $(shell find $(LAMBDA_SRC)/ -type d))


.PHONY: lambda-clearn
lambda-clean:
	@rm -rf $(LAMBDA_DIST)

.PHONY: lambda-build
lambda-build: go-lint lambda-clean
	@mkdir -p $(LAMBDA_DIST)
	@cp -f $(LAMBDA_SRC)/template.yml $(LAMBDA_DIST)/template.yml
	@for name in $(LAMBDA_FUNCTIONS); do \
		echo build: lambda function $$name; \
		CGO_ENABLED=0 GOOS=linux go build $(GOFLAGS) -o $(LAMBDA_DIST)/$$name $(LAMBDA_SRC)/$$name/main.go; \
	done;


# AWS Serverless Application Model

SAM_CLI_VERSION := 0.6.0
SAM_IMAGE_NAME := "sam-cli"

.PHONY: sam-build
sam-build:
	@docker build docker/sam-cli -t $(SAM_IMAGE_NAME) --build-arg SAM_CLI_VERSION=$(SAM_CLI_VERSION)

define sam-cmd
	docker run -it --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(LAMBDA_DIST):/var/opt \
		-p "3000:3000" \
		$(SAM_IMAGE_NAME) \
		$1
endef

.PHONY: sam
sam:
	@$(call sam-cmd, $(wordlist 2, $(words $(MAKECMDGOALS)),$(MAKECMDGOALS)))
