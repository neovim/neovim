#!/bin/bash

os=$(uname -s)
if [[ $os == Linux ]]; then
  sudo apt-get update
  sudo apt-get install -y autoconf automake build-essential cmake curl gettext libtool-bin locales-all ninja-build pkg-config unzip "$@"
elif [[ $os == Darwin ]]; then
  brew update --quiet
  brew install automake ninja "$@"
fi
