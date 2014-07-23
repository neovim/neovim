#!/bin/bash
SOURCES=(
  src/nvim/garray.c
  src/nvim/viml/{parser,printer}/expr*.c
  src/nvim/viml/dumpers/dumpers.c
  src/nvim/viml/testhelpers/{parser,fgetline}.c
  src/nvim/viml/testhelpers/progs/expr-main.c
)
CFLAGS=(
  -Isrc
  -Ibuild/include
  -Ibuild/src/nvim/auto
  -DCOMPILE_TEST_VERSION
  -DINCLUDE_GENERATED_DECLARATIONS
  -Lbuild
  -g
)
KLEE_CFLAGS=(
  "${CFLAGS[@]}"
  -c
  -emit-llvm
  -I$1
  -DCOMPILE_KLEE
)
LINK_FLAGS=(
  -o expr.lo
)

if test "x$1" == "x" ; then
  clang -o src/expr "${CFLAGS[@]}" "${SOURCES[@]}"
else
  if test -d expr ; then
    rm -rf expr
  fi
  mkdir -p expr

  LINK_FLAGS="-o expr.lo"

  for src in "${SOURCES[@]}" ; do
    out="expr/$(basename $src)"
    while test -e "${out}.lo" ; do
      out="${out}.2"
    done
    out="${out}.lo"
    clang "${KLEE_CFLAGS[@]}" -o "${out}" "$src"
    LINK_FLAGS+=( "${out}" )
  done

  llvm-link "${LINK_FLAGS[@]}"
fi
