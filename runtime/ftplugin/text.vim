" Vim filetype plugin
" Language:		Text
" Maintainer:		David Barnett <daviebdawg+vim@gmail.com>
" Last Change:		2014 Jul 09

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

let b:undo_ftplugin = 'setlocal comments< commentstring<'

" We intentionally don't set formatoptions-=t since text should wrap as text.

" Pseudo comment leaders to indent bulleted lists.
setlocal comments=fb:-,fb:*
setlocal commentstring=
