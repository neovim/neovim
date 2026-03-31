" Vim filetype plugin
" Language:		JSON
" Maintainer:		David Barnett <daviebdawg+vim@gmail.com>
" Last Change:		2014 Jul 16

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

let b:undo_ftplugin = 'setlocal formatoptions< comments< commentstring<'

setlocal formatoptions-=t

" JSON has no comments.
setlocal comments=
setlocal commentstring=
