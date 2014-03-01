#!/bin/sh -e

# export VALGRIND_CHECK=1
make cmake CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$PWD/dist"
make
make unittest
make test
if ls test/legacy/valgrind.* > /dev/null 2>&1; then
  echo "Memory leak detected" >&2
  cat test/legacy/valgrind.*
  exit 1
fi
make install
