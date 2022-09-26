#!/bin/bash

# Usage:
# ./clear_cache.sh               # clear all caches
# ./clear_cache.sh "products"    # clear only cache for /products pages

# Delete all nginx cache
#rm -rf /var/cache/nginx/*
grep -lr "httpmirabelle.openfoodfacts.org/$1" /var/cache/nginx | xargs rm


# Restart nginx to restart the cache
systemctl restart nginx
