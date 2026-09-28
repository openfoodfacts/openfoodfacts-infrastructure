#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <nginx-config-directory>" >&2
    exit 2
fi

config_dir=$(realpath "$1")
if [[ ! -d "$config_dir" ]]; then
    echo "NGINX configuration directory does not exist: $config_dir" >&2
    exit 2
fi
repository_root=$(git rev-parse --show-toplevel)
repository_config_dir=${config_dir#"$repository_root"/}

staging_dir=$(mktemp -d)
output_file=$(mktemp)
trap 'rm -rf "$staging_dir"; rm -f "$output_file"' EXIT

cp -a "$config_dir/." "$staging_dir/"

# Certificates and Certbot-generated snippets live only on the target hosts.
# Substitute a short-lived certificate so nginx can still validate every other
# directive and include in the repository configuration.
openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
    -subj /CN=nginx-config-validation \
    -keyout "$staging_dir/ci-key.pem" \
    -out "$staging_dir/ci-cert.pem" >/dev/null 2>&1

find "$staging_dir" -type f -exec sed -i -E \
    -e 's#^[[:space:]]*ssl_certificate[[:space:]]+[^;]+;#    ssl_certificate /etc/nginx/ci-cert.pem;#' \
    -e 's#^[[:space:]]*ssl_certificate_key[[:space:]]+[^;]+;#    ssl_certificate_key /etc/nginx/ci-key.pem;#' \
    -e 's#^[[:space:]]*ssl_trusted_certificate[[:space:]]+[^;]+;#    ssl_trusted_certificate /etc/nginx/ci-cert.pem;#' \
    -e '/^[[:space:]]*ssl_dhparam[[:space:]]+/d' \
    -e '\#^[[:space:]]*include[[:space:]]+/etc/letsencrypt/#d' \
    {} +

# Repository nginx.conf files include this package-owned file.
docker run --rm nginx:mainline cat /etc/nginx/mime.types \
    >"$staging_dir/mime.types"

# Older proxy trees rely on the host's package-provided nginx.conf rather than
# storing one in this repository. Supply its relevant structure for CI.
if [[ ! -f "$staging_dir/nginx.conf" ]]; then
    docker run --rm nginx:mainline cat /etc/nginx/nginx.conf \
        >"$staging_dir/nginx.conf"
fi

set +e
docker run --rm \
    --mount "type=bind,src=$staging_dir,dst=/etc/nginx" \
    nginx:mainline \
    nginx -t >"$output_file" 2>&1
nginx_status=$?
set -e

cat "$output_file"

if [[ ${GITHUB_ACTIONS:-false} == true ]]; then
    while IFS= read -r warning; do
        # The temporary CI certificate intentionally has no OCSP responder.
        if [[ $warning == *'"ssl_stapling" ignored'*'/etc/nginx/ci-cert.pem'* ]]; then
            continue
        fi

        message=${warning#nginx: \[warn\] }
        if [[ $message =~ ^(.*)\ in\ /etc/nginx/(.*):([0-9]+)$ ]]; then
            message=${BASH_REMATCH[1]}
            file=${repository_config_dir}/${BASH_REMATCH[2]}
            line=${BASH_REMATCH[3]}
            message=${message//'%'/'%25'}
            echo "::warning file=$file,line=$line::$message"
        else
            message=${message//'%'/'%25'}
            echo "::warning::$message"
        fi
    done < <(grep '^nginx: \[warn\]' "$output_file" || true)
fi

exit "$nginx_status"
