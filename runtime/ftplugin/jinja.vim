" Vim ftplugin file
" Language: Jinja
" Maintainer: Alejandro Sanchez
" Upstream: https://gitlab.com/HiPhish/jinja.vim

if exists("b:did_jinjaplugin")
 finish
endif

setlocal commentstring={#\ %s\ #}
let b:undo_ftplugin = "setlocal com<"
