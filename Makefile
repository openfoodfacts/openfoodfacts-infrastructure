#!/usr/bin/env make

# use bash !
SHELL := /bin/bash

.DEFAULT_GOAL := checks
# avoid target corresponding to file names, to depends on them
.PHONY: *

#------------#
# Checks     #
#------------#

checks: check_build_docs

check_build_docs:
	@echo "🥫 Building documentation to check it …"
	@./scripts/build_mkdocs.sh --check

build_docs:
	@echo "🥫 Building documentation …"
	@./scripts/build_mkdocs.sh
