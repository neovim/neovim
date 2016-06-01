#!/usr/bin/env bash

set -e
set -u
set -o pipefail

readonly NEOVIM_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly VIM_SOURCE_DIR_DEFAULT="${NEOVIM_SOURCE_DIR}/.vim-src"
readonly VIM_SOURCE_DIR="${VIM_SOURCE_DIR:-${VIM_SOURCE_DIR_DEFAULT}}"
readonly BASENAME="$(basename "${0}")"
readonly BRANCH_PREFIX="vim-"

CREATED_FILES=()

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
  echo "    -s                 Submit a vim-patch pull request to Neovim."
  echo "    -r {pr-number}     Review a vim-patch pull request to Neovim."
  echo
  echo "Set VIM_SOURCE_DIR to change where Vim's sources are stored."
  echo "The default is '${VIM_SOURCE_DIR_DEFAULT}'."
}

# Checks if a program is in the user's PATH, and is executable.
check_executable() {
  test -x "$(command -v "${1}")"
}

require_executable() {
  if ! check_executable "${1}"; then
    >&2 echo "${BASENAME}: '${1}' not found in PATH or not executable."
    exit 1
  fi
}

clean_files() {
  if [[ ${#CREATED_FILES[@]} -eq 0 ]]; then
    return
  fi

  echo
  echo "Created files:"
  local file
  for file in "${CREATED_FILES[@]}"; do
    echo "  • ${file}"
  done

  read -p "Delete these files (Y/n)? " -n 1 -r reply
  echo
  if [[ "${reply}" =~ ^[Yy]$ ]]; then
    rm -- "${CREATED_FILES[@]}"
  else
    echo "You can use 'git clean' to remove these files when you're done."
  fi
}

get_vim_sources() {
  require_executable git

  if [[ ! -d ${VIM_SOURCE_DIR} ]]; then
    echo "Cloning Vim sources into '${VIM_SOURCE_DIR}'."
    git clone https://github.com/vim/vim.git "${VIM_SOURCE_DIR}"
    cd "${VIM_SOURCE_DIR}"
  else
    if [[ ! -d "${VIM_SOURCE_DIR}/.git" ]]; then
      echo "✘ ${VIM_SOURCE_DIR} does not appear to be a git repository."
      echo "  Please remove it and try again."
      exit 1
    fi
    cd "${VIM_SOURCE_DIR}"
    echo "Updating Vim sources in '${VIM_SOURCE_DIR}'."
    git pull &&
      echo "✔ Updated Vim sources." ||
      echo "✘ Could not update Vim sources; ignoring error."
  fi
}

commit_message() {
  printf 'vim-patch:%s\n\n%s\n\n%s' "${vim_version}" \
    "${vim_message}" "${vim_commit_url}"
}

find_git_remote() {
  git remote -v \
    | awk '$2 ~ /github.com[:\/]neovim\/neovim/ && $3 == "(fetch)" {print $1; exit}'
}

assign_commit_details() {
  if [[ ${1} =~ [0-9]\.[0-9]\.[0-9]{3,4} ]]; then
    # Interpret parameter as version number (tag).
    vim_version="${1}"
    vim_tag="v${1}"
    vim_commit=$(cd "${VIM_SOURCE_DIR}" \
      && git log -1 --format="%H" "${vim_tag}")
    local strip_commit_line=true
  else
    # Interpret parameter as commit hash.
    vim_version="${1:0:7}"
    vim_commit=$(cd "${VIM_SOURCE_DIR}" \
      && git log -1 --format="%H" "${vim_version}")
    local strip_commit_line=false
  fi

  vim_commit_url="https://github.com/vim/vim/commit/${vim_commit}"
  vim_message="$(cd "${VIM_SOURCE_DIR}" \
    && git log -1 --pretty='format:%B' "${vim_commit}" \
      | sed -e 's/\(#[0-9]*\)/vim\/vim\1/g')"
  if [[ ${strip_commit_line} == "true" ]]; then
    # Remove first line of commit message.
    vim_message="$(echo "${vim_message}" | sed -e '1d')"
  fi
  patch_file="vim-${vim_version}.patch"
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

  # Patch surgery: preprocess the patch.
  #   - transform src/ paths to src/nvim/
  local vim_full
  vim_full="$(git show -1 --pretty=medium "${vim_commit}" \
    | LC_ALL=C sed -e 's/\( [ab]\/src\)/\1\/nvim/g')"
  local neovim_branch="${BRANCH_PREFIX}${vim_version}"

  cd "${NEOVIM_SOURCE_DIR}"
  local git_remote
  git_remote="$(find_git_remote)"
  local checked_out_branch
  checked_out_branch="$(git rev-parse --abbrev-ref HEAD)"

  if [[ "${checked_out_branch}" == ${BRANCH_PREFIX}* ]]; then
    echo "✔ Current branch '${checked_out_branch}' seems to be a vim-patch"
    echo "  branch; not creating a new branch."
  else
    echo
    echo "Fetching '${git_remote}/master'."
    output="$(git fetch "${git_remote}" master 2>&1)" &&
      echo "✔ ${output}" ||
      (echo "✘ ${output}"; false)

    echo
    echo "Creating new branch '${neovim_branch}' based on '${git_remote}/master'."
    cd "${NEOVIM_SOURCE_DIR}"
    output="$(git checkout -b "${neovim_branch}" "${git_remote}/master" 2>&1)" &&
      echo "✔ ${output}" ||
      (echo "✘ ${output}"; false)
  fi

  echo
  echo "Creating empty commit with correct commit message."
  output="$(commit_message | git commit --allow-empty --file 2>&1 -)" &&
    echo "✔ ${output}" ||
    (echo "✘ ${output}"; false)

  echo
  echo "Creating files."
  echo "${vim_full}" > "${NEOVIM_SOURCE_DIR}/${patch_file}"
  echo "✔ Saved full commit details to '${NEOVIM_SOURCE_DIR}/${patch_file}'."

  echo
  echo "Instructions:"
  echo
  echo "  Proceed to port the patch."
  echo "  You might want to try 'patch -p1 < ${patch_file}' first."
  echo
  echo "  If the patch contains a new test, consider porting it to Lua."
  echo "  You might want to try 'scripts/legacy2luatest.pl'."
  echo
  echo "  Stage your changes ('git add ...') and use 'git commit --amend' to commit."
  echo
  echo "  To port additional patches related to ${vim_version} and add them to the current"
  echo "  branch, call '${BASENAME} -p' again.  Please use this only if it wouldn't make"
  echo "  sense to send in each patch individually, as it will increase the size of the"
  echo "  pull request and make it harder to review."
  echo
  echo "  When you are finished, use '${BASENAME} -s' to submit a pull request."
  echo
  echo "  See https://github.com/neovim/neovim/wiki/Merging-patches-from-upstream-vim"
  echo "  for more information."
}

hub_pr() {
  hub pull-request -m "$1"
}

git_hub_pr() {
  git hub pull new -m "$1"
}

submit_pr() {
  require_executable git
  local push_first
  push_first=1
  local submit_fn
  if check_executable hub; then
    submit_fn="hub_pr"
  elif check_executable git-hub; then
    push_first=0
    submit_fn="git_hub_pr"
  else
    >&2 echo "${BASENAME}: 'hub' or 'git-hub' not found in PATH or not executable."
    exit 1
  fi

  cd "${NEOVIM_SOURCE_DIR}"
  local checked_out_branch
  checked_out_branch="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "${checked_out_branch}" != ${BRANCH_PREFIX}* ]]; then
    echo "✘ Current branch '${checked_out_branch}' doesn't seem to be a vim-patch branch."
    exit 1
  fi

  local git_remote
  git_remote="$(find_git_remote)"
  local pr_body
  pr_body="$(git log --reverse --format='#### %s%n%n%b%n' "${git_remote}"/master..HEAD)"
  local patches
  patches=("$(git log --reverse --format='%s' "${git_remote}"/master..HEAD)")
  patches=(${patches[@]//vim-patch:}) # Remove 'vim-patch:' prefix for each item in array.
  local pr_title="${patches[*]}" # Create space-separated string from array.
  pr_title="${pr_title// /,}" # Replace spaces with commas.

  local pr_message
  pr_message="$(printf '[RFC] vim-patch:%s\n\n%s\n' "${pr_title#,}" "${pr_body}")"

  if [[ $push_first -ne 0 ]]; then
    echo "Pushing to 'origin/${checked_out_branch}'."
    output="$(git push origin "${checked_out_branch}" 2>&1)" &&
      echo "✔ ${output}" ||
      (echo "✘ ${output}"; git reset --soft HEAD^1; false)

    echo
  fi

  echo "Creating pull request."
  output="$(${submit_fn} "${pr_message}" 2>&1)" &&
    echo "✔ ${output}" ||
    (echo "✘ ${output}"; false)

  echo
  echo "Cleaning up files."
  local patch_file
  for patch_file in "${patches[@]}"; do
    patch_file="vim-${patch_file}.patch"
    if [[ ! -f "${NEOVIM_SOURCE_DIR}/${patch_file}" ]]; then
      continue
    fi
    rm -- "${NEOVIM_SOURCE_DIR}/${patch_file}"
    echo "✔ Removed '${NEOVIM_SOURCE_DIR}/${patch_file}'."
  done
}

list_vim_patches() {
  get_vim_sources

  printf "\nVim patches missing from Neovim:\n"

  # Get commits since 7.4.602.
  local vim_commits
  vim_commits="$(cd "${VIM_SOURCE_DIR}" && git log --reverse --format='%H' v7.4.602..HEAD)"

  local vim_commit
  for vim_commit in ${vim_commits}; do
    local is_missing
    local vim_tag
    # This fails for untagged commits (e.g., runtime file updates) so mask the return status
    vim_tag="$(cd "${VIM_SOURCE_DIR}" && git describe --tags --exact-match "${vim_commit}" 2>/dev/null)" || true
    if [[ -n "${vim_tag}" ]]; then
      local patch_number="${vim_tag:5}" # Remove prefix like "v7.4."
      # Tagged Vim patch, check version.c:
      is_missing="$(sed -n '/static int included_patches/,/}/p' "${NEOVIM_SOURCE_DIR}/src/nvim/version.c" |
        grep -x -e "[[:space:]]*//[[:space:]]${patch_number} NA.*" -e "[[:space:]]*${patch_number}," >/dev/null && echo "false" || echo "true")"
      vim_commit="${vim_tag#v}"
      if (cd "${VIM_SOURCE_DIR}" && git show --name-only "v${vim_commit}" 2>/dev/null) | grep -q ^runtime; then
        vim_commit="${vim_commit} (+runtime)"
      fi
    else
      # Untagged Vim patch (e.g. runtime updates), check the Neovim git log:
      is_missing="$(cd "${NEOVIM_SOURCE_DIR}" &&
        git log -1 --no-merges --grep="vim\-patch:${vim_commit:0:7}" --pretty=format:false)"
    fi

    if [[ ${is_missing} != "false" ]]; then
      echo "  • ${vim_commit}"
    fi
  done

  echo
  echo "Instructions:"
  echo
  echo "  To port one of the above patches to Neovim, execute"
  echo "  this script with the patch revision as argument and"
  echo "  follow the instructions."
  echo
  echo "  Examples: '${BASENAME} -p 7.4.487'"
  echo "            '${BASENAME} -p 1e8ebf870720e7b671f98f22d653009826304c4f'"
  echo
  echo "  NOTE: Please port the _oldest_ patch if you possibly can."
  echo "        Out-of-order patches increase the possibility of bugs."
}

review_commit() {
  local neovim_commit_url="${1}"
  local neovim_patch_url="${neovim_commit_url}.patch"

  local git_patch_prefix='Subject: \[PATCH\] '
  local neovim_patch
  neovim_patch="$(curl -Ssf "${neovim_patch_url}")"
  local vim_version
  vim_version="$(head -n 4 <<< "${neovim_patch}" | sed -n "s/${git_patch_prefix}vim-patch:\([a-z0-9.]*\)$/\1/p")"

  echo
  if [[ -n "${vim_version}" ]]; then
    echo "✔ Detected Vim patch '${vim_version}'."
  else
    echo "✘ Could not detect the Vim patch number."
    echo "  This script assumes that the PR contains only commits"
    echo "  with 'vim-patch:XXX' in their title."
    exit 1
  fi

  assign_commit_details "${vim_version}"

  local vim_patch_url="${vim_commit_url}.patch"

  local expected_commit_message
  expected_commit_message="$(commit_message)"
  local message_length
  message_length="$(wc -l <<< "${expected_commit_message}")"
  local commit_message
  commit_message="$(tail -n +4 <<< "${neovim_patch}" | head -n "${message_length}")"
  if [[ "${commit_message#${git_patch_prefix}}" == "${expected_commit_message}" ]]; then
    echo "✔ Found expected commit message."
  else
    echo "✘ Wrong commit message."
    echo "  Expected:"
    echo "${expected_commit_message}"
    echo "  Actual:"
    echo "${commit_message#${git_patch_prefix}}"
  fi

  echo
  echo "Creating files."
  echo "${neovim_patch}" > "${NEOVIM_SOURCE_DIR}/n${patch_file}"
  echo "✔ Saved pull request diff to '${NEOVIM_SOURCE_DIR}/n${patch_file}'."
  CREATED_FILES+=("${NEOVIM_SOURCE_DIR}/n${patch_file}")

  curl -Ssfo "${NEOVIM_SOURCE_DIR}/${patch_file}" "${vim_patch_url}"
  echo "✔ Saved Vim diff to '${NEOVIM_SOURCE_DIR}/${patch_file}'."
  CREATED_FILES+=("${NEOVIM_SOURCE_DIR}/${patch_file}")

  echo
  echo "Launching nvim."
  nvim -c "cd ${NEOVIM_SOURCE_DIR}" \
    -O "${NEOVIM_SOURCE_DIR}/${patch_file}" "${NEOVIM_SOURCE_DIR}/n${patch_file}"
}

review_pr() {
  require_executable curl
  require_executable nvim
  require_executable jq

  get_vim_sources

  local pr="${1}"
  echo
  echo "Downloading data for pull request #${pr}."

  local pr_commit_urls=($(curl -Ssf "https://api.github.com/repos/neovim/neovim/pulls/${pr}/commits" \
                          | jq -r '.[].html_url'))

  echo "Found ${#pr_commit_urls[@]} commit(s)."

  local pr_commit_url
  local reply
  for pr_commit_url in "${pr_commit_urls[@]}"; do
    review_commit "${pr_commit_url}"
    if [[ "${pr_commit_url}" != "${pr_commit_urls[-1]}" ]]; then
      read -p "Continue with next commit (Y/n)? " -n 1 -r reply
      echo
      if [[ ! "${reply}" =~ ^[Yy]$ ]]; then
        break
      fi
    fi
  done

  clean_files
}

while getopts "hlp:r:s" opt; do
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
    s)
      submit_pr
      exit 0
      ;;
    *)
      exit 1
      ;;
  esac
done

usage

# vim: et sw=2
