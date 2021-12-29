#!/usr/bin/env bash

set -e
set -o pipefail


RESULT_SNAP=$(find ./ -name "*.snap")

sudo snap install "$RESULT_SNAP" --dangerous --classic

/snap/bin/nvim --version

SHA256=$(sha256sum "$RESULT_SNAP")
echo "SHA256: ${SHA256} ."
