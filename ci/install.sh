#!/usr/bin/env bash

set -e
set -o pipefail

if [[ "${CI_TARGET}" == lint ]]; then
  python3 -m pip -q install --user --upgrade flake8
  exit
fi

if [[ "${TRAVIS_OS_NAME}" == osx ]]; then
  export PATH="/usr/local/opt/ccache/libexec:$PATH"
fi

# Use default CC to avoid compilation problems when installing Python modules.
echo "Install neovim module for Python 3."
CC=cc python3 -m pip -q install --upgrade pynvim
echo "Install neovim module for Python 2."
CC=cc python2 -m pip -q install --upgrade pynvim

echo "Install neovim RubyGem."
gem install --no-document --version ">= 0.8.0" neovim

echo "Install neovim npm package"
npm install -g neovim
npm link neovim

echo "Install tree-sitter npm package"

# FIXME
# https://github.com/tree-sitter/tree-sitter/commit/e14e285a1087264a8c74a7c62fcaecc49db9d904
# If queries added to tree-sitter-c, we can use latest tree-sitter-cli
npm install -g tree-sitter-cli@v0.15.9

echo "Install tree-sitter c parser"
curl "https://codeload.github.com/tree-sitter/tree-sitter-c/tar.gz/v0.15.2" -o tree_sitter_c.tar.gz
tar xf tree_sitter_c.tar.gz
cd tree-sitter-c-0.15.2
export TREE_SITTER_DIR=$HOME/tree-sitter-build/
mkdir -p "$TREE_SITTER_DIR/bin"

if [[ "$BUILD_32BIT" != "ON" ]]; then
  # builds c parser in $HOME/tree-sitter-build/bin/c.(so|dylib)
  tree-sitter test
else
  # no tree-sitter binary for 32bit linux, so fake it (no tree-sitter unit tests)
  cd src/
  gcc -m32 -o "$TREE_SITTER_DIR/bin/c.so" -shared parser.c -I.
fi
test -f "$TREE_SITTER_DIR/bin/c.so"
