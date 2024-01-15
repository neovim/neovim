" Vim filetype plugin file
" Language: R
" Maintainer: Jakson Alves de Aquino <jalvesaq@gmail.com>
" Homepage: https://github.com/jalvesaq/R-Vim-runtime
" Last Change:	Sun Apr 24, 2022  09:14AM
"		2024 Jan 14 by Vim Project (browsefilter)

" Only do this when not yet done for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal iskeyword=@,48-57,_,.
setlocal formatoptions-=t
setlocal commentstring=#\ %s
setlocal comments=:#',:###,:##,:#

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "R Source Files (*.R)\t*.R\n" .
        \ "Files that include R (*.Rnw *.Rd *.Rmd *.Rrst *.qmd)\t*.Rnw;*.Rd;*.Rmd;*.Rrst;*.qmd\n"
  if has("win32")
    let b:browsefilter .= "All Files (*.*)\t*\n"
  else
    let b:browsefilter .= "All Files (*)\t*\n"
  endif
endif

let b:undo_ftplugin = "setl cms< com< fo< isk< | unlet! b:browsefilter"

let &cpo = s:cpo_save
unlet s:cpo_save
