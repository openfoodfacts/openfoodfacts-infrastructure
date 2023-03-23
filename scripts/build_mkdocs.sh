#!/usr/bin/env bash

# Renders markdown doc in docs to html in gh_pages

# copy README.md as the index but change links starting with ./docs/ to ./
sed -e 's|(\./docs/|(./|g' README.md > docs/index.md