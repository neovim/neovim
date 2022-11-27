" Vim filetype plugin
" Language:     Mermaid
" Maintainer:   Craig MacEachern <https://github.com/craigmac/vim-mermaid>
" Last Change:  2022 Oct 13

if exists("b:did_ftplugin")
  finish
endif

let s:keepcpo= &cpo
set cpo&vim

" Use mermaid live editor's style
setlocal expandtab
setlocal shiftwidth=2
setlocal softtabstop=-1
setlocal tabstop=4

" TODO: comments, formatlist stuff, based on what?
setlocal comments=b:#,fb:-
setlocal commentstring=#\ %s
setlocal formatoptions+=tcqln formatoptions-=r formatoptions-=o
setlocal formatlistpat=^\\s*\\d\\+\\.\\s\\+\\\|^\\s*[-*+]\\s\\+\\\|^\\[^\\ze[^\\]]\\+\\]:\\&^.\\{4\\}

if exists('b:undo_ftplugin')
  let b:undo_ftplugin .= "|setl cms< com< fo< flp< et< ts< sts< sw<"
else
  let b:undo_ftplugin = "setl cms< com< fo< flp< et< ts< sts< sw<"
endif

if !exists("g:no_plugin_maps") && !exists("g:no_markdown_maps")
  nnoremap <silent><buffer> [[ :<C-U>call search('\%(^#\{1,5\}\s\+\S\\|^\S.*\n^[=-]\+$\)', "bsW")<CR>
  nnoremap <silent><buffer> ]] :<C-U>call search('\%(^#\{1,5\}\s\+\S\\|^\S.*\n^[=-]\+$\)', "sW")<CR>
  xnoremap <silent><buffer> [[ :<C-U>exe "normal! gv"<Bar>call search('\%(^#\{1,5\}\s\+\S\\|^\S.*\n^[=-]\+$\)', "bsW")<CR>
  xnoremap <silent><buffer> ]] :<C-U>exe "normal! gv"<Bar>call search('\%(^#\{1,5\}\s\+\S\\|^\S.*\n^[=-]\+$\)', "sW")<CR>
  let b:undo_ftplugin .= '|sil! nunmap <buffer> [[|sil! nunmap <buffer> ]]|sil! xunmap <buffer> [[|sil! xunmap <buffer> ]]'
endif

" if has("folding") && get(g:, "markdown_folding", 0)
"   setlocal foldexpr=MarkdownFold()
"   setlocal foldmethod=expr
"   setlocal foldtext=MarkdownFoldText()
"   let b:undo_ftplugin .= "|setl foldexpr< foldmethod< foldtext<"
" endif

let &cpo = s:keepcpo
unlet s:keepcpo

" vim:set sw=2:
