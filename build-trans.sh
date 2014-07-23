#!/bin/sh

clang -DCOMPILE_TEST_VERSION -ldl -Isrc -o src/trans src/nvim/viml/testhelpers/progs/{init.c,trans-main.c}
