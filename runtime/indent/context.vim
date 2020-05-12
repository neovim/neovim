" ConTeXt indent file
" Language: ConTeXt typesetting engine
" Maintainer: Nicola Vitacolonna <nvitacolonna@gmail.com>
" Last Change:  2016 Oct 15

if exists("b:did_indent")
  finish
endif

if !get(b:, 'context_metapost', get(g:, 'context_metapost', 1))
  finish
endif

" Load MetaPost indentation script
runtime! indent/mp.vim

let s:keepcpo= &cpo
set cpo&vim

setlocal indentexpr=GetConTeXtIndent()

let b:undo_indent = "setl indentexpr<"

function! GetConTeXtIndent()
  " Use MetaPost rules inside MetaPost graphic environments
  if len(synstack(v:lnum, 1)) > 0 &&
        \ synIDattr(synstack(v:lnum, 1)[0], "name") ==# 'contextMPGraphic'
    return GetMetaPostIndent()
  endif
  return -1
endfunc

let &cpo = s:keepcpo
unlet s:keepcpo

" vim:sw=2
