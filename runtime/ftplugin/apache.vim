" Vim filetype plugin
" Language:	apache configuration file
" Maintainer:	Per Juchtmans <dubgeiser+vimNOSPAM@gmail.com>
" Last Change:	2022 Oct 22

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal comments=:#
setlocal commentstring=#\ %s

let b:undo_ftplugin = "setlocal comments< commentstring<"

" vim: nowrap sw=2 sts=2 ts=8 noet:
