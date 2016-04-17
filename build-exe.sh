#!/bin/sh

clang -O0 -g -Isrc -DCOMPILE_TEST_VERSION -ldl -o src/exe src/nvim/viml/testhelpers/progs/{init.c,exe-main.c}
