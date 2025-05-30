#!/usr/bin/env bash

set -e
set -u
# Use privileged mode, which e.g. skips using CDPATH.
set -p
# https://www.shellcheck.net/wiki/SC2031
shopt -s lastpipe

# Ensure that the user has a bash that supports -A
if [[ "${BASH_VERSINFO[0]}" -lt 4  ]]; then
  >&2 echo "error: script requires bash 4+ (you have ${BASH_VERSION})."
  exit 1
fi

readonly NVIM_SOURCE_DIR="${NVIM_SOURCE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
readonly VIM_SOURCE_DIR_DEFAULT="${NVIM_SOURCE_DIR}/.vim-src"
readonly VIM_SOURCE_DIR="${VIM_SOURCE_DIR:-${VIM_SOURCE_DIR_DEFAULT}}"
BASENAME="$(basename "${0}")"
readonly BASENAME
readonly BRANCH_PREFIX="vim-"

CREATED_FILES=()

usage() {
  echo "Port Vim patches to Neovim"
  echo "https://neovim.io/doc/user/dev_vimpatch.html"
  echo
  echo "Usage:  ${BASENAME} [-h | -l | -p vim-revision | -r pr-number]"
  echo
  echo "Options:"
  echo "    -h                 Show this message and exit."
  echo "    -l [git-log opts]  List missing Vim patches."
  echo "    -L [git-log opts]  List missing Vim patches (for scripts)."
  echo "    -m {vim-revision}  List previous (older) missing Vim patches."
  echo "    -M                 List all merged patch-numbers (at current v:version)."
  echo "    -p {vim-revision}  Download and generate a Vim patch. vim-revision"
  echo "                       can be a Vim version (8.1.xxx) or a Git hash."
  echo "    -P {vim-revision}  Download, generate and apply a Vim patch."
  echo "    -g {vim-revision}  Download a Vim patch."
  echo "    -s [pr args]       Create a vim-patch pull request."
  echo "    -r {pr-number}     Review a vim-patch pull request."
  echo "    -V                 Clone the Vim source code to \$VIM_SOURCE_DIR."
  echo
  echo "    \$VIM_SOURCE_DIR controls where Vim sources are found"
  echo "    (default: '${VIM_SOURCE_DIR_DEFAULT}')"
  echo
  echo "Examples:"
  echo
  echo " - List missing patches for a given file (in the Vim source):"
  echo "   $0 -l -- src/edit.c"
}

msg_ok() {
  printf '\e[32m✔\e[0m %s\n' "$@"
}

msg_err() {
  printf '\e[31m✘\e[0m %s\n' "$@" >&2
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
  elif [[ "${1-}" == update ]]; then
    cd "${VIM_SOURCE_DIR}"
    if ! [ -d ".git" ] \
        && ! [ "$(git rev-parse --show-toplevel)" = "${VIM_SOURCE_DIR}" ]; then
      msg_err "${VIM_SOURCE_DIR} does not appear to be a git repository."
      echo "  Please remove it and try again."
      exit 1
    fi
    echo "Updating Vim sources: ${VIM_SOURCE_DIR}"
    if git pull --ff; then
      msg_ok "Updated Vim sources."
    else
      msg_err "Could not update Vim sources; ignoring error."
    fi
  else
    cd "${VIM_SOURCE_DIR}"
  fi
}

commit_message() {
  if [[ "${vim_message}" == "vim-patch:${vim_version}:"* ]]; then
    printf '%s\n\n%s\n\n%s' "${vim_message}" "${vim_commit_url}" "${vim_coauthors}"
  else
    printf 'vim-patch:%s: %s\n\n%s\n\n%s' "${vim_version:0:7}" "${vim_message}" "${vim_commit_url}" "${vim_coauthors}"
  fi
}

find_git_remote() {
  local git_remote
  if [[ "${1-}" == fork ]]; then
    git_remote=$(git remote -v | awk '$2 !~ /github.com[:\/]neovim\/neovim/ && $3 == "(fetch)" {print $1; exit}')
  else
    git_remote=$(git remote -v | awk '$2 ~ /github.com[:\/]neovim\/neovim/ && $3 == "(fetch)" {print $1; exit}')
  fi
  if [[ -z "$git_remote" ]]; then
    git_remote="origin"
  fi
  echo "$git_remote"
}

