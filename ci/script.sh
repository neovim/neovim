#!/usr/bin/env bash

set -e
set -o pipefail

ci/run_${CI_TARGET}.sh
