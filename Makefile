SHELL := /usr/bin/env bash

.PHONY: help
.DEFAULT_GOAL := help
help:  ## Prints all the targets in all the Makefiles
	@grep -h -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: list
list:  ## List all make targets
	@${MAKE} -pRrn : -f $(MAKEFILE_LIST) 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | sort


MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
HTT_DIR := $(MAKEFILE_DIR)/zig-out/makefile
HTT := $(HTT_DIR)/bin/htt

$(HTT):
	zig build -p $(HTT_DIR)

htt: $(HTT)

.PHONY: clean
clean:  ## remove binaries
	rm -rf $(MAKEFILE_DIR)/zig-out/makefile
	rm -rf $(MAKEFILE_DIR)/zig-out/bin

.PHONY: site
site:  ## Generate project site
	# hugo ...
	@echo "generating site..."

.PHONY: docs
docs: site  ## Generate documentation
	echo "not implemented yet!"

.PHONY: docs-gen
docs-gen: htt  ## generate pages for documentation
	$(HTT) $(MAKEFILE_DIR)/docs/gensite.lua

.PHONY: docs-dev
docs-dev: htt  ## run local docs development server
	$(MAKE) docs-gen
	@echo "now run '$(MAKE) docs-gen' to re-render example" 
	cd docs/out; python -m http.server 1314

.PHONY: test-zig
test-zig:  ## run application unit tests
	@echo "running base HTT tests"
	zig build test

.PHONY: test-api
test-api: htt  ## test exposed Lua API
	@echo "lua unit tests"
	$(HTT) ./tests/unit/run_tests.lua  # API Unit tests

.PHONY: test-tpl
test-tpl: htt  ## tests using the HTTP templating language
	@echo "HTT templating tests"
	$(HTT) ./tests/tpl/run_tests.lua   # HTT template tests

.PHONY: test
test: htt test-zig test-api test-tpl  ## run all tests
	@echo "remember to 'make clean' first to rebuild HTT"
