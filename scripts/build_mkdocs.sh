#!/usr/bin/env bash

# first some sanity checks
WRONG_EXT=$(find docs docs/reports -maxdepth 1 -type f|grep -v ".md$"| grep -v "/.pages$");
if [[ -n "${WRONG_EXT}" ]]
then
  echo >&2 "File with wrong extensions $${WRONG_EXT}"
  exit 1
fi
MISSING_ROLE_IN_TITLE=$(for f in ansible/roles/*/README.md; do head -n 1 $f|grep --quiet -i role || echo -n $f" ";done)
if [[ -n "${MISSING_ROLE_IN_TITLE}" ]]
then
  echo >&2 'Some roles readme do not have "role" in their title:' ${MISSING_ROLE_IN_TITLE}
  exit 1
fi


# Renders markdown doc in docs to html in gh_pages

# add documentation for ansible roles
mkdir -p docs/ansible/roles
for ROLE_NAME in $(ls ansible/roles)
do
  ROLE_PATH=ansible/roles/${ROLE_NAME}
  if [[ -f $ROLE_PATH/README.md ]]
  then
    echo "generating docs for role $ROLE_NAME"
    DOC_PATH=docs/ansible/roles/${ROLE_NAME}.md
    cat $ROLE_PATH/README.md > $DOC_PATH
    # add defaults
    if [[ -f $ROLE_PATH/defaults/main.yml ]]
    then
      echo -e '\n## Defaults\n```\n' >> $DOC_PATH
      cat $ROLE_PATH/defaults/main.yml >> $DOC_PATH
      echo '```' >> $DOC_PATH
    fi
    # replace links
    sed -i -e 's!../../../docs/!../../!g' $DOC_PATH
  fi
done



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
echo "installing some extensions"
pip3 uninstall -y mkdocs-awesome-pages-plugin
pip3 install mdx_truly_sane_lists mkdocs-glightbox mdx-breakless-lists mkdocs-awesome-nav
EOF
# get group id to use it in the docker
GID=$(id -g)

# we use minidocks capability to add entrypoint to install some pip package
# we use also it's capability to change user and group id to avoid permissions problems
docker run --rm \
  -v $PIP_INSTALL:/docker-entrypoint.d/60-pip-install.sh \
  -e USER_ID=$UID -e GROUP_ID=$GID \
  $DOCKER_ARGS \
  -v $(pwd):/app -w /app \
  minidocks/mkdocs:1 build --strict
# get exit code !
ERROR=$?
# cleanup
if [[ -n $TMP_BUILD_DIR ]]; then rm -rf $TMP_BUILD_DIR; fi
rm -r docs/ansible/roles
exit $ERROR
