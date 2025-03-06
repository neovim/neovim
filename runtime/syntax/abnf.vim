" Vim compiler file
" Language:	abnf
" Maintainer:	A4-Tacks <wdsjxhno1001@163.com>
" Last Change:	2025 Mar 05
" Upstream:	https://github.com/A4-Tacks/abnf.vim

" Implementing RFC-5234, RFC-7405

if exists('b:current_syntax')
  finish
endif

syn case ignore

syn match  abnfError	/[<>"]/
syn match  abnfComment	/;.*/
syn match  abnfOption	/[[/\]]/
syn region abnfString	start=/\(%[si]\)\="/ end=/"/ oneline
syn region abnfProse	start=/</ end=/>/ oneline
syn match  abnfNumVal	/\v\%b[01]+%(%(\.[01]+)+|-[01]+)=>/
syn match  abnfNumVal	/\v\%d\d+%(%(\.\d+)+|-\d+)=>/
syn match  abnfNumVal	/\v\%x[0-9a-f]+%(%(\.[0-9a-f]+)+|-[0-9a-f]+)=>/
syn match  abnfRepeat	/\v%(%(<\d+)=\*\d*|<\d+ =)\ze[^ \t\r\n0-9*/)\]]/

hi def link abnfError		Error
hi def link abnfComment		Comment
hi def link abnfOption		PreProc
hi def link abnfString		String
hi def link abnfProse		String
hi def link abnfNumVal		Number
hi def link abnfRepeat		Repeat

" vim:noet:ts=8:sts=8:nowrap
