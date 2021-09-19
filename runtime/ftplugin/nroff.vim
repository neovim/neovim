" Vim filetype plugin
" Language:	roff(7)
" Maintainer:	Aman Verma
" Homepage:	https://github.com/a-vrma/vim-nroff-ftplugin
" Previous Maintainer:	Chris Spiegel <cspiegel@gmail.com>
" Last Change:	2020 Nov 21

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal commentstring=.\\\"%s
setlocal comments=:.\\\"
setlocal sections+=Sh

let b:undo_ftplugin = 'setlocal commentstring< comments< sections<'
