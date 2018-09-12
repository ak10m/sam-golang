SHELL := /bin/bash

# AWS Serverless Application Model

SAM_CLI_VERSION := 0.6.0
SAM_IMAGE_NAME := "sam-cli"

.PHONY: sam-build
sam-build:
	@docker build docker/sam-cli -t $(SAM_IMAGE_NAME) --build-arg SAM_CLI_VERSION=$(SAM_CLI_VERSION)

define sam-cmd
	docker run -it --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $(shell pwd):/var/opt \
		-p "3000:3000" \
		$(SAM_IMAGE_NAME) \
		$1
endef

.PHONY: sam
sam:
	@$(call sam-cmd, $(wordlist 2, $(words $(MAKECMDGOALS)),$(MAKECMDGOALS)))
