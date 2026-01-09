#!/usr/bin/bash

# This script syncs Parquet files from Hugging Face to the local 
# Superset data directory.

# Usage: parquet_sync.food.sh

set -e

# Setup variables
TODAY=$(date "+%Y-%m-%d")
DEST_DIR="/opt/superset/data"
URL="https://huggingface.co/datasets/openfoodfacts/product-database/resolve/main/food.parquet"
FILE_NAME="food.parquet"
FILE_NAME_TEMP="$FILE_NAME.tmp"

mkdir -p $DEST_DIR

# Don't download the file again if it has already been done today.
if [[ $(date -r "$DEST_DIR/$FILE_NAME.completed.txt" "+%Y-%m-%d") == "${TODAY}" ]]; then
    echo "$(date +'%Y-%m-%dT%H:%M:%S') - $DEST_DIR/$FILE_NAME file has already been downloaded today"
    echo "Want to force re-download? Remove $DEST_DIR/$FILE_NAME.completed.txt file."
else # Else download the file
    echo "$(date +'%Y-%m-%dT%H:%M:%S') - Downloading $DEST_DIR/$FILE_NAME_TEMP..."
    # Download with 'curl'
    # -z : only download if the remote file is newer than the local file
    # -L : follow redirects (necessary for HF)
    curl -L -z "$DEST_DIR/$FILE_NAME_TEMP" "$URL" -o "$DEST_DIR/$FILE_NAME_TEMP"

    if [ $? -eq 0 ]; then
        echo "Download successful: $DEST_DIR/$FILE_NAME_TEMP"
        touch "$DEST_DIR/$FILE_NAME.completed.txt"
        cp "$DEST_DIR/$FILE_NAME_TEMP" "$DEST_DIR/$FILE_NAME"
    else
        echo "Error during download"
        exit 1
    fi
fi
