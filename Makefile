SHELL := /usr/bin/env bash

.PHONY: help
.DEFAULT_GOAL := help
help:  ## Prints all the targets in all the Makefiles
	@grep -h -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: list
list:  ## List all make targets
	@${MAKE} -pRrn : -f $(MAKEFILE_LIST) 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | sort

.PHONY: site
site:  ## Generate project site
	# hugo ...
	@echo "generating site..."

.PHONY: docs
docs: site  ## Generate documentation

.PHONY: test-base
test-base:  ## run application unit tests
	@echo "running base HTT tests"
	zig build test

.PHONY: test-api
test-api:  ## test exposed Lua API
	@echo "test HTT API"
	zig build
	./zig-out/bin/htt ./tests/run_tests.lua

.PHONY: test
test:  ## run all tests
	test-base
	test-api
