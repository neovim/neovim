#!/usr/bin/env bash

set -e
set -o pipefail

# Use default CC to avoid compilation problems when installing Python modules.
echo "Install neovim module for Python 3."
CC=cc python3 -m pip -q install --user --upgrade pynvim
if python2 -m pip -c True 2>&1; then
  echo "Install neovim module for Python 2."
  CC=cc python2 -m pip -q install --user --upgrade pynvim
fi

echo "Install neovim RubyGem."
gem install --no-document --bindir "$HOME/.local/bin" --user-install --pre neovim

echo "Install neovim npm package"
npm install -g neovim
npm link neovim

sudo cpanm -n Neovim::Ext || cat "$HOME/.cpanm/build.log"
perl -W -e 'use Neovim::Ext; print $Neovim::Ext::VERSION'
