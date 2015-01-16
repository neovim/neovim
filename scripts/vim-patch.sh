#!/usr/bin/env bash

set -e
set -o pipefail

NEOVIM_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VIM_SOURCE_DIR_DEFAULT=${NEOVIM_SOURCE_DIR}/.vim-src
VIM_SOURCE_DIR="${VIM_SOURCE_DIR:-${VIM_SOURCE_DIR_DEFAULT}}"

if [[ ${#} != 1 ]]; then
  >&2 echo "Helper script for porting Vim patches. For more information,"
  >&2 echo "see https://github.com/neovim/neovim/wiki/Merging-patches-from-upstream-vim."
  >&2 echo
  >&2 echo "Usage: ${0} vim-revision"
  >&2 echo "vim-revision can be a version number in format '7.4.xxx'"
  >&2 echo "or a Mercurial commit hash."
  >&2 echo
  >&2 echo "Set VIM_SOURCE_DIR to change where Vim's sources are stored."
  >&2 echo "The default is '${VIM_SOURCE_DIR_DEFAULT}'."
  exit 1
fi

echo "Retrieving Vim sources."
if [[ ! -d ${VIM_SOURCE_DIR} ]]; then
  echo "Cloning Vim sources into '${VIM_SOURCE_DIR}'."
  hg clone https://code.google.com/p/vim ${VIM_SOURCE_DIR}
  cd ${VIM_SOURCE_DIR}
else
  echo "Updating Vim sources in '${VIM_SOURCE_DIR}'."
  cd ${VIM_SOURCE_DIR}
  hg pull --update || echo "✘ Could not update Vim sources."
fi

if [[ "${1}" =~ [0-9]\.[0-9]\.[0-9]{3,4} ]]; then
  # Interpret parameter as version number.
  vim_version="${1}"
  vim_commit="v${1//./-}"
  strip_commit_line=true
else
  # Interpret parameter as commit hash.
  vim_version="${1:0:7}"
  vim_commit="${1}"
  strip_commit_line=false
fi

hg log --rev ${vim_commit} >/dev/null 2>&1 || {
  >&2 echo "✘ Couldn't find Vim revision '${vim_commit}'."
  exit 3
}
echo "✔ Found Vim revision '${vim_commit}'."

# Collect patch details and store into variables.
vim_full="$(hg log --patch --git --verbose --rev ${vim_commit})"
vim_message="$(hg log --template "{desc}" --rev ${vim_commit})"
if [[ "${strip_commit_line}" == "true" ]]; then
  # Remove first line of commit message.
  vim_message="$(echo "${vim_message}" | sed -e '1d')"
fi
vim_diff="$(hg diff --show-function --git --change ${vim_commit} \
  | sed -e 's/\( [ab]\/src\)/\1\/nvim/g')" # Change directory to src/nvim.
neovim_message="
vim-patch:${vim_version}

${vim_message}

https://code.google.com/p/vim/source/detail?r=${vim_commit}"
neovim_pr="
\`\`\`
${vim_message}
\`\`\`

https://code.google.com/p/vim/source/detail?r=${vim_commit}

Original patch:

\`\`\`diff
${vim_diff}
\`\`\`"
neovim_branch="vim-${vim_version}"

echo
echo "Creating Git branch."
cd ${NEOVIM_SOURCE_DIR}
echo -n "✘ "
# 'git checkout -b' writes to stderr in case of success :-(
# Re-add newline (stripped by echo -n) in error case.
git checkout -b "${neovim_branch}" 2>&1 | xargs echo -n || (echo; false)
echo -n "." # Add trailing dot.
echo -e "\r✔ " # Replace ✘ with ✔

echo
echo "Creating empty commit with correct commit message."
echo -n "✘ "
git commit --allow-empty --file - <<< "${neovim_message}" | xargs echo -n
echo -e "\r✔ " # Replace ✘ with ✔

echo
echo "Creating files."
echo "${vim_diff}" > ${NEOVIM_SOURCE_DIR}/${neovim_branch}.diff
echo "✔ Saved patch to '${NEOVIM_SOURCE_DIR}/${neovim_branch}.diff'."
echo "${vim_full}" > ${NEOVIM_SOURCE_DIR}/${neovim_branch}.patch
echo "✔ Saved full commit details to '${NEOVIM_SOURCE_DIR}/${neovim_branch}.patch'."
echo "${neovim_pr}" > ${NEOVIM_SOURCE_DIR}/${neovim_branch}.pr
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
