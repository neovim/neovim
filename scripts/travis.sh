#!/bin/sh -e

# export VALGRIND_CHECK=1
make cmake CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$PWD/dist"
make
make test
make install
