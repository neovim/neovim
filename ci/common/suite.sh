# HACK: get newline for use in strings given that "\n" and $'' do not work.
NL="$(printf '\nE')"
NL="${NL%E}"

FAIL_SUMMARY=""

# Test success marker. If END_MARKER file exists, we know that all tests 
# finished. If FAIL_SUMMARY_FILE exists we know that some tests failed, this 
# file will contain information about failed tests. Build is considered 
# successful if tests ended without any of them failing.
END_MARKER="$BUILD_DIR/.tests_finished"
FAIL_SUMMARY_FILE="$BUILD_DIR/.test_errors"

enter_suite() {
  FAILED=0
  rm -f "${END_MARKER}"
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
  else
    local saved_failed=$FAILED
    FAILED=0
    return $saved_failed
  fi
}

fail() {
  local test_name="$1"
  local fail_char="$2"
  local message="$3"

  : ${fail_char:=F}
  : ${message:=Test $test_name failed}

  local full_msg="$fail_char $NVIM_TEST_CURRENT_SUITE|$test_name :: $message"
  FAIL_SUMMARY="${FAIL_SUMMARY}${NL}${full_msg}"
  echo "${full_msg}" >> "${FAIL_SUMMARY_FILE}"
  echo "Failed: $full_msg"
  FAILED=1
}

run_test() {
  local cmd="$1"
  test $# -gt 0 && shift
  local test_name="$1"
  : ${test_name:=$cmd}
  test $# -gt 0 && shift
  if ! eval "$cmd" ; then
    fail "${test_name}" "$@"
  fi
}

run_test_wd() {
  local hang_ok=
  if test "x$1" = "x--allow-hang" ; then
    hang_ok=1
    shift
  fi

  local timeout="$1"
  test $# -gt 0 && shift

  local cmd="$1"
  test $# -gt 0 && shift

  local restart_cmd="$1"
  : ${restart_cmd:=true}
  test $# -gt 0 && shift

  local test_name="$1"
  : ${test_name:=$cmd}
  test $# -gt 0 && shift

  local output_file="$(mktemp)"
  local status_file="$(mktemp)"
  local sid_file="$(mktemp)"

  local restarts=5
  local prev_tmpsize=-1
  while test $restarts -gt 0 ; do
    : > "$status_file"
    : > "$sid_file"
    setsid \
      env \
        output_file="$output_file" \
        status_file="$status_file" \
        sid_file="$sid_file" \
        cmd="$cmd" \
        sh -c '
          ps -o sid= > "$sid_file"
          ret=0
          if ! eval "$cmd" 2>&1 | tee -a "$output_file" ; then
            ret=1
          fi
          echo "$ret" > "$status_file"
        '
    while test "$(stat -c "%s" "$status_file")" -eq 0 ; do
      prev_tmpsize=$tmpsize
      sleep $timeout
      tmpsize="$(stat -c "%s" "$output_file")"
      if test $tempsize -eq $prev_temsize ; then
        # no output, assuming either hang or exit
        break
      fi
    done
    restarts=$(( restarts - 1 ))
    if test "$(stat -c "%s" "$status_file")" -eq 0 ; then
      # Status file not updated, assuming hang

      # SID not known, this should not ever happen
      if test "$(stat -c "%s" "$sid_file")" -eq 0 ; then
        fail "$test_name" E "Shell did not run"
        break
      fi

      # Kill all processes which belong to one session: should get rid of test
      # processes as well as sh itself.
      pkill -KILL -s$(cat "$sid_file")

      if test $restarts -eq 0 ; then
        if test "x$hang_ok" = "x" ; then
          fail "$test_name" E "Test hang up"
        fi
      else
        echo "Test ${test_name} hang up, restarting"
        eval "$restart_cmd"
      fi
    else
      local new_failed="$(cat "$status_file")"
      if test "x$new_failed" != "x0" ; then
        fail "$test_name" F "Test failed in run_test_wd"
      fi
      break
    fi
  done

  rm -f "$output_file"
  rm -f "$status_file"
  rm -f "$sid_file"
}

ended_successfully() {
  if [[ -f "${FAIL_SUMMARY_FILE}" ]]; then
    echo 'Test failed, complete summary:'
    cat "${FAIL_SUMMARY_FILE}"
    return 1
  fi
  if ! [[ -f "${END_MARKER}" ]] ; then
    echo 'ended_successfully called before end marker was touched'
    return 1
  fi
  return 0
}

end_tests() {
  touch "${END_MARKER}"
  ended_successfully
}
