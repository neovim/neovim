#!/usr/bin/env bash
set -e
set -u
# Use privileged mode, which e.g. skips using CDPATH.
set -p

# Ensure that the user has a bash that supports -A
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo >&2 "error: script requires bash 4+ (you have ${BASH_VERSION})."
  exit 1
fi

readonly NVIM_SOURCE_DIR="${NVIM_SOURCE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
readonly VIM_SOURCE_DIR_DEFAULT="${NVIM_SOURCE_DIR}/.vim-src"
readonly VIM_SOURCE_DIR="${VIM_SOURCE_DIR:-${VIM_SOURCE_DIR_DEFAULT}}"
BASENAME="$(basename "${0}")"
readonly BASENAME

usage() {
  echo "Bump Nvim dependencies"
  echo
  echo "Usage:  ${BASENAME} [ -h | --pr | --branch=<dep> | --dep=<dependency> ]"
  echo "    Update a dependency:"
  echo "        ./scripts/bump-deps.sh --dep Luv --version 1.43.0-0"
  echo "    Create a PR:"
  echo "        ./scripts/bump-deps.sh --pr"
  echo
  echo "Options:"
  echo "    -h                    show this message and exit."
  echo "    --pr                  submit pr for bumping deps."
  echo "    --branch=<dep>        create a branch bump-<dep> from current branch."
  echo "    --dep=<dependency>    bump to a specific release or tag."
  echo
  echo "Dependency Options:"
  echo "    --version=<tag>       bump to a specific release or tag."
  echo "    --commit=<hash>       bump to a specific commit."
  echo "    --HEAD                bump to a current head."
  echo
  echo "    <dependency> is one of:"
  echo "    \"LuaJIT\", \"libuv\", \"Luv\", \"tree-sitter\""
}

# Checks if a program is in the user's PATH, and is executable.
check_executable() {
  test -x "$(command -v "${1}")"
}

require_executable() {
  if ! check_executable "${1}"; then
    echo >&2 "${BASENAME}: '${1}' not found in PATH or not executable."
    exit 1
  fi
}

require_executable "nvim"

if [ $# -eq 0 ]; then
  usage
  exit 1
fi

PARSED_ARGS=$(getopt -a -n "$BASENAME" -o h --long pr,branch:,dep:,version:,commit:,HEAD -- "$@")

DEPENDENCY=""
eval set -- "$PARSED_ARGS"
while :; do
  case "$1" in
  -h)
    usage
    exit 0
    ;;
  --pr)
    nvim -es +"lua require('scripts.bump_deps').submit_pr()"
    exit 0
    ;;
  --branch)
    DEP=$2
    nvim -es +"lua require('scripts.bump_deps').create_branch('$DEP')"
    exit 0
    ;;
  --dep)
    DEPENDENCY=$2
    shift 2
    ;;
  --version)
    VERSION=$2
    nvim -es +"lua require('scripts.bump_deps').version('$DEPENDENCY', '$VERSION')"
    exit 0
    ;;
  --commit)
    COMMIT=$2
    nvim -es +"lua require('scripts.bump_deps').commit('$DEPENDENCY', '$COMMIT')"
    exit 0
    ;;
  --HEAD)
    nvim -es +"lua require('scripts.bump_deps').head('$DEPENDENCY')"
    exit 0
    ;;
  *)
    break
    ;;
  esac
done

usage
exit 1

# vim: et sw=2
