" Vim indent file
" Language:         KDL
" Author:           Aram Drevekenin <aram@poor.dev>
" Maintainer:       Yinzuo Jiang <jiangyinzuo@foxmail.com>
" Last Change:      2024-06-11

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
    finish
endif
let b:did_indent = 1

setlocal indentexpr=KdlIndent()
let b:undo_indent = "setlocal indentexpr<"

function! KdlIndent(...)
  let line = getline(v:lnum)
  let previousNum = prevnonblank(v:lnum - 1)
  let previous = getline(previousNum)

  if previous =~ "{" && previous !~ "}" && line !~ "}" && line !~ ":$"
    return indent(previousNum) + shiftwidth()
  else
    return indent(previousNum)
  endif
endfunction
