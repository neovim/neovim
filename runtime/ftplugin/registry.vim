" Vim filetype plugin file
" Language:         Windows Registry export with regedit (*.reg)
" Maintainer:       Cade Forester <ahx2323@gmail.com>
" Latest Revision:  2014-01-09

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin =
  \ 'let b:browsefilter = "" | ' .
  \ 'setlocal ' .
  \    'comments< '.
  \    'commentstring< ' .
  \    'formatoptions< '


if has( 'gui_win32' )
\ && !exists( 'b:browsefilter' )
   let b:browsefilter =
      \ 'registry files (*.reg)\t*.reg\n' .
      \ 'All files (*.*)\t*.*\n'
endif

setlocal comments=:;
setlocal commentstring=;\ %s

setlocal formatoptions-=t
setlocal formatoptions+=croql

let &cpo = s:cpo_save
unlet s:cpo_save
