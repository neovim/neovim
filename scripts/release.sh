#!/bin/sh

# Performs steps to tag a release.
#
# Steps:
#   Create the "release" commit:
#     - CMakeLists.txt: Unset NVIM_VERSION_PRERELEASE
#     - Tag the commit.
#   Create the "version bump" commit:
#     - CMakeLists.txt: Set NVIM_VERSION_PRERELEASE to "-dev"
#
# Manual steps:
#   - CMakeLists.txt: Bump NVIM_VERSION_* as appropriate.
#   - git push --follow-tags

set -e
set -u
set -o pipefail

cd "$(git rev-parse --show-toplevel)"

__LAST_TAG=$(git describe --abbrev=0)
[ -z "$__LAST_TAG" ] && { echo 'ERROR: no tag found'; exit 1; }
__VERSION_MAJOR=$(grep 'set(NVIM_VERSION_MAJOR' CMakeLists.txt\
  |sed -r 's/.*NVIM_VERSION_MAJOR ([[:digit:]]).*/\1/')
__VERSION_MINOR=$(grep 'set(NVIM_VERSION_MINOR' CMakeLists.txt\
  |sed -r 's/.*NVIM_VERSION_MINOR ([[:digit:]]).*/\1/')
__VERSION_PATCH=$(grep 'set(NVIM_VERSION_PATCH' CMakeLists.txt\
  |sed -r 's/.*NVIM_VERSION_PATCH ([[:digit:]]).*/\1/')
__VERSION="${__VERSION_MAJOR}.${__VERSION_MINOR}.${__VERSION_PATCH}"
{ [ -z "$__VERSION_MAJOR" ] || [ -z "$__VERSION_MINOR" ] || [ -z "$__VERSION_PATCH" ]; } \
  &&  { echo "ERROR: version parse failed: '${__VERSION}'"; exit 1; }
__RELEASE_MSG="NVIM v${__VERSION}

Features:

Fixes:

Changes:

"
__BUMP_MSG="version bump"

echo "Most recent tag: ${__LAST_TAG}"
echo "Release version: ${__VERSION}"
sed -i -r 's/(NVIM_VERSION_PRERELEASE) "-dev"/\1 ""/' CMakeLists.txt
echo "Building changelog since ${__LAST_TAG}..."
__CHANGELOG="$(./scripts/git-log-pretty-since.sh "$__LAST_TAG" 'vim-patch:\S')"

git add CMakeLists.txt
git commit --edit -m "${__RELEASE_MSG} ${__CHANGELOG}"
git tag -a v"${__VERSION}" -m "NVIM v${__VERSION}"

sed -i -r 's/(NVIM_VERSION_PRERELEASE) ""/\1 "-dev"/' CMakeLists.txt
nvim -c '/NVIM_VERSION' -c 'echo "Update version numbers"' CMakeLists.txt
git add CMakeLists.txt
git commit -m "$__BUMP_MSG"

echo "
Next steps:
    - Double-check NVIM_VERSION_* in CMakeLists.txt
    - git push --follow-tags
    - update website: index.html"
