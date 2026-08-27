" Vim filetype plugin
" Language:		Algol 68
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Last Change:		2026 Apr 23

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

" TODO: 'comments'

setlocal commentstring=#\ %s\ #

let &l:include='\c\%(^\|;\)\s*\%(PR\|PRAGMAT\)\s\+\%(read\|include\)'

let b:undo_ftplugin = "setl cms< inc<"

if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_ignorecase = 0
  let b:match_words = '\<BEGIN\>:\<END\>,' ..
	\	      '\<IF\>:\<THEN\>:\<ELIF\>:\<ELSE\>:\<FI\>,' ..
	\	      '\<CASE\>:\<IN\>:\<OUSE\>:\<OUT\>:\<ESAC\>,' ..
	"\ TODO: loops have overlapping start and intermediate keywords like
	"\ `TO` which are difficult to match with patterns alone.
	\	      '\<DO\>:\<OD\>'
  let b:match_skip = 's:Comment\|String\|PreProc'
  let b:undo_ftplugin ..= " | unlet! b:match_ignorecase b:match_skip b:match_words"
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Algol 68 Source Files (*.a68)\t*.a68\n"
  if has("win32")
    let b:browsefilter ..= "All Files (*.*)\t*\n"
  else
    let b:browsefilter ..= "All Files (*)\t*\n"
  endif
  let b:undo_ftplugin ..= " | unlet! b:browsefilter"
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8
