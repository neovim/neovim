" Vim indent file (experimental).
" Language:    Astro
" Author:      Wuelner Martínez <wuelner.martinez@outlook.com>
" Maintainer:  Wuelner Martínez <wuelner.martinez@outlook.com>
" URL:         https://github.com/wuelnerdotexe/vim-astro
" Last Change: 2022 Aug 07
" Based On:    Evan Lecklider's vim-svelte
" Changes:     See https://github.com/evanleck/vim-svelte
" Credits:     See vim-svelte on github

" Only load this indent file when no other was loaded yet.
if exists('b:did_indent')
  finish
endif

let b:html_indent_script1 = 'inc'
let b:html_indent_style1 = 'inc'

" Embedded HTML indent.
runtime! indent/html.vim
let s:html_indent = &l:indentexpr
unlet b:did_indent

let b:did_indent = 1

setlocal indentexpr=GetAstroIndent()
setlocal indentkeys=<>>,/,0{,{,},0},0),0],0\,<<>,,!^F,*<Return>,o,O,e,;

let b:undo_indent = 'setl inde< indk<'

" Only define the function once.
if exists('*GetAstroIndent')
  finish
endif

let s:cpoptions_save = &cpoptions
setlocal cpoptions&vim

function! GetAstroIndent()
  let l:current_line_number = v:lnum

  if l:current_line_number == 0
    return 0
  endif

  let l:current_line = getline(l:current_line_number)

  if l:current_line =~ '^\s*</\?\(script\|style\)'
    return 0
  endif

  let l:previous_line_number = prevnonblank(l:current_line_number - 1)
  let l:previous_line = getline(l:previous_line_number)
  let l:previous_line_indent = indent(l:previous_line_number)

  if l:previous_line =~ '^\s*</\?\(script\|style\)'
    return l:previous_line_indent + shiftwidth()
  endif

  execute 'let l:indent = ' . s:html_indent

  if searchpair('<style>', '', '</style>', 'bW') &&
        \ l:previous_line =~ ';$' && l:current_line !~ '}'
    return l:previous_line_indent
  endif

  if synID(l:previous_line_number, match(
        \   l:previous_line, '\S'
        \ ) + 1, 0) == hlID('htmlTag') && synID(l:current_line_number, match(
        \  l:current_line, '\S'
        \ ) + 1, 0) != hlID('htmlEndTag')
    let l:indents_match = l:indent == l:previous_line_indent
    let l:previous_closes = l:previous_line =~ '/>$'

    if l:indents_match &&
          \ !l:previous_closes && l:previous_line =~ '<\(\u\|\l\+:\l\+\)'
      return l:previous_line_indent + shiftwidth()
    elseif !l:indents_match && l:previous_closes
      return l:previous_line_indent
    endif
  endif

  return l:indent
endfunction

let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
" vim: ts=8
