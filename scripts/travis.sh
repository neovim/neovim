#!/bin/sh -e

export VALGRIND_CHECK=1
make cmake CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$PWD/dist"
make
make test > /dev/null 2>&1
make install
