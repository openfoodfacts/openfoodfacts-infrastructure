#!/bin/bash

# Usage:
# ./clear_cache.sh               # clear all caches
# ./clear_cache.sh "products"    # clear only cache for /products pages

# Delete all nginx cache
# https://stackoverflow.com/questions/36617999/error-rm-missing-operand-when-using-along-with-find-command
grep -lr "httpmirabelle.openfoodfacts.org/$1" /var/cache/nginx | xargs -r  rm


# Restart nginx to restart the cache
systemctl restart nginx
