#!/usr/bin/env bash
# set -v
# set -x
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

# TODO: add example
usage() {
  echo "Bump Neovim dependencies"
  echo
  echo "Usage:  ${BASENAME} <dependency> [-h | --version=<tag> | --commit=<hash> | --HEAD]"
  echo
  echo "Options:"
  echo "    -h                 Show this message and exit."
  echo "    --version=<tag>    Bump to a specific release or tag."
  echo "    --commit=<hash>    Bump to a specific commit."
  echo "    --HEAD             Bump to a current HEAD."
  echo
  echo "    <dependency> is one of:"
  echo "    \"LuaJIT\", \"libuv\", \"Luv\", \"tree-sitter\""
  echo
  echo "Examples:"
  echo
  echo " - List missing patches for a given file (in the Vim source):"
  echo "   $0 -l -- src/edit.c"
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

cmake_symbol() {
  case "$1" in
  "LuaJIT")
    echo "LUAJIT"
    ;;
  "libuv")
    echo "LIBUV"
    ;;
  "Luv")
    echo "LUV"
    ;;
  "tree-sitter")
    echo "TREESITTER"
    ;;
  "*")
    exit 1
    ;;
  esac
}

repo_location() {
  case "$1" in
  "LuaJIT")
    echo "LuaJIT/LuaJIT"
    ;;
  "libuv")
    echo "libuv/libuv"
    ;;
  "Luv")
    echo "luvit/luv"
    ;;
  "tree-sitter")
    echo "tree-sitter/tree-sitter"
    ;;
  "*")
    exit 1
    ;;
  esac
}

update_cmakelists() {
  local dependency
  local ref
  local location
  local hash
  local cmakelists
  local cmakesymbol

  dependency=$1
  ref=$2
  location=$3
  hash=$4
  cmakelists="$NVIM_SOURCE_DIR/third-party/CMakeLists.txt"
  cmakesymbol=$(cmake_symbol "$dependency")

  if [ -z "$ref" ]; then
    ref="HEAD"
  fi

  # escape '/' for sed
  location=$(echo "$location" | sed -e 's/\//\\\//g')

  sed -i -e "s/set(${cmakesymbol}_URL .*\$/set(${cmakesymbol}_URL $location) # ref: $ref/" "$cmakelists"
  sed -i -e "s/set(${cmakesymbol}_SHA256 .*\$/set(${cmakesymbol}_SHA256 $hash)/" "$cmakelists"
}

update_to_ref() {
  require_executable sed
  require_executable curl
  require_executable sha256sum

  local dependency
  local ref
  local archive_src
  local archive_location
  local archive_name
  local archive_hash
  local archive_headers
  local temp_dir

  dependency=$1
  ref=$2

  archive_src="https://api.github.com/repos/$(repo_location "$dependency")/tarball"
  if [ -n "$ref" ]; then
    archive_src="$archive_src/$ref"
  fi

  archive_location=$(
    curl -sI -H "Accept: application/vnd.github.v3+json" "$archive_src" |
      sed -n '/location:/p' |
      sed -e 's/location: //' |
      sed -e 's/\r$//'
  )

  temp_dir="$NVIM_SOURCE_DIR/tmp"
  mkdir -p "$temp_dir"

  archive_headers=$(curl -sI "$archive_location")

  echo "Fetching Archive"
  archive_status=$(
    echo "$archive_headers" |
      sed -n '/HTTP/p' |
      sed -e 's/HTTP\/\S* //' |
      sed -e 's/\r$//'
  )
  if [ "$archive_status" -eq 404 ]; then
    echo "Invalid Ref \"$ref\" for $dependency"
    exit 1
  fi
  archive_name=$(
    echo "$archive_headers" |
      sed -n '/filename=/p' |
      sed -e 's/.*filename=//' |
      sed -e 's/\r$//'
  )

  if [ -f "$temp_dir/$archive_name" ]; then
    rm "$temp_dir/$archive_name"
  fi
  cd "$temp_dir"
  curl -sX GET "$archive_location" -OJ
  cd ..

  archive_hash=$(sha256sum "$temp_dir/$archive_name" | sed 's/ .*//')

  echo "LOCATION: $archive_location"
  echo "HASH (SHA256): $archive_hash"

  update_cmakelists "$dependency" "$ref" "$archive_location" "$archive_hash"
}

update_to_version() {
  local dependency
  local version
  dependency=$1
  version=$2
  echo "Using version $version of $dependency"
  update_to_ref "$dependency" "$version"
}

update_to_commit() {
  local dependency
  local commit
  dependency=$1
  commit=$2
  echo "Using commit $commit of $dependency"
  update_to_ref "$dependency" "$commit"
}

update_to_head() {
  local dependency
  dependency=$1
  echo "Using HEAD of $dependency"
  update_to_ref "$dependency" ""
}

DEPENDENCY=$1
shift

case $DEPENDENCY in
"LuaJIT" | "libuv" | "Luv" | "tree-sitter") ;;
*)
  echo "Not a dependency: \"$DEPENDENCY\""
  exit 1
  ;;
esac

PARSED_ARGS=$(getopt -a -n "$BASENAME" -o h --long version:,commit:,HEAD -- "$@")

eval set -- "$PARSED_ARGS"
while :; do
  case "$1" in
  -h)
    usage
    exit 0
    ;;
  --version)
    VERSION=$2
    update_to_version "$DEPENDENCY" "$VERSION"
    exit 0
    ;;
  --commit)
    COMMIT=$2
    update_to_commit "$DEPENDENCY" "$COMMIT"
    exit 0
    ;;
  --HEAD)
    update_to_head "$DEPENDENCY"
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
