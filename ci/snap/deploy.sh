#!/usr/bin/env bash

set -e
set -o pipefail

# not a tagged release, abort
[[ "$TRAVIS_TAG" != "$TRAVIS_BRANCH" ]] && exit 0

openssl aes-256-cbc -K $encrypted_0a6446eb3ae3_key \
  -iv $encrypted_0a6446eb3ae3_iv \
  -in .snapcraft/travis_snapcraft.cfg \
  -out .snapcraft/snapcraft.cfg -d

SNAP=$(find ./ -name "*.snap")

if [[ "$SNAP" =~ "dirty" || "$SNAP" =~ "nightly" ]]; then
  snapcraft push "$SNAP" --release edge
else
  snapcraft push "$SNAP" --release candidate
fi

