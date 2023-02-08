# If FAIL_SUMMARY_FILE exists we know that some tests failed, this file will
# contain information about failed tests. Build is considered successful if
# tests ended without any of them failing.
FAIL_SUMMARY_FILE="$BUILD_DIR/.test_errors"

fail() {
  local test_name="$1"
  local message="$2"

  : "${message:=Test $test_name failed}"

  local full_msg="$test_name :: $message"
  echo "${full_msg}" >> "${FAIL_SUMMARY_FILE}"
  echo "Failed: $full_msg"
  export FAILED=1
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
  return 0
}
