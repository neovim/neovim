#!/usr/bin/env bash

set -e

# Check that you have uncrustify
hash uncrustify

COMMITISH="${1:-master}"
for file in $(git diff --diff-filter=d --name-only $COMMITISH | grep '\.[ch]$'); do
    uncrustify -c src/uncrustify.cfg -l C --replace --no-backup "$file"
done
