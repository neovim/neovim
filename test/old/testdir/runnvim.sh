#!/usr/bin/env bash

main() {(
  local separator="================================================================================"
  local oldesttest=
  if test "$1" = "--oldesttest" ; then
    shift
    oldesttest=1
  fi
  local root="$1" ; shift
  local nvim_prg="$1" ; shift
  local test_name="$1" ; shift

  local tlog="$test_name.tlog"

  export NVIM_TEST_ARGC=$#
  local arg
  local i=0
  # shellcheck disable=SC2034  # (unused "arg", used in "eval").
  for arg ; do
    eval "export NVIM_TEST_ARG$i=\"\$arg\""
    i=$(( i+1 ))
  done

  BUILD_DIR="$(dirname "$nvim_prg")/.."
  export BUILD_DIR
  export FAILED=0

  . $(dirname $0)/test.sh

  # Redirect XDG_CONFIG_HOME so users local config doesn't interfere
  export XDG_CONFIG_HOME="$root"

  export VIMRUNTIME="$root/runtime"
  if ! "$nvim_prg" \
    -u NONE -i NONE \
    --headless \
    --cmd 'set shortmess+=I noswapfile noundofile nomore' \
    -S runnvim.vim \
    "$tlog" > "out-$tlog" 2> "err-$tlog"
  then
    fail "$test_name" "Nvim exited with non-zero code"
  fi
  {
    echo "Stdout of :terminal runner"
    echo "$separator"
    cat "out-$tlog"
    echo "$separator"
    echo "Stderr of :terminal runner"
    echo "$separator"
    cat "err-$tlog"
    echo "$separator"
  } >> "$tlog"
  if test "$oldesttest" = 1 ; then
    if ! diff -q test.out "$test_name.ok" > /dev/null 2>&1 ; then
      if test -f test.out ; then
        fail "$test_name" "Oldest test .out file differs from .ok file"
        {
          echo "Diff between test.out and $test_name.ok"
          echo "$separator"
          diff -a test.out "$test_name.ok"
          echo "$separator"
        } >> "$tlog"
      else
        echo "No output in test.out" >> "$tlog"
      fi
    fi
  fi
  valgrind_check .
  if test -n "$LOG_DIR" ; then
    check_sanitizer "$LOG_DIR"
  fi
  check_core_dumps
  if test "$FAILED" = 1 ; then
    cat "$tlog"
  fi
  rm -f "$tlog"
  if test "$FAILED" = 1 ; then
    echo "Test $test_name failed, see output above and summary for more details" >> test.log
    # When Neovim crashed/aborted it might not have created messages.
    # test.log itself is used as an indicator to exit non-zero in the Makefile.
    if ! test -f message; then
      cp -a test.log messages
    fi
  fi
)}

main "$@"
