" Vim filetype plugin file
" Language:		Visual Basic (ft=vb)
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Johannes Zellner <johannes@zellner.org>
" Last Change:		2021 Nov 17

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal comments=sr:'\ -,mb:'\ \ ,el:'\ \ ,:'
setlocal commentstring='\ %s
setlocal formatoptions-=t formatoptions+=croql

let b:undo_ftplugin = "setlocal com< cms< fo<"

" we need this wrapper, as call doesn't allow a count
function! s:VbSearch(pattern, flags)
    let cnt = v:count1
    while cnt > 0
	call search(a:pattern, a:flags)
	let cnt = cnt - 1
    endwhile
endfunction

if !exists("no_plugin_maps") && !exists("no_vb_maps")
  nnoremap <buffer> <silent> [[ <Cmd>call <SID>VbSearch('^\s*\%(\%(private\<Bar>public\)\s\+\)\=\%(function\<Bar>sub\)', 'sbW')<CR>
  vnoremap <buffer> <silent> [[ <Cmd>call <SID>VbSearch('^\s*\%(\%(private\<Bar>public\)\s\+\)\=\%(function\<Bar>sub\)', 'sbW')<CR>
  nnoremap <buffer> <silent> ]] <Cmd>call <SID>VbSearch('^\s*\%(\%(private\<Bar>public\)\s\+\)\=\%(function\<Bar>sub\)', 'sW')<CR>
  vnoremap <buffer> <silent> ]] <Cmd>call <SID>VbSearch('^\s*\%(\%(private\<Bar>public\)\s\+\)\=\%(function\<Bar>sub\)', 'sW')<CR>
  nnoremap <buffer> <silent> [] <Cmd>call <SID>VbSearch('^\s*end\s\+\%(function\<Bar>sub\)', 'sbW')<CR>
  vnoremap <buffer> <silent> [] <Cmd>call <SID>VbSearch('^\s*end\s\+\%(function\<Bar>sub\)', 'sbW')<CR>
  nnoremap <buffer> <silent> ][ <Cmd>call <SID>VbSearch('^\s*end\s\+\%(function\<Bar>sub\)', 'sW')<CR>
  vnoremap <buffer> <silent> ][ <Cmd>call <SID>VbSearch('^\s*end\s\+\%(function\<Bar>sub\)', 'sW')<CR>
  let b:undo_ftplugin .= " | sil! exe 'nunmap <buffer> [[' | sil! exe 'vunmap <buffer> [['" .
	\		 " | sil! exe 'nunmap <buffer> ]]' | sil! exe 'vunmap <buffer> ]]'" .
	\		 " | sil! exe 'nunmap <buffer> []' | sil! exe 'vunmap <buffer> []'" .
	\		 " | sil! exe 'nunmap <buffer> ][' | sil! exe 'vunmap <buffer> ]['"
endif

" TODO: line start anchors are almost certainly overly restrictive - allow
" after statement separators.  Even in QuickBasic only block IF statements
" were required to be at the start of a line.
if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_ignorecase = 1
  let b:match_words =
	\ '\%(^\s*\)\@<=\<if\>.*\<then\>\s*\%($\|''\):\%(^\s*\)\@<=\<else\>:\%(^\s*\)\@<=\<elseif\>:\%(^\s*\)\@<=\<end\>\s\+\<if\>,' .
	\ '\%(^\s*\)\@<=\<for\>:\%(^\s*\)\@<=\<next\>,' .
	\ '\%(^\s*\)\@<=\<while\>:\%(^\s*\)\@<=\<wend\>,' .
	\ '\%(^\s*\)\@<=\<do\>:\%(^\s*\)\@<=\<loop\>\s\+\<while\>,' .
	\ '\%(^\s*\)\@<=\<select\>\s\+\<case\>:\%(^\s*\)\@<=\<case\>:\%(^\s*\)\@<=\<end\>\s\+\<select\>,' .
	\ '\%(^\s*\)\@<=\<enum\>:\%(^\s*\)\@<=\<end\>\s\<enum\>,' .
	\ '\%(^\s*\)\@<=\<with\>:\%(^\s*\)\@<=\<end\>\s\<with\>,' .
	\ '\%(^\s*\)\@<=\%(\<\%(private\|public\)\>\s\+\)\=\<function\>\s\+\([^ \t(]\+\):\%(^\s*\)\@<=\<\1\>\s*=:\%(^\s*\)\@<=\<end\>\s\+\<function\>,' .
	\ '\%(^\s*\)\@<=\%(\<\%(private\|public\)\>\s\+\)\=\<sub\>\s\+:\%(^\s*\)\@<=\<end\>\s\+\<sub\>'
  let b:undo_ftplugin .= " | unlet! b:match_words b:match_ignorecase"
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Visual Basic Source Files (*.bas)\t*.bas\n" .
	\	       "Visual Basic Form Files (*.frm)\t*.frm\n" .
	\	       "All Files (*.*)\t*.*\n"
  let b:undo_ftplugin .= " | unlet! b:browsefilter"
endif

let &cpo = s:cpo_save
unlet s:cpo_save