# Assign variables for a given Vim tag, patch version, or commit.
# Might exit in case it cannot be found, after updating Vim sources.
assign_commit_details() {
  local vim_commit_ref
  if [[ ${1} =~ v?[0-9]\.[0-9]\.[0-9]{3,4} ]]; then
    # Interpret parameter as version number (tag).
    if [[ "${1:0:1}" == v ]]; then
      vim_version="${1:1}"
      vim_tag="${1}"
    else
      vim_version="${1}"
      vim_tag="v${1}"
    fi
    vim_commit_ref="$vim_tag"
    local munge_commit_line=true
  else
    # Interpret parameter as commit hash.
    vim_version="${1:0:7}"
    vim_tag=
    vim_commit_ref="$vim_version"
    local munge_commit_line=false
  fi

  local get_vim_commit_cmd="git -C ${VIM_SOURCE_DIR} log -1 --format=%H ${vim_commit_ref} --"
  vim_commit=$($get_vim_commit_cmd 2>&1) || {
    # Update Vim sources.
    get_vim_sources update
    vim_commit=$($get_vim_commit_cmd 2>&1) || {
      >&2 msg_err "Couldn't find Vim revision '${vim_commit_ref}': git error: ${vim_commit}."
      exit 3
    }
  }

  vim_commit_url="https://github.com/vim/vim/commit/${vim_commit}"
  vim_message="$(git -C "${VIM_SOURCE_DIR}" log -1 --pretty='format:%B' "${vim_commit}" \
      | sed -Ee 's/([^A-Za-z0-9])(#[0-9]{1,})/\1vim\/vim\2/g')"
  local vim_coauthor0
  vim_coauthor0="$(git -C "${VIM_SOURCE_DIR}" log -1 --pretty='format:Co-authored-by: %an <%ae>' "${vim_commit}")"
  # Extract co-authors from the commit message.
  vim_coauthors="$(echo "${vim_message}" | (grep -E '^Co-authored-by: ' || true) | (grep -Fxv "${vim_coauthor0}" || true))"
  vim_coauthors="$(echo "${vim_coauthor0}"; echo "${vim_coauthors}")"
  # Remove Co-authored-by and Signed-off-by lines from the commit message.
  vim_message="$(echo "${vim_message}" | grep -Ev '^(Co-authored|Signed-off)-by: ')"
  if [[ ${munge_commit_line} == "true" ]]; then
    # Remove first line of commit message.
    vim_message="$(echo "${vim_message}" | sed -Ee '1s/^patch /vim-patch:/')"
  fi
  patch_file="vim-${vim_version}.patch"
}

