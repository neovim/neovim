" Vim filetype plugin file
" Language:	bind zone file
" Maintainer:	This runtime file is looking for a new maintainer.
" Last Change:	2024 Jul 06

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin=1

setlocal comments=b:;
setlocal commentstring=;\ %s
setlocal formatoptions-=t
setlocal formatoptions+=crq

let b:undo_ftplugin = "setlocal com< cms< fo<"
