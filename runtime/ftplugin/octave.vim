" Vim filetype plugin file
" Language:	GNU Octave
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Jan 14

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

" TODO: update Matlab ftplugin and source it as the base file?

setlocal comments=s:%{,m:\ ,e:%},s:#{,m:\ ,e:#},:%,:#
setlocal commentstring=#\ %s
setlocal formatoptions-=t formatoptions+=croql

setlocal keywordprg=info\ octave\ --vi-keys\ --index-search

if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_words = '\<unwind_protect\>:\<unwind_protect_cleanup\>:\<end_unwind_protect\>'
  if exists("octave_use_matlab_end")
    let b:match_words ..= ',' ..
	                \ '\<\%(classdef\|enumeration\|events\|for\|function\|if\|methods\|parfor\|properties\|switch\|while\|try\)\>' ..
                        \ ':' ..
			\ '\<\%(elseif\|else\|case\|otherwise\|break\|continue\|catch\)\>' ..
                        \ ':' ..
			\ '\<end\>'
  else
    let b:match_words ..= ',' ..
                        \ '\<classdef\>:\<endclassdef\>,' ..
			\ '\<enumeration\>:\<endenumeration\>,' ..
			\ '\<events\>:\<endevents\>,' ..
			\ '\<do\>:\<\%(break\|continue\)\>:\<until\>' ..
			\ '\<for\>:\<\%(break\|continue\)\>:\<endfor\>,' ..
			\ '\<function\>:\<return\>:\<endfunction\>,' ..
			\ '\<if\>:\<\%(elseif\|else\)\>:\<endif\>,' ..
			\ '\<methods\>:\<endmethods\>,' ..
			\ '\<parfor\>:\<endparfor\>,' ..
			\ '\<properties\>:\<endproperties\>,' ..
			\ '\<switch\>:\<\%(case\|otherwise\)\>:\<endswitch\>,' ..
			\ '\<while\>:\<\%(break\|continue\)\>:\<endwhile\>,' ..
			\ '\<try\>:\<catch\>:\<end_try_catch\>'
  endif
  " only match in statement position
  let s:statement_start = escape('\%(\%(^\|;\)\s*\)\@<=', '\')
  let b:match_words = substitute(b:match_words, '\\<', s:statement_start, 'g')
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "GNU Octave Source Files (*.m)\t*.m\n"
  if has("win32")
    let b:browsefilter ..= "All Files (*.*)\t*\n"
  else
    let b:browsefilter ..= "All Files (*)\t*\n"
  endif
endif

let b:undo_ftplugin = "setl com< cms< fo< kp< " ..
		    \ "| unlet! b:browsefilter b:match_words"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet:
