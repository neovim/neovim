#!/usr/bin/env bash

set -e
set -u
# Use privileged mode, which e.g. skips using CDPATH.
set -p

readonly NVIM_SOURCE_DIR="${NVIM_SOURCE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
readonly VIM_SOURCE_DIR_DEFAULT="${NVIM_SOURCE_DIR}/.vim-src"
readonly VIM_SOURCE_DIR="${VIM_SOURCE_DIR:-${VIM_SOURCE_DIR_DEFAULT}}"
readonly BASENAME="$(basename "${0}")"
readonly BRANCH_PREFIX="vim-"

CREATED_FILES=()

usage() {
  echo "Port Vim patches to Neovim"
  echo "https://github.com/neovim/neovim/wiki/Merging-patches-from-upstream-vim"
  echo
  echo "Usage:  ${BASENAME} [-h | -l | -p vim-revision | -r pr-number]"
  echo
  echo "Options:"
  echo "    -h                 Show this message and exit."
  echo "    -l                 List missing Vim patches."
  echo "    -L                 List missing Vim patches (for scripts)."
  echo "    -M                 List all merged patch-numbers (at current v:version)."
  echo "    -p {vim-revision}  Download and generate a Vim patch. vim-revision"
  echo "                       can be a Vim version (8.0.xxx) or a Git hash."
  echo "    -P {vim-revision}  Download, generate and apply a Vim patch."
  echo "    -g {vim-revision}  Download a Vim patch."
  echo "    -s                 Create a vim-patch pull request."
  echo "    -r {pr-number}     Review a vim-patch pull request."
  echo '    -V                 Clone the Vim source code to $VIM_SOURCE_DIR.'
  echo
  echo '    $VIM_SOURCE_DIR controls where Vim sources are found'
  echo "    (default: '${VIM_SOURCE_DIR_DEFAULT}')"
}

msg_ok() {
  printf '\e[32m✔\e[0m %s\n' "$@"
}

msg_err() {
  printf '\e[31m✘\e[0m %s\n' "$@"
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
  if [[ "${reply}" == n ]]; then
    echo "You can use 'git clean' to remove these files when you're done."
  else
    rm -- "${CREATED_FILES[@]}"
  fi
}

get_vim_sources() {
  require_executable git

  if [[ ! -d ${VIM_SOURCE_DIR} ]]; then
    echo "Cloning Vim into: ${VIM_SOURCE_DIR}"
    git clone https://github.com/vim/vim.git "${VIM_SOURCE_DIR}"
    cd "${VIM_SOURCE_DIR}"
  else
    if [[ ! -d "${VIM_SOURCE_DIR}/.git" ]]; then
      msg_err "${VIM_SOURCE_DIR} does not appear to be a git repository."
      echo "  Please remove it and try again."
      exit 1
    fi
    cd "${VIM_SOURCE_DIR}"
    echo "Updating Vim sources: ${VIM_SOURCE_DIR}"
    git pull &&
      msg_ok "Updated Vim sources." ||
      msg_err "Could not update Vim sources; ignoring error."
  fi
}

commit_message() {
  if [[ -n "$vim_tag" ]]; then
    printf '%s\n%s' "${vim_message}" "${vim_commit_url}"
  else
    printf 'vim-patch:%s\n\n%s\n%s' "$vim_version" "$vim_message" "$vim_commit_url"
  fi
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
    local munge_commit_line=true
  else
    # Interpret parameter as commit hash.
    vim_version="${1:0:12}"
    vim_tag=
    vim_commit=$(cd "${VIM_SOURCE_DIR}" \
      && git log -1 --format="%H" "${vim_version}")
    local munge_commit_line=false
  fi

  vim_commit_url="https://github.com/vim/vim/commit/${vim_commit}"
  vim_message="$(cd "${VIM_SOURCE_DIR}" \
    && git log -1 --pretty='format:%B' "${vim_commit}" \
      | sed -e 's/\(#[0-9]*\)/vim\/vim\1/g')"
  if [[ ${munge_commit_line} == "true" ]]; then
    # Remove first line of commit message.
    vim_message="$(echo "${vim_message}" | sed -e '1s/^patch /vim-patch:/')"
  fi
  patch_file="vim-${vim_version}.patch"
}

