" Vim filetype plugin file
" Language:	Bazel rc file
" Maintainer:	Barrett Ruth <br@barrettruth.com>
" Last Change:	2026 Aug 25

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal comments=:#
setlocal commentstring=#\ %s
setlocal formatoptions-=t formatoptions+=croql

let b:undo_ftplugin = "setlocal com< cms< fo<"

" vim: ts=8
