#!/bin/bash

SUDO="sudo"

while (($# > 0)); do
  case $1 in
  --test) # install test dependencies
    TEST=1
    shift
    ;;
  --container) # don't use sudo
    SUDO=""
    shift
    ;;
  esac
done

os=$(uname -s)
if [[ $os == Linux ]]; then
  $SUDO apt-get update
  $SUDO apt-get install -y build-essential cmake curl gettext ninja-build pkg-config unzip
  if [[ -n $TEST ]]; then
    $SUDO apt-get install -y locales-all cpanminus
  fi
elif [[ $os == Darwin ]]; then
  brew update --quiet
  brew install ninja
  if [[ -n $TEST ]]; then
    brew install cpanminus
  fi
fi
