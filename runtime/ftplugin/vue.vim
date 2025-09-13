" Vim filetype plugin file
" Language:	vue
" Last Change:
" 2025 Jun 09 by Vim project set comment options #17479

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1

" Make sure the continuation lines below do not cause problems in
" compatibility mode.
let s:save_cpo = &cpo
set cpo-=C

setlocal commentstring=<!--\ %s\ -->
setlocal comments=s:<!--,m:\ \ \ \ ,e:-->

let b:undo_ftplugin = "setlocal comments< commentstring<"

" Copied from ftplugin/html.vim
" Original thanks to Johannes Zellner and Benji Fisher.
if exists("loaded_matchit")
  let b:match_ignorecase = 1
  let b:match_words = '<:>,'
	\ .. '<\@<=[ou]l\>[^>]*\%(>\|$\):<\@<=li\>:<\@<=/[ou]l>,'
	\ .. '<\@<=dl\>[^>]*\%(>\|$\):<\@<=d[td]\>:<\@<=/dl>,'
	\ .. '<\@<=\([^/][^ \t>]*\)[^>]*\%(>\|$\):<\@<=/\1>'
	let b:undo_ftplugin .= ' | unlet! b:match_words b:match_ignorecase'
endif

" Restore the saved compatibility options.
let &cpo = s:save_cpo
unlet s:save_cpo
