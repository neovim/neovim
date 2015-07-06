check_core_dumps() {
  sleep 2

  if [[ "${TRAVIS_OS_NAME}" == osx ]]; then
    local cores="$(find /cores/ -type f -print)"
    local dbg_cmd="lldb -Q -o bt -f ${BUILD_DIR}/bin/nvim -c"
  else
    # FIXME (fwalch): Will trigger if a file named core.* exists outside of $DEPS_BUILD_DIR.
    local cores="$(find ./ -type f -not -path "*${DEPS_BUILD_DIR}*" -name 'core.*' -print)"
    local dbg_cmd="gdb -n -batch -ex bt ${BUILD_DIR}/bin/nvim"
  fi

  if [ -z "${cores}" ]; then
    return
  fi
  for core in $cores; do
    ${dbg_cmd} "${core}"
  done
  exit 1
}

check_logs() {
  # Iterate through each log to remove an useless warning.
  for log in $(find "${1}" -type f -name "${2}"); do
    sed -i "${log}" \
      -e '/Warning: noted but unhandled ioctl/d' \
      -e '/could cause spurious value errors to appear/d' \
      -e '/See README_MISSING_SYSCALL_OR_IOCTL for guidance/d'
  done

  # Now do it again, but only consider files with size > 0.
  local err=""
  for log in $(find "${1}" -type f -name "${2}" -size +0); do
    cat "${log}"
    err=1
  done
  if [[ -n "${err}" ]]; then
    echo "Runtime errors detected."
    exit 1
  fi
}

valgrind_check() {
  check_logs "${1}" "valgrind-*"
}

asan_check() {
  check_logs "${1}" "*san.*"
}

run_unittests() {
  ${MAKE_CMD} -C "${BUILD_DIR}" unittest
}

run_functionaltests() {
  if ! ${MAKE_CMD} -C "${BUILD_DIR}" functionaltest; then
    asan_check "${LOG_DIR}"
    valgrind_check "${LOG_DIR}"
    exit 1
  fi
  asan_check "${LOG_DIR}"
  valgrind_check "${LOG_DIR}"
}

run_oldtests() {
  if ! make -C "${TRAVIS_BUILD_DIR}/src/nvim/testdir"; then
    reset
    asan_check "${LOG_DIR}"
    valgrind_check "${LOG_DIR}"
    exit 1
  fi
  asan_check "${LOG_DIR}"
  valgrind_check "${LOG_DIR}"
}

install_nvim() {
  ${MAKE_CMD} -C "${BUILD_DIR}" install

  "${INSTALL_PREFIX}/bin/nvim" --version
  "${INSTALL_PREFIX}/bin/nvim" -u NONE -e -c ':help' -c ':qall' || {
    echo "Running ':help' in the installed nvim failed."
    echo "Maybe the helptags have not been generated properly."
    exit 1
  }
}

run_integrationtests() {
  echo "set rtp+=${PLUGIN_DIR}/junegunn/vader.vim" > "${PLUGIN_DIR}/nvimrc"

  local plugin
  local exec_plugin
  while read line; do
    if [[ -z "${line}" ]]; then
      if [[ -n "${exec_plugin}" ]]; then
        echo -n "Running Vader tests for ${exec_plugin} "
        local log_file="${LOG_DIR}/${exec_plugin}_vader.log"
        rm -f "${log_file}"
        if ! "${INSTALL_PREFIX}/bin/nvim" -u "${PLUGIN_DIR}/${exec_plugin}/__nvimrc" \
                                          -c "autocmd VimExit * windo w! >> ${log_file}"
                                          -c "Vader! ${PLUGIN_DIR}/${exec_plugin}/test*/*.vader"; then
          echo "failed."
          cat "${log_file}"
          exit 1
        else
          echo "succeeded."
        fi
      fi
      exec_plugin=
      continue
    fi
    plugin="$(cut -d ' ' -f 1 <<< "${line}")"

    if [[ -z "${exec_plugin}" ]]; then
      exec_plugin="${plugin}"
      echo "source ${PLUGIN_DIR}/nvimrc" > "${PLUGIN_DIR}/${exec_plugin}/__nvimrc"
    else
      # Add $plugin as dependency of $exec_plugin.
      echo "set rtp+=${PLUGIN_DIR}/${plugin}" >> "${PLUGIN_DIR}/${exec_plugin}/__nvimrc"
    fi
  done <<< "$(tail -n +2 "${CI_DIR}/common/plugins.txt")"

  cd "${TRAVIS_BUILD_DIR}"
}