# Patch surgery
preprocess_patch() {
  local file="$1"
  local nvim="nvim -u NORC -i NONE --headless"

  # Remove *.proto, Make*, gui_*, some if_*
  local na_src='proto\|Make*\|gui_*\|if_lua\|if_mzsch\|if_olepp\|if_ole\|if_perl\|if_py\|if_ruby\|if_tcl\|if_xcmdsrv'
  2>/dev/null $nvim --cmd 'set dir=/tmp' +'g@^diff --git a/src/\S*\<\%(testdir/\)\@<!\%('${na_src}'\)@norm! d/\v(^diff)|%$' +w +q "$file"

  # Remove channel.txt, netbeans.txt, os_*.txt, term.txt, todo.txt, version*.txt, tags
  local na_doc='channel\.txt\|netbeans\.txt\|os_\w\+\.txt\|term\.txt\|todo\.txt\|version\d\.txt\|tags'
  2>/dev/null $nvim --cmd 'set dir=/tmp' +'g@^diff --git a/runtime/doc/\<\%('${na_doc}'\)\>@norm! d/\v(^diff)|%$' +w +q "$file"

  # Remove "Last change ..." changes in doc files.
  2>/dev/null $nvim --cmd 'set dir=/tmp' +'%s/^@@.*\n.*For Vim version.*Last change.*\n.*For Vim version.*Last change.*//' +w +q "$file"

  # Remove some testdir/Make_*.mak files
  local na_src_testdir='Make_amiga.mak\|Make_dos.mak\|Make_ming.mak\|Make_vms.mms'
  2>/dev/null $nvim --cmd 'set dir=/tmp' +'g@^diff --git a/src/testdir/\<\%('${na_src_testdir}'\)\>@norm! d/\v(^diff)|%$' +w +q "$file"

  # Remove version.c #7555
  local na_po='version.c'
  2>/dev/null $nvim --cmd 'set dir=/tmp' +'g@^diff --git a/src/\<\%('${na_po}'\)\>@norm! d/\v(^diff)|%$' +w +q "$file"

  # Remove some *.po files. #5622
  local na_po='sjiscorr.c\|ja.sjis.po\|ko.po\|pl.cp1250.po\|pl.po\|ru.cp1251.po\|uk.cp1251.po\|zh_CN.cp936.po\|zh_CN.po\|zh_TW.po'
  2>/dev/null $nvim --cmd 'set dir=/tmp' +'g@^diff --git a/src/po/\<\%('${na_po}'\)\>@norm! d/\v(^diff)|%$' +w +q "$file"

  # Remove vimrc_example.vim
  local na_vimrcexample='vimrc_example\.vim'
  2>/dev/null $nvim --cmd 'set dir=/tmp' +'g@^diff --git a/runtime/\<\%('${na_vimrcexample}'\)\>@norm! d/\v(^diff)|%$' +w +q "$file"

  # Rename src/ paths to src/nvim/
  LC_ALL=C sed -e 's/\( [ab]\/src\)/\1\/nvim/g' \
    "$file" > "$file".tmp && mv "$file".tmp "$file"

  # Rename path to matchit plugin.
  LC_ALL=C sed -e 's@\( [ab]/runtime\)/pack/dist/opt/matchit/\(plugin/matchit.vim\)@\1/\2@g' \
    "$file" > "$file".tmp && mv "$file".tmp "$file"
}

get_vimpatch() {
  get_vim_sources

  assign_commit_details "${1}"

  git log -1 "${vim_commit}" -- >/dev/null 2>&1 || {
    >&2 msg_err "Couldn't find Vim revision '${vim_commit}'."
    exit 3
  }
  msg_ok "Found Vim revision '${vim_commit}'."

  local patch_content
  patch_content="$(git --no-pager show --color=never -1 --pretty=medium "${vim_commit}")"

  cd "${NVIM_SOURCE_DIR}"

  printf "Creating patch...\n"
  echo "$patch_content" > "${NVIM_SOURCE_DIR}/${patch_file}"

  printf "Pre-processing patch...\n"
  preprocess_patch "${NVIM_SOURCE_DIR}/${patch_file}"

  msg_ok "Saved patch to '${NVIM_SOURCE_DIR}/${patch_file}'.\n"
}

