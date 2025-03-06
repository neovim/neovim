" Vim filetype plugin file
" Language:             Tera
" Maintainer:           Muntasir Mahmud <muntasir.joypurhat@gmail.com>
" Last Change:          2025 Mar 06

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal commentstring={#\ %s\ #}

let b:undo_ftplugin = "setlocal commentstring<"
