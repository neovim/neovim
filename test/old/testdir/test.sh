fail() {
  local test_name="$1"
  local message="$2"

  : "${message:=Test $test_name failed}"

  local full_msg="$test_name :: $message"
  echo "Failed: $full_msg"
  export FAILED=1
}

print_core() {
  local app="$1"
  local core="$2"
  if test "$app" = quiet ; then
    echo "Found core $core"
    return 0
  fi
  echo "======= Core file $core ======="
  if test "${CI_OS_NAME}" = osx ; then
    lldb -Q -o "bt all" -f "${app}" -c "${core}"
  else
    gdb -n -batch -ex 'thread apply all bt full' "${app}" -c "${core}"
  fi
}

check_core_dumps() {
  local del=
  if test "$1" = "--delete" ; then
    del=1
    shift
  fi
  local app="${1:-${BUILD_DIR}/bin/nvim}"
  local cores
  if test "${CI_OS_NAME}" = osx ; then
    cores="$(find /cores/ -type f -print)"
    local _sudo='sudo'
  else
    cores="$(find ./ -type f \( -name 'core.*' -o -name core -o -name nvim.core \) -print)"
    local _sudo=
  fi

  if test -z "${cores}" ; then
    return
  fi
  local core
  for core in $cores; do
    if test "$del" = "1" ; then
      print_core "$app" "$core" >&2
      "$_sudo" rm "$core"
    else
      print_core "$app" "$core"
    fi
  done
  if test "$app" != quiet ; then
    fail 'cores' 'Core dumps found'
  fi
}

check_logs() {
  # Iterate through each log to remove a useless warning.
  # shellcheck disable=SC2044
  for log in $(find "${1}" -type f -name "${2}"); do
    sed -i "${log}" \
      -e '/Warning: noted but unhandled ioctl/d' \
      -e '/could cause spurious value errors to appear/d' \
      -e '/See README_MISSING_SYSCALL_OR_IOCTL for guidance/d'
  done

  # Now do it again, but only consider files with size > 0.
  local err=""
  # shellcheck disable=SC2044
  for log in $(find "${1}" -type f -name "${2}" -size +0); do
    cat "${log}"
    err=1
    rm "${log}"
  done
  if test -n "${err}" ; then
    fail 'logs' 'Runtime errors detected.'
  fi
}

valgrind_check() {
  check_logs "${1}" "valgrind-*"
}

check_sanitizer() {
  check_logs "${1}" "*san.*"
}
