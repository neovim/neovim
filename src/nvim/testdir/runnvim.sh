#!/bin/sh

# set -x
set -e

prepare_tdir() {
  local tdir="$1" ; shift
  local test_name="$1" ; shift

  if test -d "$tdir" ; then
    rm -r "$tdir"
  fi
  mkdir -p "$tdir"

  mkdir -p "$tdir/Xtest-tmpdir"
  export TMPDIR="$tdir/Xtest-tmpdir"

  cp -a * "$tdir"
  if test -e "$tdir/$test_name.ok" ; then
    cp "$tdir/$test_name.ok" "$tdir/test.ok"
  fi
}

help() {
  echo "Usage:"
  echo
  echo "  $0 --help"
  echo "  $0 --report {root} {build_dir}"
  echo "  $0 [--oldesttest] {root} {build_dir} {nvim_prg} {test_name} {cmd}..."
  echo
  echo "  --help: show this help."
  echo
  echo "  --report: check whether test failure report file exists. If it does"
  echo "            then output it and exit with non-zero exit code."
  echo
  echo "  --oldesttest: use oldest test report files to check for error."
  echo "                Specifically will check that there is test.out and that"
  echo "                it does not differ from {test_name}.ok. Otherwise"
  echo "                script checks for failures in messages file."
  echo
  echo "  {root}: git repository root directory."
  echo "  {build_dir}: CMake build directory, normally {root}/build."
  echo "  {nvim_prg}: Neovim executable name, normally {build_dir}/bin/nvim."
  echo "  {test_name}: test name without extension."
  echo "  {cmd}: command to run to perform test and corresponding arguments."
}

report() {
  local root="$1" ; shift
  local build_dir="$1" ; shift

  local ctdir="$build_dir/oldtests"
  local ctlog="$ctdir/test.log"

  echo "Test results"
  if test -f "$ctlog" ; then
    cat "$ctlog"
    echo "TEST FAILURE"
    return 1
  else
    echo "ALL DONE"
    return 0
  fi
}

main() {(
  if test "$1" = "--help" ; then
    help
    return 0
  fi
  local report=
  if test "$1" = "--report" ; then
    shift
    report "$@"
    return $?
  fi
  local oldesttest=
  if test "$1" = "--oldesttest" ; then
    shift
    oldesttest=1
  fi
  local root="$1" ; shift
  local build_dir="$1" ; shift
  local nvim_prg="$1" ; shift
  local test_name="$1" ; shift

  export NVIM_TEST_ARGC=$#
  local arg
  local i=0
  for arg ; do
    eval "export NVIM_TEST_ARG$i=\"\$arg\""
    i=$(( i+1 ))
  done

  export CI_DIR="$root/ci"
  export ROOT="$root"
  export BUILD_DIR="$build_dir"
  export FAILED=0
  export NVIM_PRG="$nvim_prg"

  . "$CI_DIR/common/suite.sh"
  . "$CI_DIR/common/test.sh"

  local ctdir="$build_dir/oldtests"
  local tdir="$ctdir/$test_name"

  prepare_tdir "$tdir" "$test_name"

  local tlog="$ctdir/$test_name.tlog"
  local ctlog="$ctdir/test.log"

  export VIMRUNTIME="$root/runtime"
  cd "$tdir"
  if ! "$nvim_prg" \
    -u NONE -i NONE \
    --headless \
    --cmd 'set shortmess+=I noswapfile noundofile nomore' \
    -S runnvim.vim \
    "$tlog" > "$tlog.out" 2> "$tlog.err"
  then
    fail "$test_name" F "Nvim exited with non-zero code"
  fi
  local separator="================================================================================"
  echo "Stdout of :terminal runner" >> "$tlog"
  echo "$separator" >> "$tlog"
  cat "$tlog.out" >> "$tlog"
  echo "$separator" >> "$tlog"
  echo "Stderr of :terminal runner" >> "$tlog"
  echo "$separator" >> "$tlog"
  cat "$tlog.err" >> "$tlog"
  echo "$separator" >> "$tlog"
  if test "$oldesttest" = 1 ; then
    if ! diff -q "$tdir/test.out" "$tdir/$test_name.ok" > /dev/null 2>&1 ; then
      if test -f "$tdir/test.out" ; then
        fail "$test_name" F "Oldest test .out file differs from .ok file"
        echo "Diff between test.out and $test_name.ok" >> "$tlog"
        echo "$separator" >> "$tlog"
        diff -a "$tdir/test.out" "$tdir/$test_name.ok" >> "$tlog" || true
        echo "$separator" >> "$tlog"
      else
        echo "No output in test.out" >> "$tlog"
      fi
    fi
  else
    local messages="$tdir/messages"
    if test -e "$tdir/messages" ; then
      if grep -q "FAILED" "$tdir/messages" ; then
        fail "$test_name" F "Messages file contains FAILED message"
      fi
      echo "Messages file:" >> "$tlog"
      echo "$separator" >> "$tlog"
      cat "$tdir/messages" >> "$tlog"
      echo "$separator" >> "$tlog"
    fi
  fi
  if test "$FAILED" = 1 ; then
    travis_fold start "$NVIM_TEST_CURRENT_SUITE/$test_name"
  fi
  valgrind_check .
  if test -n "$LOG_DIR" ; then
    asan_check "$LOG_DIR"
  fi
  check_core_dumps
  if test "$FAILED" = 1 ; then
    cat "$tlog"
  fi
  rm -f "$tlog"
  if test "$FAILED" = 1 ; then
    travis_fold end "$NVIM_TEST_CURRENT_SUITE/$test_name"
  fi
  if test "$FAILED" = 1 ; then
    echo "Test $test_name failed, see output above and summary for more details" >> "$ctlog"
  fi
)}

main "$@"
