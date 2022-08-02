" Vim indent file
" Language:	RPL/2
" Version:	0.2
" Last Change:	2017 Jun 13
" Maintainer:	BERTRAND Joël <rpl2@free.fr>

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal autoindent
setlocal indentkeys+==~end,=~case,=~if,=~then,=~else,=~do,=~until,=~while,=~repeat,=~select,=~default,=~for,=~start,=~next,=~step,<<>,<>>

" Define the appropriate indent function but only once
setlocal indentexpr=RplGetFreeIndent()
if exists("*RplGetFreeIndent")
  finish
endif

let b:undo_indent = "set ai< indentkeys< indentexpr<"

function RplGetIndent(lnum)
  let ind = indent(a:lnum)
  let prevline=getline(a:lnum)
  " Strip tail comment
  let prevstat=substitute(prevline, '!.*$', '', '')

  " Add a shiftwidth to statements following if, iferr, then, else, elseif,
  " case, select, default, do, until, while, repeat, for, start
  if prevstat =~? '\<\(if\|iferr\|do\|while\)\>' && prevstat =~? '\<end\>'
  elseif prevstat =~? '\(^\|\s\+\)<<\($\|\s\+\)' && prevstat =~? '\s\+>>\($\|\s\+\)'
  elseif prevstat =~? '\<\(if\|iferr\|then\|else\|elseif\|select\|case\|do\|until\|while\|repeat\|for\|start\|default\)\>' || prevstat =~? '\(^\|\s\+\)<<\($\|\s\+\)'
    let ind = ind + shiftwidth()
  endif

  " Subtract a shiftwidth from then, else, elseif, end, until, repeat, next,
  " step
  let line = getline(v:lnum)
  if line =~? '^\s*\(then\|else\|elseif\|until\|repeat\|next\|step\|default\|end\)\>'
    let ind = ind - shiftwidth()
  elseif line =~? '^\s*>>\($\|\s\+\)'
    let ind = ind - shiftwidth()
  endif

  return ind
endfunction

function RplGetFreeIndent()
  " Find the previous non-blank line
  let lnum = prevnonblank(v:lnum - 1)

  " Use zero indent at the top of the file
  if lnum == 0
    return 0
  endif

  let ind=RplGetIndent(lnum)
  return ind
endfunction

" vim:sw=2 tw=130
