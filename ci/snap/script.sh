#!/usr/bin/env bash

set -e
set -o pipefail

mkdir -p "$TRAVIS_BUILD_DIR/snaps-cache"
sudo snapcraft --use-lxd