stage_patch() {
  get_vimpatch "$1"
  local try_apply="${2:-}"

  local git_remote
  git_remote="$(find_git_remote)"
  local checked_out_branch
  checked_out_branch="$(git rev-parse --abbrev-ref HEAD)"

  if [[ "${checked_out_branch}" == ${BRANCH_PREFIX}* ]]; then
    msg_ok "Current branch '${checked_out_branch}' seems to be a vim-patch"
    echo "  branch; not creating a new branch."
  else
    printf '\nFetching "%s/master".\n' "${git_remote}"
    output="$(git fetch "${git_remote}" master 2>&1)" &&
      msg_ok "${output}" ||
      (msg_err "${output}"; false)

    local nvim_branch="${BRANCH_PREFIX}${vim_version}"
    echo
    echo "Creating new branch '${nvim_branch}' based on '${git_remote}/master'."
    cd "${NVIM_SOURCE_DIR}"
    output="$(git checkout -b "${nvim_branch}" "${git_remote}/master" 2>&1)" &&
      msg_ok "${output}" ||
      (msg_err "${output}"; false)
  fi

  printf "\nCreating empty commit with correct commit message.\n"
  output="$(commit_message | git commit --allow-empty --file 2>&1 -)" &&
    msg_ok "${output}" ||
    (msg_err "${output}"; false)

  if test -n "$try_apply" ; then
    if ! check_executable patch; then
      printf "\n"
      msg_err "'patch' command not found\n"
    else
      printf "\nApplying patch...\n"
      patch -p1 < "${patch_file}" || true
      find -name '*.orig' -type f -delete
    fi
    printf "\nInstructions:\n  Proceed to port the patch.\n"
  else
    printf '\nInstructions:\n  Proceed to port the patch.\n  Try the "patch" command (or use "%s -P ..." next time):\n    patch -p1 < %s\n' "${BASENAME}" "${patch_file}"
  fi

  printf '
  Stage your changes ("git add ..."), then use "git commit --amend" to commit.

  To port more patches (if any) related to %s,
  run "%s" again.
    * Do this only for _related_ patches (otherwise it increases the
      size of the pull request, making it harder to review)

  When you are done, try "%s -s" to create the pull request.

  See the wiki for more information:
    * https://github.com/neovim/neovim/wiki/Merging-patches-from-upstream-vim
' "${vim_version}" "${BASENAME}" "${BASENAME}"
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

  cd "${NVIM_SOURCE_DIR}"
  local checked_out_branch
  checked_out_branch="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "${checked_out_branch}" != ${BRANCH_PREFIX}* ]]; then
    msg_err "Current branch '${checked_out_branch}' doesn't seem to be a vim-patch branch."
    exit 1
  fi

  local git_remote
  git_remote="$(find_git_remote)"
  local pr_body
  pr_body="$(git log --grep=vim-patch --reverse --format='#### %s%n%n%b%n' "${git_remote}"/master..HEAD)"
  local patches
  # Extract just the "vim-patch:X.Y.ZZZZ" or "vim-patch:sha" portion of each log
  patches=("$(git log --grep=vim-patch --reverse --format='%s' "${git_remote}"/master..HEAD | sed 's/: .*//')")
  patches=(${patches[@]//vim-patch:}) # Remove 'vim-patch:' prefix for each item in array.
  local pr_title="${patches[*]}" # Create space-separated string from array.
  pr_title="${pr_title// /,}" # Replace spaces with commas.

  local pr_message
  pr_message="$(printf '[RFC] vim-patch:%s\n\n%s\n' "${pr_title#,}" "${pr_body}")"

  if [[ $push_first -ne 0 ]]; then
    echo "Pushing to 'origin/${checked_out_branch}'."
    output="$(git push origin "${checked_out_branch}" 2>&1)" &&
      msg_ok "${output}" ||
      (msg_err "${output}"; false)

    echo
  fi

  echo "Creating pull request."
  output="$(${submit_fn} "${pr_message}" 2>&1)" &&
    msg_ok "${output}" ||
    (msg_err "${output}"; false)

  echo
  echo "Cleaning up files."
  local patch_file
  for patch_file in "${patches[@]}"; do
    patch_file="vim-${patch_file}.patch"
    if [[ ! -f "${NVIM_SOURCE_DIR}/${patch_file}" ]]; then
      continue
    fi
    rm -- "${NVIM_SOURCE_DIR}/${patch_file}"
    msg_ok "Removed '${NVIM_SOURCE_DIR}/${patch_file}'."
  done
}

# Gets all Vim commits since the "start" commit.
list_vim_commits() { (
  cd "${VIM_SOURCE_DIR}" && git log --reverse --format='%H' v8.0.0000..HEAD
) }

# Prints all (sorted) "vim-patch:xxx" tokens found in the Nvim git log.
list_vimpatch_tokens() {
  local tokens
  # Find all "vim-patch:xxx" tokens in the Nvim git log.
  tokens="$(cd "${NVIM_SOURCE_DIR}" && git log -E --grep='vim-patch:[^ ]+' | grep 'vim-patch')"
  echo "$tokens" | grep -E 'vim-patch:[^ ,{]{7,}' \
    | sed 's/.*\(vim-patch:[.0-9a-z]\+\).*/\1/' \
    | sort \
    | uniq
}

# Prints all patch-numbers (for the current v:version) for which there is
# a "vim-patch:xxx" token in the Nvim git log.
list_vimpatch_numbers() {
  # Transform "vim-patch:X.Y.ZZZZ" to "ZZZZ".
  list_vimpatch_tokens | while read vimpatch_token; do
    echo "$vimpatch_token" | grep '8\.0\.' | sed 's/.*vim-patch:8\.0\.\([0-9a-z]\+\).*/\1/'
  done
}

# Prints a newline-delimited list of Vim commits, for use by scripts.
list_missing_vimpatches() {
  local tokens vim_commit vim_commits is_missing vim_tag patch_number

  # Find all "vim-patch:xxx" tokens in the Nvim git log.
  tokens="$(list_vimpatch_tokens)"

  # Get missing Vim commits
  vim_commits="$(list_vim_commits)"
  for vim_commit in ${vim_commits}; do
    # Check for vim-patch:<commit_hash> (usually runtime updates).
    is_missing="$(echo "$tokens" | >/dev/null 2>&1 grep "vim\-patch:${vim_commit:0:7}" && echo false || echo true)"

    if ! [ "$is_missing" = "false" ] \
      && vim_tag="$(cd "${VIM_SOURCE_DIR}" && git describe --tags --exact-match "${vim_commit}" 2>/dev/null)"
    then
      # Vim version number (not commit hash).
      # Check for vim-patch:<tag> (not commit hash).
      patch_number="${vim_tag:1}" # "v7.4.0001" => "7.4.0001"
      is_missing="$(echo "$tokens" | >/dev/null 2>&1 grep "vim\-patch:${patch_number}" && echo false || echo true)"
      vim_commit="${vim_tag#v}"
    fi

    if ! [ "$is_missing" = "false" ]; then
      echo "${vim_commit}"
    fi
  done
}

# Prints a human-formatted list of Vim commits, with instructional messages.
show_vimpatches() {
  get_vim_sources
  printf "\nVim patches missing from Neovim:\n"

  list_missing_vimpatches | while read vim_commit; do
    if (cd "${VIM_SOURCE_DIR}" && git --no-pager  show --color=never --name-only "v${vim_commit}" 2>/dev/null) | grep -q ^runtime; then
      printf '  • %s (+runtime)\n' "${vim_commit}"
    else
      printf '  • %s\n' "${vim_commit}"
    fi
  done

  printf "Instructions:

  To port one of the above patches to Neovim, execute
  this script with the patch revision as argument and
  follow the instructions.

  Examples: '%s -p 7.4.487'
            '%s -p 1e8ebf870720e7b671f98f22d653009826304c4f'

  NOTE: Please port the _oldest_ patch if you possibly can.
        Out-of-order patches increase the possibility of bugs.
" "${BASENAME}" "${BASENAME}"
}

review_commit() {
  local nvim_commit_url="${1}"
  local nvim_patch_url="${nvim_commit_url}.patch"

  local git_patch_prefix='Subject: \[PATCH\] '
  local nvim_patch
  nvim_patch="$(curl -Ssf "${nvim_patch_url}")"
  local vim_version
  vim_version="$(head -n 4 <<< "${nvim_patch}" | sed -n 's/'"${git_patch_prefix}"'vim-patch:\([a-z0-9.]*\)\(:.*\)\{0,1\}$/\1/p')"

  echo
  if [[ -n "${vim_version}" ]]; then
    msg_ok "Detected Vim patch '${vim_version}'."
  else
    msg_err "Could not detect the Vim patch number."
    echo "  This script assumes that the PR contains only commits"
    echo "  with 'vim-patch:XXX' in their title."
    echo
    printf -- '%s\n\n' "$(head -n 4 <<< "${nvim_patch}")"
    local reply
    read -p "Continue reviewing (y/N)? " -n 1 -r reply
    if [[ "${reply}" == y ]]; then
      echo
      return
    fi
    exit 1
  fi

  assign_commit_details "${vim_version}"

  echo
  echo "Creating files."
  echo "${nvim_patch}" > "${NVIM_SOURCE_DIR}/n${patch_file}"
  msg_ok "Saved pull request diff to '${NVIM_SOURCE_DIR}/n${patch_file}'."
  CREATED_FILES+=("${NVIM_SOURCE_DIR}/n${patch_file}")

  local nvim="nvim -u NORC -n -i NONE --headless"
  2>/dev/null $nvim --cmd 'set dir=/tmp' +'1,/^$/g/^ /-1join' +w +q "${NVIM_SOURCE_DIR}/n${patch_file}"

  local expected_commit_message
  expected_commit_message="$(commit_message)"
  local message_length
  message_length="$(wc -l <<< "${expected_commit_message}")"
  local commit_message
  commit_message="$(tail -n +4 "${NVIM_SOURCE_DIR}/n${patch_file}" | head -n "${message_length}")"
  if [[ "${commit_message#${git_patch_prefix}}" == "${expected_commit_message}" ]]; then
    msg_ok "Found expected commit message."
  else
    msg_err "Wrong commit message."
    echo "  Expected:"
    echo "${expected_commit_message}"
    echo "  Actual:"
    echo "${commit_message#${git_patch_prefix}}"
  fi

  get_vimpatch "${vim_version}"
  CREATED_FILES+=("${NVIM_SOURCE_DIR}/${patch_file}")

  echo
  echo "Launching nvim."
  nvim -c "cd ${NVIM_SOURCE_DIR}" \
    -O "${NVIM_SOURCE_DIR}/${patch_file}" "${NVIM_SOURCE_DIR}/n${patch_file}"
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
      if [[ "${reply}" == n ]]; then
        break
      fi
    fi
  done

  clean_files
}

while getopts "hlLMVp:P:g:r:s" opt; do
  case ${opt} in
    h)
      usage
      exit 0
      ;;
    l)
      show_vimpatches
      exit 0
      ;;
    L)
      list_missing_vimpatches
      exit 0
      ;;
    M)
      list_vimpatch_numbers
      exit 0
      ;;
    p)
      stage_patch "${OPTARG}"
      exit 0
      ;;
    P)
      stage_patch "${OPTARG}" TRY_APPLY
      exit 0
      ;;
    g)
      get_vimpatch "${OPTARG}"
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
    V)
      get_vim_sources
      exit 0
      ;;
    *)
      exit 1
      ;;
  esac
done

usage

# vim: et sw=2