# Patch surgery
preprocess_patch() {
  local file="$1"
  local nvim="nvim -u NONE -n -i NONE --headless"

  # Remove Filelist, README
  local na_files='Filelist\|README.*'
  2>/dev/null $nvim --cmd 'set dir=/tmp' +'g@^diff --git a/\<\%('"${na_files}"'\)\>@exe "norm! d/\\v(^diff)|%$\r"' +w +q "$file"

  # Remove *.proto, Make*, INSTALL*, gui_*, beval.*, some if_*, gvim, libvterm, tee, VisVim, xpm, xxd
  local na_src='auto\|configure.*\|GvimExt\|hardcopy.*\|libvterm\|proto\|tee\|VisVim\|xpm\|xxd\|Make.*\|INSTALL.*\|beval.*\|gui.*\|if_cscop\|if_lua\|if_mzsch\|if_olepp\|if_ole\|if_perl\|if_py\|if_ruby\|if_tcl\|if_xcmdsrv'
  2>/dev/null $nvim --cmd 'set dir=/tmp' +'g@^diff --git a/src/\S*\<\%(testdir/\)\@<!\%('"${na_src}"'\)\>@exe "norm! d/\\v(^diff)|%$\r"' +w +q "$file"

  # Remove runtime/print/
  local na_rt='print\/.*'
  2>/dev/null $nvim --cmd 'set dir=/tmp' +'g@^diff --git a/runtime/\<\%('"${na_rt}"'\)\>@exe "norm! d/\\v(^diff)|%$\r"' +w +q "$file"

  # Remove unwanted Vim doc files.
  local na_doc='channel\.txt\|if_cscop\.txt\|netbeans\.txt\|os_\w\+\.txt\|print\.txt\|term\.txt\|todo\.txt\|vim9\.txt\|tags'
  2>/dev/null $nvim --cmd 'set dir=/tmp' +'g@^diff --git a/runtime/doc/\<\%('"${na_doc}"'\)\>@exe "norm! d/\\v(^diff)|%$\r"' +w +q "$file"

  # Remove "Last change ..." changes in doc files.
  2>/dev/null $nvim --cmd 'set dir=/tmp' +'%s/^@@.*\n.*For Vim version.*Last change.*\n.*For Vim version.*Last change.*//' +w +q "$file"

  # Remove gui, setup, screen dumps, testdir/Make_*.mak files
  local na_src_testdir='gui_.*\|Make_amiga\.mak\|Make_dos\.mak\|Make_ming\.mak\|Make_vms\.mms\|dumps/.*\.dump\|setup_gui\.vim'
  2>/dev/null $nvim --cmd 'set dir=/tmp' +'g@^diff --git a/src/testdir/\<\%('"${na_src_testdir}"'\)\>@exe "norm! d/\\v(^diff)|%$\r"' +w +q "$file"

  # Remove testdir/test_*.vim files
  local na_src_testdir='balloon.*\|behave\.vim\|channel.*\|crypt\.vim\|cscope\.vim\|gui.*\|hardcopy\.vim\|job_fails\.vim\|json\.vim\|listener\.vim\|mzscheme\.vim\|netbeans.*\|paste\.vim\|popupwin.*\|python2\.vim\|pyx2\.vim\|restricted\.vim\|shortpathname\.vim\|sound\.vim\|tcl\.vim\|terminal.*\|xxd\.vim'
  2>/dev/null $nvim --cmd 'set dir=/tmp' +'g@^diff --git a/src/testdir/\<test_\%('"${na_src_testdir}"'\)\>@exe "norm! d/\\v(^diff)|%$\r"' +w +q "$file"

  # Remove N/A src/*.[ch] files: sound.c, version.c
  local na_src_c='sound\|version'
  2>/dev/null $nvim --cmd 'set dir=/tmp' +'g@^diff --git a/src/\<\%('"${na_src_c}"'\)\.[ch]\>@exe "norm! d/\\v(^diff)|%$\r"' +w +q "$file"

  # Remove some *.po files. #5622
  local na_po='sjiscorr\.c\|ja\.sjis\.po\|ko\.po\|pl\.cp1250\.po\|pl\.po\|ru\.cp1251\.po\|uk\.cp1251\.po\|zh_CN\.cp936\.po\|zh_CN\.po\|zh_TW\.po'
  2>/dev/null $nvim --cmd 'set dir=/tmp' +'g@^diff --git a/src/po/\<\%('${na_po}'\)\>@exe "norm! d/\\v(^diff)|%$\r"+' +w +q "$file"

  # Remove vimrc_example.vim
  local na_vimrcexample='vimrc_example\.vim'
  2>/dev/null $nvim --cmd 'set dir=/tmp' +'g@^diff --git a/runtime/\<\%('${na_vimrcexample}'\)\>@exe "norm! d/\\v(^diff)|%$\r"+' +w +q "$file"

  # Rename src/testdir/ paths to test/old/testdir/
  LC_ALL=C sed -Ee 's/( [ab])\/src\/testdir/\1\/test\/old\/testdir/g' \
    "$file" > "$file".tmp && mv "$file".tmp "$file"

  # Rename src/ paths to src/nvim/
  LC_ALL=C sed -Ee 's/( [ab]\/src)/\1\/nvim/g' \
    "$file" > "$file".tmp && mv "$file".tmp "$file"

  # Rename evalfunc.c to eval/funcs.c
  LC_ALL=C sed -Ee 's/( [ab]\/src\/nvim)\/evalfunc\.c/\1\/eval\/funcs.c/g' \
    "$file" > "$file".tmp && mv "$file".tmp "$file"

  # Rename evalvars.c to eval/vars.c
  LC_ALL=C sed -Ee 's/( [ab]\/src\/nvim)\/evalvars\.c/\1\/eval\/vars.c/g' \
    "$file" > "$file".tmp && mv "$file".tmp "$file"

  # Rename userfunc.c to eval/userfunc.c
  LC_ALL=C sed -Ee 's/( [ab]\/src\/nvim)\/userfunc\.c/\1\/eval\/userfunc.c/g' \
    "$file" > "$file".tmp && mv "$file".tmp "$file"

  # Rename evalbuffer.c to eval/buffer.c
  LC_ALL=C sed -Ee 's/( [ab]\/src\/nvim)\/evalbuffer\.c/\1\/eval\/buffer.c/g' \
    "$file" > "$file".tmp && mv "$file".tmp "$file"

  # Rename evalwindow.c to eval/window.c
  LC_ALL=C sed -Ee 's/( [ab]\/src\/nvim)\/evalwindow\.c/\1\/eval\/window.c/g' \
    "$file" > "$file".tmp && mv "$file".tmp "$file"

  # Rename map.c to mapping.c
  LC_ALL=C sed -Ee 's/( [ab]\/src\/nvim)\/map\.c/\1\/mapping.c/g' \
    "$file" > "$file".tmp && mv "$file".tmp "$file"

  # Rename profiler.c to profile.c
  LC_ALL=C sed -Ee 's/( [ab]\/src\/nvim)\/profiler\.c/\1\/profile.c/g' \
    "$file" > "$file".tmp && mv "$file".tmp "$file"

  # Rename scriptfile.c to runtime.c
  LC_ALL=C sed -Ee 's/( [ab]\/src\/nvim)\/scriptfile\.c/\1\/runtime.c/g' \
    "$file" > "$file".tmp && mv "$file".tmp "$file"

  # Rename session.c to ex_session.c
  LC_ALL=C sed -Ee 's/( [ab]\/src\/nvim)\/session\.c/\1\/ex_session.c/g' \
    "$file" > "$file".tmp && mv "$file".tmp "$file"

  # Rename highlight.c to highlight_group.c
  LC_ALL=C sed -Ee 's/( [ab]\/src\/nvim)\/highlight\.c/\1\/highlight_group.c/g' \
    "$file" > "$file".tmp && mv "$file".tmp "$file"

  # Rename locale.c to os/lang.c
  LC_ALL=C sed -Ee 's/( [ab]\/src\/nvim)\/locale\.c/\1\/os\/lang.c/g' \
    "$file" > "$file".tmp && mv "$file".tmp "$file"

  # Rename keymap.h to keycodes.h
  LC_ALL=C sed -Ee 's/( [ab]\/src\/nvim)\/keymap\.h/\1\/keycodes.h/g' \
    "$file" > "$file".tmp && mv "$file".tmp "$file"

  # Rename option.h to option_vars.h
  LC_ALL=C sed -Ee 's/( [ab]\/src\/nvim)\/option\.h/\1\/option_vars.h/g' \
    "$file" > "$file".tmp && mv "$file".tmp "$file"

  # Rename runtime/doc/eval.txt to runtime/doc/vimeval.txt
  LC_ALL=C sed -Ee 's/( [ab]\/runtime\/doc)\/eval\.txt/\1\/vimeval.txt/g' \
    "$file" > "$file".tmp && mv "$file".tmp "$file"

  # Rename version*.txt to news.txt
  LC_ALL=C sed -Ee 's/( [ab]\/runtime\/doc)\/version[0-9]+\.txt/\1\/news.txt/g' \
    "$file" > "$file".tmp && mv "$file".tmp "$file"

  # Rename sponsor.txt to intro.txt
  LC_ALL=C sed -Ee 's/( [ab]\/runtime\/doc)\/sponsor\.txt/\1\/intro.txt/g' \
    "$file" > "$file".tmp && mv "$file".tmp "$file"

  # Rename test_urls.vim to check_urls.vim
  LC_ALL=C sed -Ee 's/( [ab])\/runtime\/doc\/test(_urls\.vim)/\1\/scripts\/check\2/g' \
    "$file" > "$file".tmp && mv "$file".tmp "$file"

  # Rename path to check_colors.vim
  LC_ALL=C sed -Ee 's/( [ab]\/runtime)\/colors\/(tools\/check_colors\.vim)/\1\/\2/g' \
    "$file" > "$file".tmp && mv "$file".tmp "$file"
}

