" Vim filetype plugin file
" Language: sway config file
" Original Author: James Eapen <james.eapen@vai.org>
" Maintainer: James Eapen <james.eapen@vai.org>
" Version: 0.1
" Last Change: 2022 June 07

if exists("b:did_ftplugin")
  finish
endif

let b:did_ftplugin = 1

let b:undo_ftplugin = "setlocal cms<"

setlocal commentstring=#\ %s
