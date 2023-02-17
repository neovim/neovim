#!/bin/bash

os=$(uname -s)
if [[ $os == Linux ]]; then
  sudo apt-get update
  sudo apt-get install -y build-essential cmake curl gettext locales-all ninja-build pkg-config unzip "$@"
elif [[ $os == Darwin ]]; then
  brew update --quiet
  brew install ninja "$@"
fi
