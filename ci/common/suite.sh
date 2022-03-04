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
}

exit_suite() {
  if test $FAILED -ne 0 ; then
    echo "Test failed, summary:"
    echo "${FAIL_SUMMARY}"
  fi
  FAILED=0
}

fail() {
  local test_name="$1"
  local message="$2"

  : ${message:=Test $test_name failed}

  local full_msg="$test_name :: $message"
  FAIL_SUMMARY="${FAIL_SUMMARY}${NL}${full_msg}"
  echo "${full_msg}" >> "${FAIL_SUMMARY_FILE}"
  echo "Failed: $full_msg"
  FAILED=1
}

ended_successfully() {
  if test -f "${FAIL_SUMMARY_FILE}" ; then
    echo 'Test failed, complete summary:'
    cat "${FAIL_SUMMARY_FILE}"

    if [[ "$GITHUB_ACTIONS" == "true" ]]; then
        rm -f "$FAIL_SUMMARY_FILE"
    fi

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

run_suite() {
  local command="$1"
  local suite_name="$2"

  enter_suite
  eval "$command" || fail "$suite_name"
  exit_suite
}
