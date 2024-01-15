" Vim filetype plugin file
" Language:     Falcon
" Author:       Steven Oliver <oliver.steven@gmail.com>
" Copyright:    Copyright (c) 2009-2013 Steven Oliver
" License:      You may redistribute this under the same terms as Vim itself
" Last Update:  2020 Oct 10
"               2024 Jan 14 by Vim Project (browsefilter)
" --------------------------------------------------------------------------

" Only do this when not done yet for this buffer
if (exists("b:did_ftplugin"))
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal softtabstop=4 shiftwidth=4
setlocal suffixesadd=.fal,.ftd

" Matchit support
if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_ignorecase = 0

  let b:match_words =
	\ '\<\%(if\|case\|while\|until\|for\|do\|class\)\>=\@!' .
	\ ':' .
	\ '\<\%(else\|elsif\|when\)\>' .
	\ ':' .
	\ '\<end\>' .
	\ ',{:},\[:\],(:)'
endif

setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,://

" Windows allows you to filter the open file dialog
if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Falcon Source Files (*.fal, *.ftd)\t*.fal;*.ftd\n"
  if has("win32")
    let b:browsefilter ..= "All Files (*.*)\t*\n"
  else
    let b:browsefilter ..= "All Files (*)\t*\n"
  endif
endif

let b:undo_ftplugin = "setlocal tabstop< shiftwidth< expandtab< fileencoding<"
	\ . " suffixesadd< comments<"
	\ . "| unlet! b:browsefilter"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: set sw=4 sts=4 et tw=80 :
