#!/usr/bin/env bash

# Renders markdown doc in docs to html in gh_pages

# --check just checks for errors and warnings
echo "OPTION IS $1"
if [[ "$1" == "--check" ]]
then
  TMP_BUILD_DIR=$(mktemp -d)
  DOCKER_ARGS="-v $TMP_BUILD_DIR:/app/gh_pages"
  # ensure dir exists however to avoid having it created with root:root permissions
  mkdir -p gh_pages
fi

# we need to install one more dependency to minidocs/mkdocs
PIP_INSTALL=$(mktemp)
cat >$PIP_INSTALL <<EOF
#!/bin/sh
echo "installing mdx_truly_sane_lists and mdx-breakless-lists"
pip3 install mdx_truly_sane_lists mkdocs-glightbox mdx-breakless-lists
EOF
# get group id to use it in the docker
GID=$(id -g)

# copy README.md as the index but change links starting with ./docs/ to ./
sed -e 's|(\./docs/|(./|g' README.md > docs/index.md

# we use minidocks capability to add entrypoint to install some pip package
# we use also it's capability to change user and group id to avoid permissions problems
docker run --rm \
  -v $PIP_INSTALL:/docker-entrypoint.d/60-pip-install.sh \
  -e USER_ID=$UID -e GROUP_ID=$GID \
  $DOCKER_ARGS \
  -v $(pwd):/app -w /app \
  minidocks/mkdocs build --strict
# get exit code !
ERROR=$?
# cleanup
rm $PIP_INSTALL docs/index.md
if [[ -n $TMP_BUILD_DIR ]]; then rm -rf $TMP_BUILD_DIR; fi

exit $ERROR