#!/bin/bash

tests_run=( )
tests_passed=( )
tests_skipped=( )

prog=../../build/bin/nvim

RM_ON_RUN="test.out X* viminfo"
RM_ON_START="tiny.vim small.vim mbyte.vim mzscheme.vim lua.vim test.ok"

out() {
  echo "$@" >&3
}

run_vim() {
  "$prog" -u unix.vim -U NONE --noplugin -s dotest.in "$@"
}

run_test() {
  if [[ ! -f test$1.in || ! -f test$1.ok ]] ; then
    out "Test $1 doesn't exist"
    tests_skipped=( "${tests_skipped[@]}" "$1" )
    return
  fi

  out -n "Running test $1..."
  rm -rf test$1.failed test.ok $RM_ON_RUN
  cp test$1.ok test.ok
  sleep .2 > /dev/null 2>&1 || sleep 1
  run_vim test$1.in
  tests_run=( "${tests_run[@]}" "$1" )

  if diff test.out test$1.ok ; then
    out "pass"
    tests_passed=( "${tests_passed[@]}" "$1" )
    mv -f test.out test$1.out
  else
    out "fail"
    tests_failed=( "${tests_failed[@]}" "$1" )
    mv -f test.out test$1.failed
  fi

  if [[ -f valgrind ]] ; then
    mv -f valgrind valgrind.test$1
  fi

  rm -rf X* test.ok viminfo
}

run_test_1() {
  out -n "Running preliminary check..."
  rm -rf test1.failed $RM_ON_RUN $RM_ON_START wrongtermsize
  run_vim test1.in
  if [[ -e wrongtermsize ]] ; then
    out "fail"
    return 1
  elif diff test.out test1.ok ; then
    mv -f test.out test1.out
  else
    out "fail"
    return 1
  fi
  out "pass"
  rm -rf X* viminfo
}

run_tests() {
  rm -rf *.out *.failed *.rej *.orig test.log $RM_ON_RUN $RM_ON_START valgrind.*
  if ! run_test_1 ; then
    return 1
  fi
  for i in $1 ; do
    run_test $i
  done
  out "${#tests_passed[@]} of ${#tests_run[@]} tests passed (${#tests_skipped[@]} skipped)"
  out "Tests which failed: ${tests_failed[@]}"
  out "Tests which were skipped: ${tests_skipped[@]}"
  if [[ "${#tests_failed[@]}" -gt 0 ]] ; then
    return 1
  else
    return 0
  fi
}

tests=
tmpdir=

while getopts d:t: opt ; do
  case $opt in
    d) tmpdir="$OPTARG" ;;
    t) tests="$OPTARG" ;;
    ?) echo "Usage: $0 [-d <tmpdir>] [-t <tests>]" ;;
  esac
done

if [[ -z "$tmpdir" ]] ; then
  exec 3>&2
else
  exec >"$tmpdir/stdout"
  exec 2>"$tmpdir/stderr"
  exec 3>"$tmpdir/progress"
fi

if [[ -z "$tests" ]] ; then
  tests="$(seq 2 103)"
fi

if run_tests "$tests" ; then
  result=0
else
  result=1
fi

echo "$result" > "$tmpdir/result"
exit "$result"
