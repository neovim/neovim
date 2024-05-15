#!/usr/bin/env bash

# Usage:
#   ./scripts/release.sh
#   ./scripts/release.sh --use-current-commit
#   ./scripts/release.sh --only-bump
#
# Performs steps to tag a release.
#
# Steps:
#   Create the "release" commit:
#     - CMakeLists.txt: Unset NVIM_VERSION_PRERELEASE
#     - CMakeLists.txt: Unset NVIM_API_PRERELEASE
#     - Create test/functional/fixtures/api_level_N.mpack
#     - Add date and version to runtime/nvim.appdata.xml
#     - Tag the commit.
#   Create the "version bump" commit:
#     - CMakeLists.txt: Set NVIM_VERSION_PRERELEASE to "-dev"

set -e
set -u
set -o pipefail

ARG1=${1:-no}

__sed=$( [ "$(uname)" = Darwin ] && echo 'sed -E' || echo 'sed -r' )

cd "$(git rev-parse --show-toplevel)"

__DATE=$(date +'%Y-%m-%d')
__LAST_TAG=$(git describe --abbrev=0)
[ -z "$__LAST_TAG" ] && { echo 'ERROR: no tag found'; exit 1; }
__VERSION_MAJOR=$(grep 'set(NVIM_VERSION_MAJOR' CMakeLists.txt\
  |$__sed 's/.*NVIM_VERSION_MAJOR ([[:digit:]]+).*/\1/')
__VERSION_MINOR=$(grep 'set(NVIM_VERSION_MINOR' CMakeLists.txt\
  |$__sed 's/.*NVIM_VERSION_MINOR ([[:digit:]]+).*/\1/')
__VERSION_PATCH=$(grep 'set(NVIM_VERSION_PATCH' CMakeLists.txt\
  |$__sed 's/.*NVIM_VERSION_PATCH ([[:digit:]]+).*/\1/')
__VERSION="${__VERSION_MAJOR}.${__VERSION_MINOR}.${__VERSION_PATCH}"
__API_LEVEL=$(grep 'set(NVIM_API_LEVEL ' CMakeLists.txt\
  |$__sed 's/.*NVIM_API_LEVEL ([[:digit:]]+).*/\1/')
{ [ -z "$__VERSION_MAJOR" ] || [ -z "$__VERSION_MINOR" ] || [ -z "$__VERSION_PATCH" ]; } \
  &&  { echo "ERROR: version parse failed: '${__VERSION}'"; exit 1; }
__RELEASE_MSG="NVIM v${__VERSION}

"
__BUMP_MSG="version bump"

echo "Most recent tag: ${__LAST_TAG}"
echo "Release version: ${__VERSION}"

_git_log_pretty() {
  git cliff --config scripts/cliff.toml --unreleased || echo 'git cliff failed'
}

_do_release_commit() {
  $__sed -i.bk 's/(NVIM_VERSION_PRERELEASE) "-dev"/\1 ""/' CMakeLists.txt
  if grep '(NVIM_API_PRERELEASE true)' CMakeLists.txt > /dev/null; then
    $__sed -i.bk 's/(NVIM_API_PRERELEASE) true/\1 false/' CMakeLists.txt
    build/bin/nvim --api-info > "test/functional/fixtures/api_level_$__API_LEVEL.mpack"
    git add "test/functional/fixtures/api_level_${__API_LEVEL}.mpack"
    VIMRUNTIME=./runtime build/bin/nvim -u NONE -l scripts/gen_vimdoc.lua
    git add -u -- runtime/doc/
  fi

  $__sed -i.bk 's,(<releases>),\1\
    <release date="'"${__DATE}"'" version="'"${__VERSION}"'"/>,' runtime/nvim.appdata.xml
  git add runtime/nvim.appdata.xml

  if ! test "$ARG1" = '--use-current-commit' ; then
    echo "Building changelog since ${__LAST_TAG}..."

    git add CMakeLists.txt
    (echo "${__RELEASE_MSG}"; _git_log_pretty) | git commit --edit -F -
  fi

  git tag --sign -a v"${__VERSION}" -m "NVIM v${__VERSION}"
}

_do_bump_commit() {
  $__sed -i.bk 's/(NVIM_VERSION_PRERELEASE) ""/\1 "-dev"/' CMakeLists.txt
  $__sed -i.bk 's/set\((NVIM_VERSION_PATCH) [[:digit:]]/set(\1 ?/' CMakeLists.txt
  rm -f CMakeLists.txt.bk
  rm -f runtime/nvim.appdata.xml.bk
  nvim +'/NVIM_VERSION' +1new +'exe "norm! iUpdate version numbers!!!"' \
    -O CMakeLists.txt

  git add CMakeLists.txt
  git commit -m "$__BUMP_MSG"
}

if ! test "$ARG1" = '--only-bump' ; then
  _do_release_commit
fi
_do_bump_commit
echo "
Next steps:
    - Run tests/CI (version_spec.lua)!
    - Push the tag:
        git push --follow-tags
    - Update website: index.html"
