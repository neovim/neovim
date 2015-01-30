#!/usr/bin/env bash

set -e
set -o pipefail

NEOVIM_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VIM_SOURCE_DIR_DEFAULT=${NEOVIM_SOURCE_DIR}/.vim-src
VIM_SOURCE_DIR="${VIM_SOURCE_DIR:-${VIM_SOURCE_DIR_DEFAULT}}"

usage() {
  >&2 echo "Helper script for porting Vim patches. For more information,"
  >&2 echo "see https://github.com/neovim/neovim/wiki/Merging-patches-from-upstream-vim."
  >&2 echo
  >&2 echo "Usage:  ${0} [option]"
  >&2 echo "        ${0} vim-revision"
  >&2 echo
  >&2 echo "Options:"
  >&2 echo "    -h, --help    Show this message."
  >&2 echo "    -l, --list    Show list of Vim patches missing from Neovim."
  >&2 echo
  >&2 echo "vim-revision can be a version number in format '7.4.xxx'"
  >&2 echo "or a Mercurial commit hash."
  >&2 echo
  >&2 echo "Set VIM_SOURCE_DIR to change where Vim's sources are stored."
  >&2 echo "The default is '${VIM_SOURCE_DIR_DEFAULT}'."
}

get_vim_sources() {
  echo "Retrieving Vim sources."
  if [[ ! -d ${VIM_SOURCE_DIR} ]]; then
    echo "Cloning Vim sources into '${VIM_SOURCE_DIR}'."
    hg clone https://code.google.com/p/vim ${VIM_SOURCE_DIR}
    cd ${VIM_SOURCE_DIR}
  else
    echo "Updating Vim sources in '${VIM_SOURCE_DIR}'."
    cd ${VIM_SOURCE_DIR}
    hg pull --update &&
      echo "✔ Updated Vim sources." ||
      echo "✘ Could not update Vim sources; ignoring error."
  fi
}

get_vim_patch() {
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
  echo
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
}

list_vim_patches() {
  echo
  echo "Vim patches missing from Neovim:"

  # Get vim patches and runtime file updates.
  # Start from 7.4.442. The runtime was re-integrated from 7.4.384, but
  # runtime patches before between 384 and 442 have already been ported
  # to Neovim as of the creation of this script.
  local vim_commits=$(cd ${VIM_SOURCE_DIR} && \
    hg log --removed --template='{if(startswith("Added tag", firstline(desc)),
      "{latesttag}\n",
      "{if(startswith(\"updated for version\", firstline(desc)),
        \"\",
        \"{node}\n\")}")}' -r tip:v7-4-442)
  # Append remaining vim patches.
  # Start from 7.4.160, where Neovim was forked.
  local vim_old_commits=$(cd ${VIM_SOURCE_DIR} && \
    hg log --removed --template='{if(startswith("Added tag",
      firstline(desc)),
      "{latesttag}\n")}' -r v7-4-442:v7-4-161)

  local vim_commit
  for vim_commit in ${vim_commits} ${vim_old_commits}; do
    local is_missing
    if [[ "${vim_commit}" =~ v([0-9]-[0-9]-([0-9]{3,4})) ]]; then
      local patch_number="${BASH_REMATCH[2]}"
      # "Proper" Vim patch
      # Check version.c:
      is_missing="$(sed -n '/static int included_patches/,/}/p' ${NEOVIM_SOURCE_DIR}/src/nvim/version.c |
        grep -x -e "[[:space:]]*//${patch_number} NA" -e "[[:space:]]*${patch_number}," >/dev/null && echo "false" || echo "true")"
      vim_commit="${BASH_REMATCH[1]//-/.}"
    else
      # Untagged Vim patch, e.g. runtime updates.
      # Check Neovim log:
      is_missing="$(cd ${NEOVIM_SOURCE_DIR} &&
        git log -1 --no-merges --grep="vim\-patch:${vim_commit:0:7}" --pretty=format:"false")"
    fi

    if [[ "${is_missing}" != "false" ]]; then
      echo "  • ${vim_commit}"
    fi
  done

  echo
  echo "Instructions:"
  echo
  echo "  To port one of the above patches to Neovim, execute"
  echo "  this script with the patch revision as argument."
  echo
  echo "  Examples: './scripts/vim-patch.sh 7.4.487'"
  echo "            './scripts/vim-patch.sh 1e8ebf870720e7b671f98f22d653009826304c4f'"
}

if [[ ${#} != 1 || "${1}" == "--help" || "${1}" == "-h" ]]; then
  usage
  exit 1
fi

get_vim_sources

if [[ "${1}" == "--list" || "${1}" == "-l" ]]; then
  list_vim_patches
else
  get_vim_patch ${1}
fi
