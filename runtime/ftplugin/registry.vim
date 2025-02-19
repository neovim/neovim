" Vim filetype plugin file
" Language:         Windows Registry export with regedit (*.reg)
" Maintainer:       Cade Forester <ahx2323@gmail.com>
" Latest Revision:  2014-01-09
"                   2024 Jan 14 by Vim Project (browsefilter)

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin =
  \ 'setlocal ' .
  \    'comments< '.
  \    'commentstring< ' .
  \    'formatoptions<'


if ( has( 'gui_win32' ) || has( 'gui_gtk' ) )
\ && !exists( 'b:browsefilter' )
   let b:browsefilter =
      \ "registry files (*.reg)\t*.reg\n"
   if has("win32")
      let b:browsefilter .= "All Files (*.*)\t*\n"
   else
      let b:browsefilter .= "All Files (*)\t*\n"
   endif
   let b:undo_ftplugin .= " | unlet! b:browsefilter"
endif

setlocal comments=:;
setlocal commentstring=;\ %s

setlocal formatoptions-=t
setlocal formatoptions+=croql

let &cpo = s:cpo_save
unlet s:cpo_save
