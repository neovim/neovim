fail() {
  local test_name="$1"
  local message="$2"

  : "${message:=Test $test_name failed}"

  local full_msg="$test_name :: $message"
  echo "Failed: $full_msg"
  export FAILED=1
}
