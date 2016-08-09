statcmd() {
  if [[ "${TRAVIS_OS_NAME}" == osx ]]; then
    local statcmd="stat -f %Sm"
  else
    local statcmd="stat -c %y"
  fi

  ${statcmd} "${@}"
}
