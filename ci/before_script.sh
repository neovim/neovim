#!/usr/bin/env bash

set -e
set -o pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
source "${CI_DIR}/common/build.sh"

# Compile dependencies.
build_deps

rm -rf "${LOG_DIR}"
mkdir -p "${LOG_DIR}"
