#!/usr/bin/env bash

# Provides bash completion for "nvim".

if [[ -n ${BASH_COMPLETION_VERSINFO[*]} ]] \
  && ((BASH_COMPLETION_VERSINFO[0] > 2 || (\
  BASH_COMPLETION_VERSINFO[0] == 2 && BASH_COMPLETION_VERSINFO[1] >= 12))); then
  # use bash-completion >= 2.12
  _comp_nvim() {
    local cur prev words cword
    _comp_initialize -n : -- "$@" || return

    case "$prev" in
      --listen | --server)
        _comp_compgen_filedir

        if [[ "$cur" != /* ]]; then
          _comp_compgen_ip_addresses -a
          compopt -o nospace
        fi

        return
        ;;
    esac

    if [[ "$cur" =~ ^- ]]; then
      # Infers args from "nvim --help".
      _comp_compgen_help
      _comp_compgen -a -- -W "-c -Es -v -h"

      if [[ ${#COMPREPLY[@]} -eq 1 ]]; then
        case "${COMPREPLY-}" in
          -o | -O | -p | -V)
            compopt -o nospace
            ;;
        esac
      fi
      return
    fi

    _comp_compgen_filedir
  } \
    && complete -F _comp_nvim nvim
else
  _comp_nvim() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD - 1]}"

    opts="
      --cmd
      -c
      -l
      -S
      -s
      -u
      -d
      -es -Es
      -h --help
      -i
      -n
      -o
      -O
      -p
      -R
      -v --version
      -V
      --
      --api-info
      --clean
      --embed
      --headless
      --listen
      --remote
      --server
      --startuptime
      "

    if [[ "$cur" =~ ^- ]]; then
      # shellcheck disable=SC2207
      COMPREPLY=($(compgen -W "$opts" -- "$cur"))

      if [[ ${#COMPREPLY[@]} -eq 1 ]]; then
        case "${COMPREPLY-}" in
          -o | -O | -p | -V)
            compopt -o nospace
            ;;
        esac
      fi
      return
    fi

    compopt -o default -o bashdefault
  } \
    && complete -F _comp_nvim nvim
fi

# aliases are not expanded by default during completion.
for cmd in vi vim; do
  [[ "$(alias $cmd 2> /dev/null)" == "alias $cmd='nvim'" ]] \
    && type -f _comp_nvim > /dev/null 2>&1 \
    && ! complete -p $cmd > /dev/null 2>&1 \
    && complete -F _comp_nvim $cmd
done