uncrustify_patch() {
  git diff --quiet || {
    >&2 echo 'Vim source working tree dirty, aborting.'
    exit 1
  }

  local patch_path="$NVIM_SOURCE_DIR"/build/vim_patch
  rm -rf "$patch_path"
  mkdir -p "$patch_path"/{a,b}

  local commit="$1"
  for file in $(git diff-tree --name-only --no-commit-id -r --diff-filter=a "$commit"); do
    git --work-tree="$patch_path"/a checkout --quiet "$commit"~ -- "$file"
  done
  for file in $(git diff-tree --name-only --no-commit-id -r --diff-filter=d "$commit"); do
    git --work-tree="$patch_path"/b checkout --quiet "$commit" -- "$file"
  done
  git reset --quiet --hard HEAD

  # If the difference are drastic enough uncrustify may need to be used more
  # than once. This is obviously a bug that needs to be fixed on uncrustify's
  # end, but in the meantime this workaround is sufficient.
  for _ in {1..2}; do
    "$NVIM_SOURCE_DIR"/build/usr/bin/uncrustify -c "$NVIM_SOURCE_DIR"/src/uncrustify.cfg -q --replace --no-backup "$patch_path"/{a,b}/src/*.[ch]
  done

  (cd "$patch_path" && (git --no-pager diff --no-index --no-prefix --patch --unified=5 --color=never a/ b/ || true))
}

get_vimpatch() {
  get_vim_sources

  assign_commit_details "${1}"

  msg_ok "Found Vim revision '${vim_commit}'."

  local patch_content
  if check_executable "$NVIM_SOURCE_DIR"/build/usr/bin/uncrustify; then
    patch_content="$(uncrustify_patch "${vim_commit}")"
  else
    patch_content="$(git --no-pager show --unified=5 --color=never -1 --pretty=medium "${vim_commit}")"
  fi

  cd "${NVIM_SOURCE_DIR}"

  printf "Creating patch...\n"
  echo "$patch_content" > "${NVIM_SOURCE_DIR}/${patch_file}"

  printf "Pre-processing patch...\n"
  preprocess_patch "${NVIM_SOURCE_DIR}/${patch_file}"

  msg_ok "Saved patch to '${NVIM_SOURCE_DIR}/${patch_file}'."
}

stage_patch() {
  get_vimpatch "$1"
  local try_apply="${2:-}"

  local nvim_remote
  nvim_remote="$(find_git_remote)"
  local checked_out_branch
  checked_out_branch="$(git rev-parse --abbrev-ref HEAD)"

  if [[ "${checked_out_branch}" == ${BRANCH_PREFIX}* ]]; then
    msg_ok "Current branch '${checked_out_branch}' seems to be a vim-patch"
    echo "  branch; not creating a new branch."
  else
    printf '\nFetching "%s/master".\n' "${nvim_remote}"
    if output="$(git fetch "$nvim_remote" master 2>&1)"; then
      msg_ok "$output"
    else
      msg_err "$output"
      exit 1
    fi

    local nvim_branch="${BRANCH_PREFIX}${vim_version}"
    echo
    echo "Creating new branch '${nvim_branch}' based on '${nvim_remote}/master'."
    cd "${NVIM_SOURCE_DIR}"
    if output="$(git checkout -b "$nvim_branch" "$nvim_remote/master" 2>&1)"; then
      msg_ok "$output"
    else
      msg_err "$output"
      exit 1
    fi
  fi

  printf "\nCreating empty commit with correct commit message.\n"
  if output="$(commit_message | git commit --allow-empty --file 2>&1 -)"; then
    msg_ok "$output"
  else
    msg_err "$output"
    exit 1
  fi

  local ret=0
  if test -n "$try_apply" ; then
    if ! check_executable patch; then
      printf "\n"
      msg_err "'patch' command not found\n"
    else
      printf "\nApplying patch...\n"
      patch -p1 --fuzz=1 --no-backup-if-mismatch < "${patch_file}" || ret=$?
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

  When you are done, try "%s -s" to create the pull request,
  or "%s -s --draft" to create a draft pull request.

  See the wiki for more information:
    * https://neovim.io/doc/user/dev_vimpatch.html
' "${vim_version}" "${BASENAME}" "${BASENAME}" "${BASENAME}"
  return $ret
}

gh_pr() {
  local pr_title
  local pr_body
  pr_title="$1"
  pr_body="$2"
  shift 2
  gh pr create --title "${pr_title}" --body "${pr_body}" "$@"
}

git_hub_pr() {
  local pr_message
  pr_message="$(printf '%s\n\n%s\n' "$1" "$2")"
  shift 2
  git hub pull new -m "${pr_message}" "$@"
}

submit_pr() {
  require_executable git
  local push_first
  push_first=1
  local submit_fn
  if check_executable gh; then
    submit_fn="gh_pr"
  elif check_executable git-hub; then
    push_first=0
    submit_fn="git_hub_pr"
  else
    >&2 echo "${BASENAME}: 'gh' or 'git-hub' not found in PATH or not executable."
    >&2 echo "              Get it here: https://cli.github.com/"
    exit 1
  fi

  cd "${NVIM_SOURCE_DIR}"
  local checked_out_branch
  checked_out_branch="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "${checked_out_branch}" != ${BRANCH_PREFIX}* ]]; then
    msg_err "Current branch '${checked_out_branch}' doesn't seem to be a vim-patch branch."
    exit 1
  fi

  local nvim_remote
  nvim_remote="$(find_git_remote)"
  local pr_body
  pr_body="$(git log --grep=vim-patch --reverse --format='#### %s%n%n%b%n' "${nvim_remote}"/master..HEAD)"
  local patches
  # Extract just the "vim-patch:X.Y.ZZZZ" or "vim-patch:sha" portion of each log
  patches=("$(git log --grep=vim-patch --reverse --format='%s' "${nvim_remote}"/master..HEAD | sed 's/: .*//')")
  # shellcheck disable=SC2206
  patches=(${patches[@]//vim-patch:}) # Remove 'vim-patch:' prefix for each item in array.
  local pr_title="${patches[*]}" # Create space-separated string from array.
  pr_title="${pr_title// /,}" # Replace spaces with commas.
  pr_title="$(printf 'vim-patch:%s' "${pr_title#,}")"

  if [[ $push_first -ne 0 ]]; then
    local push_remote
    push_remote="$(git config --get branch."${checked_out_branch}".pushRemote || true)"
    if [[ -z "$push_remote" ]]; then
      push_remote="$(git config --get remote.pushDefault || true)"
      if [[ -z "$push_remote" ]]; then
        push_remote="$(git config --get branch."${checked_out_branch}".remote || true)"
        if [[ -z "$push_remote" ]] || [[ "$push_remote" == "$nvim_remote" ]]; then
          push_remote="$(find_git_remote fork)"
        fi
      fi
    fi
    echo "Pushing to '${push_remote}/${checked_out_branch}'."
    if output="$(git push "$push_remote" "$checked_out_branch" 2>&1)"; then
      msg_ok "$output"
    else
      msg_err "$output"
      exit 1
    fi

    echo
  fi

  echo "Creating pull request."
  if output="$($submit_fn "$pr_title" "$pr_body" "$@" 2>&1)"; then
    msg_ok "$output"
  else
    msg_err "$output"
    exit 1
  fi

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
  cd "${VIM_SOURCE_DIR}" && git log --reverse v8.1.0000..HEAD "$@"
) }

# Prints all (sorted) "vim-patch:xxx" tokens found in the Nvim git log.
list_vimpatch_tokens() {
  # Use sed…{7,7} to normalize (internal) Git hashes (for tokens caches).
  git -C "${NVIM_SOURCE_DIR}" log -E --grep='vim-patch:[^ ,{]{7,}' \
    | grep -oE 'vim-patch:[^ ,{:]{7,}' \
    | sort \
    | uniq \
    | sed -nEe 's/^(vim-patch:([0-9]+\.[^ ]+|[0-9a-z]{7,7})).*/\1/p'
}

# Prints all patch-numbers (for the current v:version) for which there is
# a "vim-patch:xxx" token in the Nvim git log.
list_vimpatch_numbers() {
  # Transform "vim-patch:X.Y.ZZZZ" to "ZZZZ".
  list_vimpatch_tokens | while read -r vimpatch_token; do
    echo "$vimpatch_token" | grep -F '8.1.' | sed -Ee 's/.*vim-patch:8\.1\.([0-9a-z]+).*/\1/'
  done
}

declare -A tokens
declare -A vim_commit_tags

_set_tokens_and_tags() {
  set +u  # Avoid "unbound variable" with bash < 4.4 below.
  if [[ -n "${tokens[*]}" ]]; then
    return
  fi
  set -u

  # Find all "vim-patch:xxx" tokens in the Nvim git log.
  for token in $(list_vimpatch_tokens); do
    tokens[$token]=1
  done

  # Create an associative array mapping Vim commits to tags.
  eval "vim_commit_tags=(
    $(git -C "${VIM_SOURCE_DIR}" show-ref --tags --dereference \
      | sed -nEe 's/^([0-9a-f]+) refs\/tags\/(v[0-9.]+)(\^\{\})?$/["\1"]="\2"/p')
  )"
  # Exit in case of errors from the above eval (empty vim_commit_tags).
  if ! (( "${#vim_commit_tags[@]}" )); then
    msg_err "Could not get Vim commits/tags."
    exit 1
  fi
}

# Prints a newline-delimited list of Vim commits, for use by scripts.
# "$1": use extended format? (with subject)
# "$@" is passed to list_vim_commits, as extra arguments to git-log.
list_missing_vimpatches() {
  local -a missing_vim_patches=()
  _set_missing_vimpatches "$@"
  set +u  # Avoid "unbound variable" with bash < 4.4 below.
  for line in "${missing_vim_patches[@]}"; do
    printf '%s\n' "$line"
  done
  set -u
}

# Sets / appends to missing_vim_patches (useful to avoid a subshell when
# used multiple times to cache tokens/vim_commit_tags).
# "$1": use extended format? (with subject)
# "$@": extra arguments to git-log.
_set_missing_vimpatches() {
  local token vim_commit vim_tag patch_number
  declare -a git_log_args

  local extended_format=$1; shift
  if [[ "$extended_format" == 1 ]]; then
    git_log_args=("--format=%H %s")
  else
    git_log_args=("--format=%H")
  fi

  # Massage arguments for git-log.
  declare -A git_log_replacements=(
    [^\(.*/\)?src/nvim/\(.*\)]="\${BASH_REMATCH[1]}src/\${BASH_REMATCH[2]}"
    [^\(.*/\)?test/old/\(.*\)]="\${BASH_REMATCH[1]}src/\${BASH_REMATCH[2]}"
    [^\(.*/\)?\.vim-src/\(.*\)]="\${BASH_REMATCH[2]}"
  )
  local i j
  for i in "$@"; do
    for j in "${!git_log_replacements[@]}"; do
      if [[ "$i" =~ $j ]]; then
        eval "git_log_args+=(${git_log_replacements[$j]})"
        continue 2
      fi
    done
    git_log_args+=("$i")
  done

  _set_tokens_and_tags

  # Get missing Vim commits
  set +u  # Avoid "unbound variable" with bash < 4.4 below.
  local vim_commit info
  while IFS=' ' read -r line; do
    # Check for vim-patch:<commit_hash> (usually runtime updates).
    token="vim-patch:${line:0:7}"
    if [[ "${tokens[$token]-}" ]]; then
      continue
    fi

    # Get commit hash, and optional info from line.  This is used in
    # extended mode, and when using e.g. '--format' manually.
    vim_commit=${line%% *}
    if [[ "$vim_commit" == "$line" ]]; then
      info=
    else
      info=${line#* }
      if [[ -n $info ]]; then
        # Remove any "patch 8.1.0902: " prefixes, and prefix with ": ".
        info=": ${info#patch*: }"
      fi
    fi

    vim_tag="${vim_commit_tags[$vim_commit]-}"
    if [[ -n "$vim_tag" ]]; then
      # Check for vim-patch:<tag> (not commit hash).
      patch_number="vim-patch:${vim_tag:1}" # "v7.4.0001" => "7.4.0001"
      if [[ "${tokens[$patch_number]-}" ]]; then
        continue
      fi
      missing_vim_patches+=("$vim_tag$info")
    else
      missing_vim_patches+=("$vim_commit$info")
    fi
  done < <(list_vim_commits "${git_log_args[@]}")
  set -u
}

# Prints a human-formatted list of Vim commits, with instructional messages.
# Passes "$@" onto list_missing_vimpatches (args for git-log).
show_vimpatches() {
  get_vim_sources update
  printf "Vim patches missing from Neovim:\n"

  local -A runtime_commits
  for commit in $(git -C "${VIM_SOURCE_DIR}" log --format="%H %D" -- runtime | sed -Ee 's/,\? tag: / /g'); do
    runtime_commits[$commit]=1
  done

  list_missing_vimpatches 1 "$@" | while read -r vim_commit; do
    if [[ "${runtime_commits[$vim_commit]-}" ]]; then
      printf '  • %s (+runtime)\n' "${vim_commit}"
    else
      printf '  • %s\n' "${vim_commit}"
    fi
  done

  cat << EOF

Instructions:
  To port one of the above patches to Neovim, execute this script with the patch revision as argument and follow the instructions, e.g.
  '${BASENAME} -p v8.1.1234', or '${BASENAME} -P v8.1.1234'

  NOTE: Please port the _oldest_ patch if you possibly can.
        You can use '${BASENAME} -l path/to/file' to see what patches are missing for a file.
EOF
}

list_missing_previous_vimpatches_for_patch() {
  local for_vim_patch="${1}"
  local vim_commit vim_tag
  assign_commit_details "${for_vim_patch}"

  local file
  local -a missing_list
  local -a fnames
  while IFS= read -r line ; do
    fnames+=("$line")
  done < <(git -C "${VIM_SOURCE_DIR}" diff-tree --no-commit-id --name-only -r "${vim_commit}" -- . ':!src/version.c')
  local i=0
  local n=${#fnames[@]}
  printf '=== getting missing patches for %d files ===\n' "$n"
  if [[ -z "${vim_tag}" ]]; then
    printf 'NOTE: "%s" is not a Vim tag - listing all oldest missing patches\n' "${for_vim_patch}" >&2
  fi
  for fname in "${fnames[@]}"; do
    i=$(( i+1 ))
    printf '[%.*d/%d] %s: ' "${#n}" "$i" "$n" "$fname"

    local -a missing_vim_patches=()
    _set_missing_vimpatches 1 -- "${fname}"

    set +u  # Avoid "unbound variable" with bash < 4.4 below.
    for missing_vim_commit_info in "${missing_vim_patches[@]}"; do
      if [[ -z "${missing_vim_commit_info}" ]]; then
        printf -- "-\r"
      else
        printf -- "-\r"
        local missing_vim_commit="${missing_vim_commit_info%%:*}"
        if [[ -z "${vim_tag}" ]] || [[ "${missing_vim_commit}" < "${vim_tag}" ]]; then
          printf -- "%s\n" "$missing_vim_commit_info"
          missing_list+=("$missing_vim_commit_info")
        else
          printf -- "-\r"
        fi
      fi
    done
    set -u
  done

  set +u  # Avoid "unbound variable" with bash < 4.4 below.
  if [[ -z "${missing_list[*]}" ]]; then
    msg_ok 'no missing previous Vim patches'
    set -u
    return 0
  fi
  set -u

  local -a missing_unique
  local stat
  while IFS= read -r line; do
    local commit="${line%%:*}"
    stat="$(git -C "${VIM_SOURCE_DIR}" show --format= --shortstat "${commit}")"
    missing_unique+=("$(printf '%s\n  %s' "$line" "$stat")")
  done < <(printf '%s\n' "${missing_list[@]}" | sort -u)

  msg_err "$(printf '%d missing previous Vim patches:' ${#missing_unique[@]})"
  printf ' - %s\n' "${missing_unique[@]}"
  return 1
}

review_commit() {
  local nvim_commit_url="${1}"
  local nvim_patch_url="${nvim_commit_url}.patch"

  local git_patch_prefix='Subject: \[PATCH\] '
  local nvim_patch
  nvim_patch="$(curl -Ssf "${nvim_patch_url}")"
  local vim_version
  vim_version="$(head -n 4 <<< "${nvim_patch}" | sed -nEe 's/'"${git_patch_prefix}"'vim-patch:([a-z0-9.]*)(:.*){0,1}$/\1/p')"

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

  local nvim="nvim -u NONE -n -i NONE --headless"
  2>/dev/null $nvim --cmd 'set dir=/tmp' +'1,/^$/g/^ /-1join' +w +q "${NVIM_SOURCE_DIR}/n${patch_file}"

  local expected_commit_message
  expected_commit_message="$(commit_message)"
  local message_length
  message_length="$(wc -l <<< "${expected_commit_message}")"
  local commit_message
  commit_message="$(tail -n +4 "${NVIM_SOURCE_DIR}/n${patch_file}" | head -n "${message_length}")"
  if [[ "${commit_message#"$git_patch_prefix"}" == "${expected_commit_message}" ]]; then
    msg_ok "Found expected commit message."
  else
    msg_err "Wrong commit message."
    echo "  Expected:"
    echo "${expected_commit_message}"
    echo "  Actual:"
    echo "${commit_message#"$git_patch_prefix"}"
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

  local -a pr_commit_urls
  while IFS= read -r pr_commit_url; do
    pr_commit_urls+=("$pr_commit_url")
  done < <(curl -Ssf "https://api.github.com/repos/neovim/neovim/pulls/${pr}/commits" \
    | jq -r '.[].html_url')

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

while getopts "hlLmMVp:P:g:r:s" opt; do
  case ${opt} in
    h)
      usage
      exit 0
      ;;
    l)
      shift  # remove opt
      show_vimpatches "$@"
      exit 0
      ;;
    L)
      shift  # remove opt
      list_missing_vimpatches 0 "$@"
      exit 0
      ;;
    M)
      list_vimpatch_numbers
      exit 0
      ;;
    m)
      shift  # remove opt
      list_missing_previous_vimpatches_for_patch "$@"
      exit 0
      ;;
    p)
      stage_patch "${OPTARG}"
      exit
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
      shift  # remove opt
      submit_pr "$@"
      exit 0
      ;;
    V)
      get_vim_sources update
      exit 0
      ;;
    *)
      exit 1
      ;;
  esac
done

usage

# vim: et sw=2
