#!/bin/sh
set -e

get_jobs_num() {
  local num="$(cat /proc/cpuinfo | grep -c "^processor")"
  num="$(echo $(( num + 1 )))"
  num="${num:-1}"
  echo $num
}

help() {
  echo 'Usage:'
  echo '  pvscheck.sh [target-directory [branch]]'
  echo '  pvscheck.sh [--recheck] [target-directory]'
  echo '  pvscheck.sh --patch [--only-build]'
  echo
  echo '    --patch: patch sources in the current directory.'
  echo '             Does not patch already patched files.'
  echo '             Does not run analysis.'
  echo
  echo '    --only-build: Only patch files in ./build directory.'
  echo
  echo '    --recheck: run analysis on a prepared target directory.'
  echo
  echo '    target-directory: Directory where build should occur.'
  echo '                      Default: ../neovim-pvs'
  echo
  echo '    branch: Branch to check.'
  echo '            Default: master.'
}

get_pvs_comment() {
  cat > pvs-comment << EOF
// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

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
    pvs_comment="$(cat pvs-comment ; echo -n EOS)"
    filehead="$(head -c $(( ${#pvs_comment} - 3 )) "$1" ; echo -n EOS)"
    if test "x$filehead" != "x$pvs_comment" ; then
      cat pvs-comment "$1" > "$1.tmp"
      mv "$1.tmp" "$1"
    fi
  '

  if test "x$1" != "x--only-build" ; then
    find \
      src/nvim test/functional/fixtures test/unit/fixtures \
      -name '*.c' \
      -exec /bin/sh -c "$sh_script" - '{}' \;
  fi

  find \
    build/src/nvim/auto build/config \
    -name '*.c' -not -name '*.test-include.c' \
    -exec /bin/sh -c "$sh_script" - '{}' \;

  rm pvs-comment
}

run_analysis() {
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

do_check() {
  local tgt="${1}"
  local branch="${2}"

  git clone --branch="$branch" . "$tgt"

  cd "$tgt"

  install_pvs

  create_compile_commands

  run_analysis
}

do_recheck() {
  local tgt="${1}"

  cd "$tgt"

  export PATH="$PWD/pvs-studio/bin${PATH+:}${PATH}"

  run_analysis
}

main() {
  local PVS_URL="http://files.viva64.com/pvs-studio-6.15.21741.1-x86_64.tgz"

  if test "$1" = "--help" ; then
    help
    return
  fi

  set -x

  if test "$1" = "--patch" ; then
    shift
    if test "$1" = "--only-build" ; then
      shift
      patch_sources --only-build
    else
      patch_sources
    fi
    exit $?
  fi

  local recheck=
  if test "$1" = "--recheck" ; then
    recheck=1
    shift
  fi

  local tgt="${1:-$PWD/../neovim-pvs}"
  local branch="${2:-master}"

  if test -z "$recheck" ; then
    do_check "$tgt" "$branch"
  else
    do_recheck "$tgt"
  fi
}

main "$@"
