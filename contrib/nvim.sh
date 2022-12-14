#! /usr/bin/env bash

VIMRUNTIME=$(pwd)/runtime ./build/bin/nvim \
  -c "set rtp+=$(pwd)/build/runtime" \
  "$@"
