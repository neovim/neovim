#!/bin/bash

set -e

if type tmux >/dev/null ; then
  tmp_dir=$(mktemp -d)
  fifo="$tmp_dir/progress"
  mkfifo "$fifo"
  echo "Using tmux, with tmp dir $tmp_dir"
  tmux new-session -d "./runtests_child.sh -t '$*' -d '$tmp_dir'"
  cat "$fifo"
  read result < "$tmp_dir/result"
  if [[ "$result" != 0 ]] ; then
    echo "Stdout:"
    cat "$tmp_dir/stdout"
    echo "Stderr:"
    cat "$tmp_dir/stderr"
  fi
  rm "$tmp_dir/*" && rmdir "$tmp_dir"
  exit "$result"
else
  echo "Couldn't find tmux :("
  ./runtests_child.sh -d . -t "$*"
fi
