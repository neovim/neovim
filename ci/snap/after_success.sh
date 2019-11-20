#!/usr/bin/env bash

set -e
set -o pipefail


RESULT_SNAP=$(find ./ -name "*.snap")

sudo snap install "$RESULT_SNAP" --dangerous --classic

/snap/bin/nvim --version

SHA256=$(sha256sum "$RESULT_SNAP")
echo "SHA256: ${SHA256} ."

timeout 240 /snap/bin/transfer "$RESULT_SNAP"

travis_retry bash "${ROOT_PATH}/scripts/services/0x0.st.sh" "${RESULT_SNAP}"

