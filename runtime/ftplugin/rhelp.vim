" Vim filetype plugin file
" Language: R help file
" Maintainer: Jakson Alves de Aquino <jalvesaq@gmail.com>
" Homepage: https://github.com/jalvesaq/R-Vim-runtime
" Last Change:	Sun Apr 24, 2022  09:12AM

" Only do this when not yet done for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal iskeyword=@,48-57,_,.

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "R Source Files (*.R *.Rnw *.Rd *.Rmd *.Rrst *.qmd)\t*.R;*.Rnw;*.Rd;*.Rmd;*.Rrst;*.qmd\n" .
        \ "All Files (*.*)\t*.*\n"
endif

let b:undo_ftplugin = "setl isk< | unlet! b:browsefilter"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: sw=2
