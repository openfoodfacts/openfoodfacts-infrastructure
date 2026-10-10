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

#------------#
# Install    #
#------------#

# wazuh-ansible is a git submodule (see docs/explanation/services/wazuh.md), so
# it comes with the repository. We only install the collections it requires,
# which ansible-galaxy puts in collections/ alongside our own.
install_ansible:
	@echo "🥫 Installing ansible dependencies …"
	@cd ansible && ansible-galaxy install -r requirements.yml

install_wazuh_ansible:
	@echo "🥫 Installing wazuh-ansible collections …"
	@cd ansible && ansible-galaxy install -r vendor/wazuh-ansible/requirements.yml

# people who cloned before wazuh-ansible became a submodule
install_submodules:
	@echo "🥫 Fetching git submodules …"
	@git submodule update --init --recursive

install: install_ansible install_wazuh_ansible install_submodules
