#!/usr/bin/env bash

set -e
set -o pipefail

# Use default CC to avoid compilation problems when installing Python modules.
echo "Install neovim module for Python."
CC=cc python3 -m pip -q install --user --upgrade pynvim

echo "Install neovim RubyGem."
gem install --no-document --bindir "$HOME/.local/bin" --user-install --pre neovim

echo "Install neovim npm package"
npm install -g neovim
npm link neovim

if [[ $CI_OS_NAME != osx ]]; then
  sudo cpanm -n Neovim::Ext || cat "$HOME/.cpanm/build.log"
  perl -W -e 'use Neovim::Ext; print $Neovim::Ext::VERSION'
fi
