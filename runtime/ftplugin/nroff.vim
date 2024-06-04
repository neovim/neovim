" Vim filetype plugin
" Language:	roff(7)
" Maintainer:	Aman Verma
" Homepage:	https://github.com/a-vrma/vim-nroff-ftplugin
" Previous Maintainer: Chris Spiegel <cspiegel@gmail.com>
"		2024 May 24 by Riley Bruins <ribru17@gmail.com> ('commentstring')

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal commentstring=.\\\"\ %s
setlocal comments=:.\\\"
setlocal sections+=Sh

let b:undo_ftplugin = 'setlocal commentstring< comments< sections<'
