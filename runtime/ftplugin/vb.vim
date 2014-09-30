" Vim filetype plugin file
" Language:	VisualBasic (ft=vb)
" Maintainer:	Johannes Zellner <johannes@zellner.org>
" Last Change:	Thu, 22 Nov 2001 12:56:14 W. Europe Standard Time

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1

setlocal com=sr:'\ -,mb:'\ \ ,el:'\ \ ,:'

" we need this wrapper, as call doesn't allow a count
fun! <SID>VbSearch(pattern, flags)
    let cnt = v:count1
    while cnt > 0
	call search(a:pattern, a:flags)
	let cnt = cnt - 1
    endwhile
endfun

let s:cpo_save = &cpo
set cpo&vim

" NOTE the double escaping \\|
nnoremap <buffer> <silent> [[ :call <SID>VbSearch('^\s*\(\(private\|public\)\s\+\)\=\(function\\|sub\)', 'bW')<cr>
nnoremap <buffer> <silent> ]] :call <SID>VbSearch('^\s*\(\(private\|public\)\s\+\)\=\(function\\|sub\)', 'W')<cr>
nnoremap <buffer> <silent> [] :call <SID>VbSearch('^\s*\<end\>\s\+\(function\\|sub\)', 'bW')<cr>
nnoremap <buffer> <silent> ][ :call <SID>VbSearch('^\s*\<end\>\s\+\(function\\|sub\)', 'W')<cr>

" matchit support
if exists("loaded_matchit")
    let b:match_ignorecase=1
    let b:match_words=
    \ '\%(^\s*\)\@<=\<if\>.*\<then\>\s*$:\%(^\s*\)\@<=\<else\>:\%(^\s*\)\@<=\<elseif\>:\%(^\s*\)\@<=\<end\>\s\+\<if\>,' .
    \ '\%(^\s*\)\@<=\<for\>:\%(^\s*\)\@<=\<next\>,' .
    \ '\%(^\s*\)\@<=\<while\>:\%(^\s*\)\@<=\<wend\>,' .
    \ '\%(^\s*\)\@<=\<do\>:\%(^\s*\)\@<=\<loop\>\s\+\<while\>,' .
    \ '\%(^\s*\)\@<=\<select\>\s\+\<case\>:\%(^\s*\)\@<=\<case\>:\%(^\s*\)\@<=\<end\>\s\+\<select\>,' .
    \ '\%(^\s*\)\@<=\<enum\>:\%(^\s*\)\@<=\<end\>\s\<enum\>,' .
    \ '\%(^\s*\)\@<=\<with\>:\%(^\s*\)\@<=\<end\>\s\<with\>,' .
    \ '\%(^\s*\)\@<=\%(\<\%(private\|public\)\>\s\+\)\=\<function\>\s\+\([^ \t(]\+\):\%(^\s*\)\@<=\<\1\>\s*=:\%(^\s*\)\@<=\<end\>\s\+\<function\>,' .
    \ '\%(^\s*\)\@<=\%(\<\%(private\|public\)\>\s\+\)\=\<sub\>\s\+:\%(^\s*\)\@<=\<end\>\s\+\<sub\>'
endif

let &cpo = s:cpo_save
unlet s:cpo_save
