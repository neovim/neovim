" Vim filetype plugin file
" Language: 		SML
" Filenames:		*.sml *.sig
" Maintainer: 		tocariimaa <tocariimaa@firemail.cc>
" Last Change:		2025 Nov 04

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = 'setl com< cms< fo<'

setlocal formatoptions+=croql formatoptions-=t
setlocal commentstring=(*\ %s\ *)
setlocal comments=sr:(*,mb:*,ex:*)

if exists('loaded_matchit')
  let b:match_ignorecase = 0
  let b:match_words = '\<\%(abstype\|let\|local\|sig\|struct\)\>:\<\%(in\|with\)\>:\<end\>'
  let b:undo_ftplugin ..= ' | unlet! b:match_ignorecase b:match_words'
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "SML Source Files (*.sml)\t*.sml\n" ..
                     \ "SML Signature Files (*.sig)\t*.sig\n"
  if has("win32")
    let b:browsefilter ..= "All Files (*.*)\t*\n"
  else
    let b:browsefilter ..= "All Files (*)\t*\n"
  endif
  let b:undo_ftplugin ..= " | unlet! b:browsefilter"
endif

let &cpo = s:cpo_save
unlet s:cpo_save
