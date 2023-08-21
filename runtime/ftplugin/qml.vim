" Vim filetype plugin file
" Language: QML
" Maintainer: Chase Knowlden <haroldknowlden@gmail.com>
" Last Change: 2023 Aug 16

if exists( 'b:did_ftplugin' )
   finish
endif
let b:did_ftplugin = 1

let s:cpoptions_save = &cpoptions
set cpoptions&vim

" command for undo
let b:undo_ftplugin = "setlocal formatoptions< comments< commentstring<"

if (has("gui_win32") || has("gui_gtk")) && !exists( 'b:browsefilter' )
   let b:browsefilter =
      \ 'QML Files (*.qml,*.qbs)\t*.qml;*.qbs\n' .
      \ 'All Files\t*\n'
endif

" Set 'comments' to format dashed lists in comments.
setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,://
setlocal commentstring=//%s

setlocal formatoptions-=t
setlocal formatoptions+=croql

let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
