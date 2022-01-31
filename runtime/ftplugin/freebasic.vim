" Vim filetype plugin file
" Language:	FreeBASIC
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2021 Mar 16

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
  let s:not_end = '\%(end\s\+\)\@<!'

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
		  \	'^#\s*\%(if\|ifdef\|ifndef\)\>:^#\s*\%(else\|elseif\)\>:^#\s*endif\>,' ..
		  \	'^#\s*macro\>:^#\s*endmacro\>'

  " skip "function = <retval>"
  let b:match_skip ..= '|| strpart(getline("."), col(".") - 1) =~? "^\\<function\\s\\+="'

  unlet s:not_end
endif

" Cleanup {{{1
let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet fdm=marker:
