" Vim filetype plugin file
" Language: reStructuredText documentation format with R code
" Maintainer: Jakson Alves de Aquino <jalvesaq@gmail.com>
" Homepage: https://github.com/jalvesaq/R-Vim-runtime
" Last Change:	Tue Apr 07, 2015  04:38PM
" Original work by Alex Zvoleff

" Only do this when not yet done for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal comments=fb:*,fb:-,fb:+,n:> commentstring=>\ %s
setlocal formatoptions+=tcqln
setlocal formatlistpat=^\\s*\\d\\+\\.\\s\\+\\\|^\\s*[-*+]\\s\\+
setlocal iskeyword=@,48-57,_,.

if has("gui_win32") && !exists("b:browsefilter")
  let b:browsefilter = "R Source Files (*.R *.Rnw *.Rd *.Rmd *.Rrst)\t*.R;*.Rnw;*.Rd;*.Rmd;*.Rrst\n" .
        \ "All Files (*.*)\t*.*\n"
endif

if exists('b:undo_ftplugin')
  let b:undo_ftplugin .= " | setl cms< com< fo< flp< isk< | unlet! b:browsefilter"
else
  let b:undo_ftplugin = "setl cms< com< fo< flp< isk< | unlet! b:browsefilter"
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: sw=2
