#!/usr/bin/env bash

set -e
set -u
set -o pipefail

readonly NEOVIM_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly VIM_SOURCE_DIR_DEFAULT=${NEOVIM_SOURCE_DIR}/.vim-src
readonly VIM_SOURCE_DIR="${VIM_SOURCE_DIR:-${VIM_SOURCE_DIR_DEFAULT}}"
readonly BASENAME="$(basename "${0}")"

usage() {
  echo "Helper script for porting Vim patches. For more information, see"
  echo "https://github.com/neovim/neovim/wiki/Merging-patches-from-upstream-vim"
  echo
  echo "Usage:  ${BASENAME} [-h | -l | -p vim-revision | -r pr-number]"
  echo
  echo "Options:"
  echo "    -h                 Show this message and exit."
  echo "    -l                 Show list of Vim patches missing from Neovim."
  echo "    -p {vim-revision}  Download and apply the Vim patch vim-revision."
  echo "                       vim-revision can be a version number of the "
  echo "                       format '7.4.xxx' or a Git commit hash."
  echo "    -r {pr-number}     Review a vim-patch pull request to Neovim."
  echo
  echo "Set VIM_SOURCE_DIR to change where Vim's sources are stored."
  echo "The default is '${VIM_SOURCE_DIR_DEFAULT}'."
}

# Checks if a program is in the user's PATH, and is executable.
check_executable() {
  if [[ ! -x $(command -v "${1}") ]]; then
    >&2 echo "${BASENAME}: '${1}' not found in PATH or not executable."
    exit 1
  fi
}

get_vim_sources() {
  check_executable git

  echo "Retrieving Vim sources."
  if [[ ! -d ${VIM_SOURCE_DIR} ]]; then
    echo "Cloning Vim sources into '${VIM_SOURCE_DIR}'."
    git clone --depth=1000 https://github.com/vim/vim.git "${VIM_SOURCE_DIR}"
    cd "${VIM_SOURCE_DIR}"
  else
    if [[ ! -d "${VIM_SOURCE_DIR}/.git" ]]; then
      echo "✘ ${VIM_SOURCE_DIR} does not appear to be a git repository."
      echo "  Please remove it and try again."
      exit 1
    fi
    echo "Updating Vim sources in '${VIM_SOURCE_DIR}'."
    cd "${VIM_SOURCE_DIR}"
    git pull &&
      echo "✔ Updated Vim sources." ||
      echo "✘ Could not update Vim sources; ignoring error."
  fi
}

commit_message() {
  echo "vim-patch:${vim_version}

${vim_message}

${vim_commit_url}"
}

assign_commit_details() {
  if [[ ${1} =~ [0-9]\.[0-9]\.[0-9]{3,4} ]]; then
    # Interpret parameter as version number (tag).
    vim_version="${1}"
    vim_tag="v${1}"
    vim_commit=$( cd "${VIM_SOURCE_DIR}" \
      && git log -1 --format="%H" ${vim_tag} )
    local strip_commit_line=true
  else
    # Interpret parameter as commit hash.
    vim_version="${1:0:7}"
    vim_commit="${1}"
    local strip_commit_line=false
  fi

  vim_commit_url="https://github.com/vim/vim/commit/${vim_commit}"
  vim_message="$(git log -1 --pretty='format:%B' "${vim_commit}")"
  if [[ ${strip_commit_line} == "true" ]]; then
    # Remove first line of commit message.
    vim_message="$(echo "${vim_message}" | sed -e '1d')"
  fi
}

