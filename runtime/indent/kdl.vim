" Vim indent file
" Language:         KDL
" Author:           Aram Drevekenin <aram@poor.dev>
" Maintainer:       Yinzuo Jiang <jiangyinzuo@foxmail.com>
" Last Change:      2024-06-16

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
    finish
endif
let b:did_indent = 1

setlocal indentexpr=KdlIndent()
let b:undo_indent = "setlocal indentexpr<"

function! KdlIndent(...)
  let line = substitute(getline(v:lnum), '//.*$', '', '')
  let previousNum = prevnonblank(v:lnum - 1)
  let previous = substitute(getline(previousNum), '//.*$', '', '')

  let l:indent = indent(previousNum)
  if previous =~ "{" && previous !~ "}"
    let l:indent += shiftwidth()
  endif
  if line =~ "}" && line !~ "{"
    let l:indent -= shiftwidth()
  endif
  return l:indent
endfunction
" vim: sw=2 sts=2 et
