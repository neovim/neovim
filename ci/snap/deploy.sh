#!/usr/bin/env bash

set -e
set -o pipefail

# not a tagged release, abort
# [[ "$TRAVIS_TAG" != "$TRAVIS_BRANCH" ]] && exit 0

mkdir -p .snapcraft
# shellcheck disable=SC2154
openssl aes-256-cbc -K "$encrypted_ece1c4844832_key" -iv "$encrypted_ece1c4844832_iv" \
  -in ci/snap/travis_snapcraft.cfg -out .snapcraft/snapcraft.cfg -d

SNAP=$(find ./ -name "*.snap")

# TODO(justinmk): This always does `edge` until we enable tagged builds.
if [[ "$SNAP" =~ "dirty" || "$SNAP" =~ "nightly" ]]; then
  snapcraft push "$SNAP" --release edge
else
  snapcraft push "$SNAP" --release candidate
fi
