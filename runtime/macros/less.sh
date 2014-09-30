#!/bin/sh
# Shell script to start Vim with less.vim.
# Read stdin if no arguments were given and stdin was redirected.

if test -t 1; then
  if test $# = 0; then
    if test -t 0; then
      echo "Missing filename" 1>&2
      exit
    fi
    vim --cmd 'let no_plugin_maps = 1' -c 'runtime! macros/less.vim' -
  else
    vim --cmd 'let no_plugin_maps = 1' -c 'runtime! macros/less.vim' "$@"
  fi
else
  # Output is not a terminal, cat arguments or stdin
  if test $# = 0; then
    if test -t 0; then
      echo "Missing filename" 1>&2
      exit
    fi
    cat
  else
    cat "$@"
  fi
fi
