" Vim filetype plugin
" Language:	Java properties file
" Maintainer:	David Bürgin <676c7473@gmail.com>
" Last Change:	2013-11-19

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal formatoptions-=t
setlocal comments=:#,:!
setlocal commentstring=#\ %s

let b:undo_ftplugin = "setl cms< com< fo<"
