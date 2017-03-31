# HACK: get newline for use in strings given that "\n" and $'' do not work.
NL="$(printf '\nE')"
NL="${NL%E}"

FAILED=0

FAIL_SUMMARY=""

enter_suite() {
  local suite_name="$1"
  export NVIM_TEST_CURRENT_SUITE="${NVIM_TEST_CURRENT_SUITE}/$suite_name"
}

exit_suite() {
  if test $FAILED -ne 0 ; then
    echo "Suite ${NVIM_TEST_CURRENT_SUITE} failed, summary:"
    echo "${FAIL_SUMMARY}"
  fi
  export NVIM_TEST_CURRENT_SUITE="${NVIM_TEST_CURRENT_SUITE%/*}"
  if test "x$1" != "x--continue" ; then
    exit $FAILED
  fi
}

fail() {
  local allow_failure=
  if test "x$1" = "x--allow-failure" ; then
    shift
    allow_failure=A
  fi
  local test_name="$1"
  local fail_char="$allow_failure$2"
  local message="$3"

  : ${fail_char:=F}
  : ${message:=Test $test_name failed}

  local full_msg="$fail_char $NVIM_TEST_CURRENT_SUITE|$test_name :: $message"
  FAIL_SUMMARY="${FAIL_SUMMARY}${NL}${full_msg}"
  echo "Failed: $full_msg"
  if test "x$allow_failure" = "x" ; then
    FAILED=1
  fi
}

run_test() {
  local cmd="$1"
  shift
  local test_name="$1"
  : ${test_name:=$cmd}
  shift
  if ! eval "$cmd" ; then
    fail "${test_name}" "$@"
  fi
}

run_test_wd() {
  local timeout="$1"
  shift
  local cmd="$1"
  shift
  local test_name="$1"
  : ${test_name:=$cmd}
  shift
  local output_file="$(mktemp)"
  local status_file="$(mktemp)"
  local restarts=5
  local prev_tmpsize=-1
  while test $restarts -gt 0 ; do
    : > "${status_file}"
    (
      if ! (
        set -o pipefail
        eval "$cmd" 2>&1 | tee -a "$output_file"
      ) ; then
        fail "${test_name}" "$@"
      fi
      echo "$FAILED" > "$status_file"
    ) &
    local pid=$!
    while test "$(stat -c "%s" "$status_file")" -eq 0 ; do
      prev_tmpsize=$tmpsize
      sleep $timeout
      tmpsize="$(stat -c "%s" "$output_file")"
      if test $tempsize -eq $prev_temsize ; then
        # no output, assuming either hang or exit
        break
      fi
    done
    if test "$(stat -c "%s" "$status_file")" -eq 0 ; then
      # status file not updated, assuming hang
      kill -KILL $pid
      echo "Test ${test_name} hang up, restarting"
    else
      local new_failed="$(cat "$status_file")"
      if test "x$new_failed" != "x0" ; then
        fail "${test_name}" F "Test failed in run_test_wd"
      fi
      return 0
    fi
    restarts=$[ restarts - 1 ]
  done
}

succeeded() {
  return $FAILED
}
