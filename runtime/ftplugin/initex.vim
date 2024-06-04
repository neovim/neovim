" filetype plugin for TeX and variants
" Language:     TeX (ft=initex)
" Maintainer:   Benji Fisher, Ph.D. <benji@member.AMS.org>
" Version:	1.0
" Last Change:	Wed 19 Apr 2006
" Last Change:	Thu 23 May 2024 by Riley Bruins <ribru17@gmail.com> ('commentstring')

" Only do this when not done yet for this buffer.
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer.
let b:did_ftplugin = 1

" Avoid problems if running in 'compatible' mode.
let s:save_cpo = &cpo
set cpo&vim

let b:undo_ftplugin = "setl com< cms< define< include< sua<"

" Set 'comments' to format dashed lists in comments
setlocal com=sO:%\ -,mO:%\ \ ,eO:%%,:%

" Set 'commentstring' to recognize the % comment character:
" (Thanks to Ajit Thakkar.)
setlocal cms=%\ %s

" Allow "[d" to be used to find a macro definition:
let &l:define='\\\([egx]\|char\|mathchar\|count\|dimen\|muskip\|skip\|toks\)\='
	\ .	'def\|\\font\|\\\(future\)\=let'

" Tell Vim to recognize \input bar :
let &l:include = '\\input'
setlocal suffixesadd=.tex

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:sts=2:sw=2:
