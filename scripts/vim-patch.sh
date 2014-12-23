#!/bin/bash -e

NEOVIM_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VIM_SOURCE_DIR_DEFAULT=${NEOVIM_SOURCE_DIR}/build/vim
VIM_SOURCE_DIR="${VIM_SOURCE_DIR:-${VIM_SOURCE_DIR_DEFAULT}}"

if [[ ${#} != 1 ]]; then
  >&2 echo "Helper script for porting Vim patches. For more information,"
  >&2 echo "see https://github.com/neovim/neovim/wiki/Merging-patches-from-upstream-vim."
  >&2 echo
  >&2 echo "Usage: ${0} vim-version"
  >&2 echo "vim-version must be in format '7.4.xxx'."
  >&2 echo
  >&2 echo "Set VIM_SOURCE_DIR to change where Vim's sources are stored."
  >&2 echo "The default is '${VIM_SOURCE_DIR_DEFAULT}'."
  exit 1
fi

vim_version="${1}"
if [[ ! ${vim_version} =~ [0-9]\.[0-9]\.[0-9][0-9][0-9] ]]; then
  >&2 echo "vim-version must be in format '7.4.xxx'."
  exit 2
fi

if [[ ! -d ${VIM_SOURCE_DIR} ]]; then
  echo "Cloning Vim sources into '${VIM_SOURCE_DIR}'."
  hg clone https://code.google.com/p/vim ${VIM_SOURCE_DIR}
  cd ${VIM_SOURCE_DIR}
else
  echo "Updating Vim sources in '${VIM_SOURCE_DIR}'."
  cd ${VIM_SOURCE_DIR}
  hg pull --update || echo 'Could not update Vim sources.'
fi

vim_tag="v${vim_version//./-}"
echo "Using Vim tag '${vim_tag}'."

hg log --rev ${vim_tag} >/dev/null 2>&1 || {
  >&2 echo "Couldn't find Vim tag '${vim_tag}'."
  exit 3
}

vim_full="$(hg log --patch --git --verbose --rev ${vim_tag})"
vim_message="$(hg log --template "{desc}" --rev ${vim_tag} \
  | sed -e '1d')" # Remove first line of commit message.
vim_diff="$(hg diff --show-function --git --change ${vim_tag} \
  | sed -e 's/\( [ab]\/src\)/\1\/nvim/g')" # Change directory to src/nvim.


neovim_branch="vim-${vim_version}"
echo
echo "Creating Neovim branch '${neovim_branch}'."
cd ${NEOVIM_SOURCE_DIR}
git checkout -b "${neovim_branch}"

echo
echo "Saving patch to '${NEOVIM_SOURCE_DIR}/${neovim_branch}.patch'."
echo "${vim_diff}" > ${NEOVIM_SOURCE_DIR}/${neovim_branch}.patch

echo "Saving full commit details to '${NEOVIM_SOURCE_DIR}/${neovim_branch}.commit'."
echo "${vim_full}" > ${NEOVIM_SOURCE_DIR}/${neovim_branch}.commit

echo
echo "Creating empty Neovim commit with correct commit message."
neovim_message="
vim-patch:${vim_version}

${vim_message}

https://code.google.com/p/vim/source/detail?r=${vim_tag}"

git commit --allow-empty --file - <<< "${neovim_message}"

echo
echo "Proceed to port the patch and stage your changes ('git add ...')."
echo "Then use 'git commit --amend' to commit."
echo "Push your changes with 'git push origin ${neovim_branch}' and create a"
echo "pull request called '[RFC] vim-patch:${vim_version}'."
echo
echo "See https://github.com/neovim/neovim/wiki/Merging-patches-from-upstream-vim"
echo "for more information."
