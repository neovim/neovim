" Vim filetype plugin file
" Language:	SWIG
" Maintainer:	Julien Marrec <julien.marrec 'at' gmail com>
" Last Change:	2023 November 23
" 2025 July 14 by Vim project: set 'comment'/'commentstring' options

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let b:undo_ftplugin = "setlocal iskeyword< comments< commentstring<"
setlocal iskeyword+=%
setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,://
setlocal commentstring=//\ %s
