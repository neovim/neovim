" Vim filetype plugin file
" Language:	QB64
" Maintainer:	Doug Kearns <dougkearns@gmail.com>

if exists("b:did_ftplugin")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

runtime! ftplugin/basic.vim

let s:not_end = '\%(end\s\+\)\@<!'

let b:match_words ..= ',' ..
		\     s:not_end .. '\<declare\>:\<end\s\+declare\>,' ..
		\     '\<select\s\+everycase\>:\%(select\s\+\)\@<!\<case\%(\s\+\%(else\|is\)\)\=\>:\<end\s\+select\>,' ..
		\     '$IF\>:$\%(ELSEIF\|ELSE\)\>:$END\s*IF\>'

unlet s:not_end

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet fdm=marker:
