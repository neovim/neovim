#!/bin/sh
set -e

get_jobs_num() {
  local num="$(cat /proc/cpuinfo | grep -c "^processor")"
  num="$(echo $(( num + 1 )))"
  num="${num:-1}"
  echo $num
}

get_pvs_comment() {
  cat > pvs-comment << EOF
// This is an open source non-commercial project. Dear PVS-Studio, please check it.
// PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com
EOF
}

install_pvs() {
  mkdir pvs-studio
  cd pvs-studio

  curl -o pvs-studio.tar.gz "$PVS_URL"
  tar xzf pvs-studio.tar.gz
  rm pvs-studio.tar.gz
  local pvsdir="$(find . -maxdepth 1 -mindepth 1)"
  find "$pvsdir" -maxdepth 1 -mindepth 1 -exec mv '{}' . \;
  rmdir "$pvsdir"

  export PATH="$PWD/bin${PATH+:}${PATH}"

  cd ..
}

create_compile_commands() {
  mkdir build
  cd build
  env \
    CC=clang \
    CFLAGS=' -O0 ' \
    cmake .. -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX="$PWD/root"
  make -j"$(get_jobs_num)"
  find src/nvim/auto -name '*.test-include.c' -delete

  cd ..
}

patch_sources() {
  get_pvs_comment

  local sh_script='
    cat pvs-comment "$1" > "$1.tmp"
    mv "$1.tmp" "$1"
  '

  find \
    src/nvim test/functional/fixtures test/unit/fixtures \
    -name '*.[ch]' \
    -exec /bin/sh -c "$sh_script" - '{}' \;

  find \
    build/src/nvim/auto build/config \
    -name '*.[ch]' -not -name '*.test-include.c' \
    -exec /bin/sh -c "$sh_script" - '{}' \;
}

help() {
  echo 'Usage: pvscheck.sh [target-directory [branch]]'
  echo
  echo '  target-directory: Directory where build should occur'
  echo '                    Default: ../neovim-pvs'
  echo
  echo '  branch: Branch to check'
  echo '          Must not be already checked out: uses git worktree.'
  echo '          Default: master'
}

main() {
  local PVS_URL="http://files.viva64.com/pvs-studio-6.14.21446.1-x86_64.tgz"

  if test "x$1" = "x--help" ; then
    help
    return
  fi
  set -x

  local tgt="${1:-$PWD/../neovim-pvs}"
  local branch="${2:-master}"

  git clone --branch="$branch" . "$tgt"

  cd "$tgt"

  install_pvs

  create_compile_commands

  patch_sources

  pvs-studio-analyzer \
    analyze \
      --threads "$(get_jobs_num)" \
      --output-file PVS-studio.log \
      --verbose \
      --file build/compile_commands.json \
      --sourcetree-root .

  plog-converter -t xml -o PVS-studio.xml PVS-studio.log
  plog-converter -t errorfile -o PVS-studio.err PVS-studio.log
  plog-converter -t tasklist -o PVS-studio.tsk PVS-studio.log
}

main "$@"
