#!/usr/bin/env bash

set -e
set -o pipefail

mkdir -p "$CI_BUILD_DIR/snaps-cache"
sg lxd -c snapcraft