get_vim_patch() {
  get_vim_sources

  assign_commit_details "${1}"

  git log -1 "${vim_commit}" -- >/dev/null 2>&1 || {
    >&2 echo "✘ Couldn't find Vim revision '${vim_commit}'."
    exit 3
  }
  echo
  echo "✔ Found Vim revision '${vim_commit}'."

  # Collect patch details and store into variables.
  vim_full="$(git show -1 --pretty=medium "${vim_commit}")"
  vim_diff="$(git show -1 "${vim_commit}" \
    | sed -e 's/\( [ab]\/src\)/\1\/nvim/g')" # Change directory to src/nvim.
  neovim_message="$(commit_message)"
  neovim_pr="
\`\`\`
${vim_message}
\`\`\`

${vim_commit_url}

Original patch:

\`\`\`diff
${vim_diff}
\`\`\`"
  neovim_branch="vim-${vim_version}"

  echo
  echo "Creating Git branch."
  cd "${NEOVIM_SOURCE_DIR}"
  output="$(git checkout -b "${neovim_branch}" 2>&1)" &&
    echo "✔ ${output}" ||
    (echo "✘ ${output}"; false)

  echo
  echo "Creating empty commit with correct commit message."
  output="$(git commit --allow-empty --file 2>&1 - <<< "${neovim_message}")" &&
    echo "✔ ${output}" ||
    (echo "✘ ${output}"; false)

  echo
  echo "Creating files."
  echo "${vim_diff}" > "${NEOVIM_SOURCE_DIR}/${neovim_branch}.diff"
  echo "✔ Saved diff to '${NEOVIM_SOURCE_DIR}/${neovim_branch}.diff'."
  echo "${vim_full}" > "${NEOVIM_SOURCE_DIR}/${neovim_branch}.patch"
  echo "✔ Saved full commit details to '${NEOVIM_SOURCE_DIR}/${neovim_branch}.patch'."
  echo "${neovim_pr}" > "${NEOVIM_SOURCE_DIR}/${neovim_branch}.pr"
  echo "✔ Saved suggested PR description to '${NEOVIM_SOURCE_DIR}/${neovim_branch}.pr'."
  echo "You can use 'git clean' to remove these files when you're done."

  echo
  echo "Instructions:"
  echo
  echo "  Proceed to port the patch."
  echo "  You might want to try 'patch -p1 < ${neovim_branch}.diff' first."
  echo
  echo "  Stage your changes ('git add ...') and use 'git commit --amend' to commit."
  echo
  echo "  Push your changes with 'git push origin ${neovim_branch}' and create a"
  echo "  pull request called '[RFC] vim-patch:${vim_version}'. You might want "
  echo "  to use the text in '${neovim_branch}.pr' as the description of this pull request."
  echo
  echo "  See https://github.com/neovim/neovim/wiki/Merging-patches-from-upstream-vim"
  echo "  for more information."
}

list_vim_patches() {
  get_vim_sources

  echo
  echo "Vim patches missing from Neovim:"

  # Get tags since 7.4.442.
  local vim_tags=$(cd "${VIM_SOURCE_DIR}" && \
    git tag --contains v7.4.442)

  # Get non-versioned commits since e2719096.
  if git log -1 --grep='.' --invert-grep > /dev/null 2>&1 ; then
    local vim_runtime_commits=$(cd "${VIM_SOURCE_DIR}" && \
      git log --format='%H' --grep='^patch' --grep='^updated for version' --invert-grep e2719096250a19ecdd9a35d13702879f163d2a50..HEAD)
  else
    # --invert-grep requires git 2.4+
    echo "Warning: some runtime updates may not be listed (requires git 2.4+)."
    local vim_runtime_commits=$(cd "${VIM_SOURCE_DIR}" && \
      git log --format='%H' --grep='Updated' e2719096250a19ecdd9a35d13702879f163d2a50..HEAD)
  fi

  local vim_commit
  for vim_commit in ${vim_tags} ${vim_runtime_commits}; do
    local is_missing
    if [[ ${vim_commit} =~ v([0-9].[0-9].([0-9]{3,4})) ]]; then
      local patch_number="${BASH_REMATCH[2]}"
      # Tagged Vim patch, check version.c:
      is_missing="$(sed -n '/static int included_patches/,/}/p' "${NEOVIM_SOURCE_DIR}/src/nvim/version.c" |
        grep -x -e "[[:space:]]*//${patch_number} NA" -e "[[:space:]]*${patch_number}," >/dev/null && echo "false" || echo "true")"
      vim_commit="${BASH_REMATCH[1]//-/.}"
    else
      # Untagged Vim patch (e.g. runtime updates), check the Neovim git log:
      is_missing="$(cd "${NEOVIM_SOURCE_DIR}" &&
        git log -1 --no-merges --grep="vim\-patch:${vim_commit:0:7}" --pretty=format:"false")"
    fi

    if [[ ${is_missing} != "false" ]]; then
      echo "  • ${vim_commit}"
    fi
  done

  echo
  echo "Instructions:"
  echo
  echo "  To port one of the above patches to Neovim, execute"
  echo "  this script with the patch revision as argument."
  echo
  echo "  Examples: '${BASENAME} -p 7.4.487'"
  echo "            '${BASENAME} -p 1e8ebf870720e7b671f98f22d653009826304c4f'"
}

review_pr() {
  check_executable curl
  check_executable nvim

  get_vim_sources

  local pr="${1}"
  echo
  echo "Downloading data for pull request #${pr}."

  local git_patch_prefix='Subject: \[PATCH\] '
  local neovim_patch="$(curl -Ssf "https://patch-diff.githubusercontent.com/raw/neovim/neovim/pull/${pr}.patch")"
  echo "${neovim_patch}" > a
  local vim_version="$(head -n 4 <<< "${neovim_patch}" | sed -n "s/${git_patch_prefix}vim-patch:\([a-z0-9.]*\)$/\1/p")"

  if [[ -n "${vim_version}" ]]; then
    echo "✔ Detected Vim patch '${vim_version}'."
  else
    echo "✘ Could not detect the Vim patch number."
    echo "  This script assumes that the PR contains a single commit"
    echo "  with 'vim-patch:XXX' as its title."
    exit 1
  fi

  assign_commit_details "${vim_version}"

  local expected_commit_message="$(commit_message)"
  local message_length="$(wc -l <<< "${expected_commit_message}")"
  local commit_message="$(tail -n +4 <<< "${neovim_patch}" | head -n "${message_length}")"
  if [[ "${commit_message#${git_patch_prefix}}" == "${expected_commit_message}" ]]; then
    echo "✔ Found expected commit message."
  else
    echo "✘ Wrong commit message."
    echo "  Expected:"
    echo "${expected_commit_message}"
    echo "  Actual:"
    echo "${commit_message#${git_patch_prefix}}"
    exit 1
  fi

  local base_name="vim-${vim_version}"
  echo
  echo "Creating files."
  curl -Ssfo "${NEOVIM_SOURCE_DIR}/n${base_name}.diff" "https://patch-diff.githubusercontent.com/raw/neovim/neovim/pull/${pr}.diff"
  echo "✔ Saved pull request diff to '${NEOVIM_SOURCE_DIR}/n${base_name}.diff'."
  echo "${neovim_patch}" > "${NEOVIM_SOURCE_DIR}/n${base_name}.patch"
  echo "✔ Saved full pull request commit details to '${NEOVIM_SOURCE_DIR}/n${base_name}.patch'."
  git show "${vim_commit}" > "${NEOVIM_SOURCE_DIR}/${base_name}.diff"
  echo "✔ Saved Vim diff to '${NEOVIM_SOURCE_DIR}/${base_name}.diff'."
  git show "${vim_commit}" > "${NEOVIM_SOURCE_DIR}/${base_name}.patch"
  echo "✔ Saved full Vim commit details to '${NEOVIM_SOURCE_DIR}/${base_name}.patch'."
  echo "You can use 'git clean' to remove these files when you're done."

  echo
  echo "Launching nvim."
  exec nvim -O "${NEOVIM_SOURCE_DIR}/${base_name}.diff" "${NEOVIM_SOURCE_DIR}/n${base_name}.diff"
}

while getopts "hlp:r:" opt; do
  case ${opt} in
    h)
      usage
      exit 0
      ;;
    l)
      list_vim_patches
      exit 0
      ;;
    p)
      get_vim_patch "${OPTARG}"
      exit 0
      ;;
    r)
      review_pr "${OPTARG}"
      exit 0
      ;;
    *)
      exit 1
      ;;
  esac
done

usage

# vim: et sw=2
