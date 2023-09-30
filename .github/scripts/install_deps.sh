#!/bin/bash

while (($# > 0)); do
  case $1 in
  --test) # install test dependencies
    TEST=1
    shift
    ;;
  esac
done

os=$(uname -s)
if [[ $os == Linux ]]; then
  sudo apt-get update
  sudo apt-get install -y attr build-essential cmake curl gettext libattr1-dev ninja-build unzip
  if [[ -n $TEST ]]; then
    sudo apt-get install -y locales-all cpanminus
  fi
elif [[ $os == Darwin ]]; then
  brew update --quiet
  brew install ninja
  if [[ -n $TEST ]]; then
    brew install cpanminus
  fi
fi
