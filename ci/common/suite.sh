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

ANSI_CLEAR="\033[0K"

travis_fold() {
  local action="$1"
  local name="$2"
  name="$(echo -n "$name" | tr '\n\0' '--' | sed 's/[^A-Za-z0-9]\{1,\}/-/g')"
  name="$(echo -n "$name" | sed 's/-$//')"
  echo -en "travis_fold:${action}:${name}\r${ANSI_CLEAR}"
}

if test "$TRAVIS" != "true" ; then
  travis_fold() {
    return 0
  }
fi

enter_suite() {
  set +x
  FAILED=0
  rm -f "${END_MARKER}"
  local suite_name="$1"
  export NVIM_TEST_CURRENT_SUITE="${NVIM_TEST_CURRENT_SUITE}/$suite_name"
  travis_fold start "${NVIM_TEST_CURRENT_SUITE}"
  set -x
}

exit_suite() {
  set +x
  if test $FAILED -ne 0 ; then
    echo "Suite ${NVIM_TEST_CURRENT_SUITE} failed, summary:"
    echo "${FAIL_SUMMARY}"
  else
    travis_fold end "${NVIM_TEST_CURRENT_SUITE}"
  fi
  export NVIM_TEST_CURRENT_SUITE="${NVIM_TEST_CURRENT_SUITE%/*}"
  if test "$1" != "--continue" ; then
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
  if test "$1" = "--allow-hang" ; then
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
        CI_DIR="$CI_DIR" \
        sh -c '
          . "${CI_DIR}/common/test.sh"
          ps -o sid= > "$sid_file"
          (
            ret=0
            if ! eval "$cmd" 2>&1 ; then
              ret=1
            fi
            echo "$ret" > "$status_file"
          ) | tee -a "$output_file"
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
        if test -z "$hang_ok" ; then
          fail "$test_name" E "Test hang up"
        fi
      else
        echo "Test ${test_name} hang up, restarting"
        eval "$restart_cmd"
      fi
    else
      local new_failed="$(cat "$status_file")"
      if test "$new_failed" != "0" ; then
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
  if test -f "${FAIL_SUMMARY_FILE}" ; then
    echo 'Test failed, complete summary:'
    cat "${FAIL_SUMMARY_FILE}"
    return 1
  fi
  if ! test -f "${END_MARKER}" ; then
    echo 'ended_successfully called before end marker was touched'
    return 1
  fi
  return 0
}

end_tests() {
  touch "${END_MARKER}"
  ended_successfully
}
