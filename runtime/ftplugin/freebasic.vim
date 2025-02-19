" Vim filetype plugin file
" Language:	FreeBASIC
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2023 Aug 22

" Setup {{{1
if exists("b:did_ftplugin")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

runtime! ftplugin/basic.vim

let s:dialect = freebasic#GetDialect()

" Comments {{{1
" add ''comments before 'comments
let &l:comments = "sO:*\ -,mO:*\ \ ,exO:*/,s1:/',mb:',ex:'/,:''," .. &l:comments

" Match words {{{1
if exists("loaded_matchit")
  let s:line_start = '\%(^\s*\)\@<='
  let s:not_end    = '\%(end\s\+\)\@<!'

  let b:match_words ..= ','

  if s:dialect == 'fb'
    let b:match_words ..= s:not_end .. '\<constructor\>:\<end\s\+constructor\>,' ..
		  \	  s:not_end .. '\<destructor\>:\<end\s\+destructor\>,' ..
		  \	  s:not_end .. '\<property\>:\<end\s\+property\>,' ..
		  \	  s:not_end .. '\<operator\>:\<end\s\+operator\>,' ..
		  \	  s:not_end .. '\<extern\%(\s\+"\)\@=:\<end\s\+extern\>,'
  endif

  if s:dialect == 'fb' || s:dialect == 'deprecated'
    let b:match_words ..= s:not_end .. '\<scope\>:\<end\s\+scope\>,'
  endif

  if s:dialect == 'qb'
    let b:match_words ..= s:not_end .. '\<__asm\>:\<end\s\+__asm\>,' ..
		  \	  s:not_end .. '\<__union\>:\<end\s\+__union\>,' ..
		  \	  s:not_end .. '\<__with\>:\<end\s\+__with\>,'
  else
    let b:match_words ..= s:not_end .. '\<asm\>:\<end\s\+asm\>,' ..
		  \	  s:not_end .. '\<namespace\>:\<end\s\+namespace\>,' ..
		  \	  s:not_end .. '\<union\>:\<end\s\+union\>,' ..
		  \	  s:not_end .. '\<with\>:\<end\s\+with\>,'
  endif

  let b:match_words ..= s:not_end .. '\<enum\>:\<end\s\+enum\>,' ..
		\     s:line_start .. '#\s*\%(if\|ifdef\|ifndef\)\>:' ..
		\       s:line_start .. '#\s*\%(else\|elseif\)\>:' ..
		\     s:line_start .. '#\s*endif\>,' ..
		\     s:line_start .. '#\s*macro\>:' .. s:line_start .. '#\s*endmacro\>,' ..
		\     "/':'/"

  " skip "function = <retval>" and "continue { do | for | while }"
  if s:dialect == "qb"
    let s:continue = "__continue"
  else
    let s:continue = "continue"
  endif
  let b:match_skip ..= ' || strpart(getline("."), col(".") - 1) =~? "^\\<function\\s\\+="' ..
		  \    ' || strpart(getline("."), 0, col(".") ) =~? "\\<' .. s:continue .. '\\s\\+"'

  unlet s:not_end s:line_start
endif

if (has("gui_win32") || has("gui_gtk")) && exists("b:basic_set_browsefilter")
  let b:browsefilter = "FreeBASIC Source Files (*.bas)\t*.bas\n" ..
		\      "FreeBASIC Header Files (*.bi)\t*.bi\n"
  if has("win32")
    let b:browsefilter ..= "All Files (*.*)\t*\n"
  else
    let b:browsefilter ..= "All Files (*)\t*\n"
  endif
endif

" Cleanup {{{1
let &cpo = s:cpo_save
unlet s:cpo_save s:dialect

" vim: nowrap sw=2 sts=2 ts=8 noet fdm=marker:
