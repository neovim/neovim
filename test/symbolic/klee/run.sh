#!/bin/sh

set -e
set -x
test -z "$POSH_VERSION" && set -u

PROJECT_SOURCE_DIR=.
PROJECT_BINARY_DIR="$PROJECT_SOURCE_DIR/build"
KLEE_TEST_DIR="$PROJECT_SOURCE_DIR/test/symbolic/klee"
KLEE_BIN_DIR="$PROJECT_BINARY_DIR/klee"
KLEE_OUT_DIR="$KLEE_BIN_DIR/out"

help() {
  echo "Usage:"
  echo
  echo "  $0 -c fname"
  echo "  $0 fname"
  echo "  $0 -s"
  echo
  echo "First form compiles executable out of test/symbolic/klee/{fname}.c."
  echo "Compiled executable is placed into build/klee/{fname}. Must first"
  echo "successfully compile Neovim in order to generate declarations."
  echo
  echo "Second form runs KLEE in a docker container using file "
  echo "test/symbolic/klee/{fname.c}. Bitcode is placed into build/klee/a.bc,"
  echo "results are placed into build/klee/out/. The latter is first deleted if"
  echo "it exists."
  echo
  echo "Third form runs ktest-tool which prints errors found by KLEE via "
  echo "the same container used to run KLEE."
}

main() {
  local compile=
  local print_errs=
  if test "$1" = "--help" ; then
    help
    return
  fi
  if test "$1" = "-s" ; then
    print_errs=1
    shift
  elif test "$1" = "-c" ; then
    compile=1
    shift
  fi
  if test -z "$print_errs" ; then
    local test="$1" ; shift
  fi

  local includes=
  includes="$includes -I$KLEE_TEST_DIR"
  includes="$includes -I/home/klee/klee_src/include"
  includes="$includes -I$PROJECT_SOURCE_DIR/src"
  includes="$includes -I$PROJECT_BINARY_DIR/src/nvim/auto"
  includes="$includes -I$PROJECT_BINARY_DIR/include"
  includes="$includes -I$PROJECT_BINARY_DIR/config"
  includes="$includes -I/host-includes"

  local defines=
  defines="$defines -DMIN_LOG_LEVEL=9999"
  defines="$defines -DINCLUDE_GENERATED_DECLARATIONS"

  test -z "$compile" && defines="$defines -DUSE_KLEE"

  test -d "$KLEE_BIN_DIR" || mkdir -p "$KLEE_BIN_DIR"

  if test -z "$compile" ; then
    local line1='cd /image'
    if test -z "$print_errs" ; then
      test -d "$KLEE_OUT_DIR" && rm -r "$KLEE_OUT_DIR"

      line1="$line1 && $(echo clang \
        $includes $defines \
        -o "$KLEE_BIN_DIR/a.bc" -emit-llvm -g -c \
        "$KLEE_TEST_DIR/$test.c")"
      line1="$line1 && klee --libc=uclibc --posix-runtime "
      line1="$line1 '--output-dir=$KLEE_OUT_DIR' '$KLEE_BIN_DIR/a.bc'"
    fi
    local line2="for t in '$KLEE_OUT_DIR'/*.err"
    line2="$line2 ; do ktest-tool --write-ints"
    line2="$line2 \"\$(printf '%s' \"\$t\" | sed -e 's@\\.[^/]*\$@.ktest@')\""
    line2="$line2 ; done"
    printf '%s\n%s\n' "$line1" "$line2" | \
      docker run \
        --volume "$(cd "$PROJECT_SOURCE_DIR" && pwd)":/image \
        --volume "/usr/include":/host-includes \
        --interactive \
        --rm \
        --ulimit='stack=-1:-1' \
        klee/klee \
        /bin/sh -x
  else
    clang \
      $includes $defines \
      -o "$KLEE_BIN_DIR/$test" \
      -O0 -g \
      "$KLEE_TEST_DIR/$test.c"
  fi
}

main "$@"
