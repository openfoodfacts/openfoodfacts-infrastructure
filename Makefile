#!/usr/bin/env make

# use bash !
SHELL := /bin/bash

.DEFAULT_GOAL := checks
# avoid target corresponding to file names, to depends on them
.PHONY: *

#------------#
# Checks     #
#------------#

checks: check_docs check_build_docs

check_docs:
	@echo "🥫 Checking documentation …"
	@WRONG_EXT=$$(find docs docs/reports -maxdepth 1 -type f|grep -v ".md$$"); \
	if [[ -n "$${WRONG_EXT}" ]] ; then echo >&2 "File with wrong extensions $${WRONG_EXT}"; exit 1; fi

check_build_docs:
	@echo "🥫 Building documentation to check it …"
	@./scripts/build_mkdocs.sh --check


build_docs:
	@echo "🥫 Building documentation …"
	@./scripts/build_mkdocs.sh
