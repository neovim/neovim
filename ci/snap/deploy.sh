#!/usr/bin/env bash

set -e
set -o pipefail

# not a tagged release, abort
[[ "$TRAVIS_TAG" != "$TRAVIS_BRANCH" ]] && exit 0

openssl enc \
  -aes-256-cbc \
  -md sha512 \
  -pbkdf2 \
  -iter 1000 \
  -a -d \
  -in .snapcraft/travis_snapcraft.cfg \
  -out .snapcraft/snapcraft.cfg -k $SNAP_SECRECT_KEY

SNAP=$(find ./ -name "*.snap")

if [[ "$SNAP" =~ "dirty" || "$SNAP" =~ "nightly" ]]; then
  snapcraft push "$SNAP" --release edge
else
  snapcraft push "$SNAP" --release candidate
fi

