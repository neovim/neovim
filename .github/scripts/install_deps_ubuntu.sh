#!/bin/bash

PACKAGES=(
  autoconf
  automake
  build-essential
  cmake
  cpanminus
  curl
  gettext
  libtool-bin
  locales-all
  ninja-build
  pkg-config
  unzip
)

sudo apt-get update
sudo apt-get install -y "${PACKAGES[@]}"
