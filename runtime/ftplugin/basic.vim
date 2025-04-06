" Vim filetype plugin file
" Language:	BASIC (QuickBASIC 4.5)
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Jan 14

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal comments=:REM\ ,:Rem\ ,:rem\ ,:'
setlocal commentstring='\ %s
setlocal formatoptions-=t formatoptions+=croql

let b:undo_ftplugin = "setl fo< com< cms<"

" TODO: support exit ... as middle matches?
if exists("loaded_matchit") && !exists("b:match_words")
  let s:line_start	= '\%(^\s*\)\@<='
  let s:not_end		= '\%(end\s\+\)\@<!'
  let s:not_end_or_exit	= '\%(\%(end\|exit\)\s\+\)\@<!'

  let b:match_ignorecase = 1
  let b:match_words =
		\     s:not_end_or_exit .. '\<def\s\+fn:\<end\s\+def\>,' ..
		\     s:not_end_or_exit .. '\<function\>:\<end\s\+function\>,' ..
		\     s:not_end_or_exit .. '\<sub\>:\<end\s\+sub\>,' ..
		\     s:not_end .. '\<type\>:\<end\s\+type\>,' ..
		\     s:not_end .. '\<select\>:\%(select\s\+\)\@<!\<case\%(\s\+\%(else\|is\)\)\=\>:\<end\s\+select\>,' ..
		\     '\<do\>:\<loop\>,' ..
		\     '\<for\>\%(\s\+\%(input\|output\|random\|append\|binary\)\)\@!:\<next\>,' ..
		\     '\<while\>:\<wend\>,' ..
		\     s:line_start .. 'if\%(.*\<then\s*\%($\|''\)\)\@=:\<\%(' .. s:line_start .. 'else\|elseif\)\>:\<end\s\+if\>,' ..
		\     '\<lock\>:\<unlock\>'
  let b:match_skip = 'synIDattr(synID(line("."),col("."),1),"name") =~? "comment\\|string" || ' ..
		\    'strpart(getline("."), 0, col(".") ) =~? "\\<exit\\s\\+"'

  let b:undo_ftplugin ..= " | unlet! b:match_ignorecase b:match_skip b:match_words"

  unlet s:line_start s:not_end s:not_end_or_exit
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "BASIC Source Files (*.bas)\t*.bas\n" ..
		\      "BASIC Include Files (*.bi, *.bm)\t*.bi;*.bm\n"
  if has("win32")
    let b:browsefilter ..= "All Files (*.*)\t*\n"
  else
    let b:browsefilter ..= "All Files (*)\t*\n"
  endif
  let b:basic_set_browsefilter = 1
  let b:undo_ftplugin ..= " | unlet! b:browsefilter b:basic_set_browsefilter"
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet fdm=marker:
