" Vim indent file
" Language:    Hamster Script 
" Version:     2.0.6.1
" Last Change: 2021 Oct 11
" Maintainer:  David Fishburn <dfishburn dot vim at gmail dot com>
" Download: https://www.vim.org/scripts/script.php?script_id=1099
"
"    2.0.6.1 (Oct 2021)
"        Added b:undo_indent
"        Added cpo check
"

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentkeys+==~if,=~else,=~endif,=~endfor,=~endwhile
setlocal indentkeys+==~do,=~until,=~while,=~repeat,=~for,=~loop
setlocal indentkeys+==~sub,=~endsub

let b:undo_indent = "setl indentkeys<"

" Define the appropriate indent function but only once
setlocal indentexpr=HamGetFreeIndent()
if exists("*HamGetFreeIndent")
  finish
endif

let s:keepcpo = &cpo
set cpo&vim

function HamGetIndent(lnum)
  let ind = indent(a:lnum)
  let prevline=getline(a:lnum)

  " Add a shiftwidth to statements following if,  else, elseif,
  " case, select, default, do, until, while, for, start
  if prevline =~? '^\s*\<\(if\|else\%(if\)\?\|for\|repeat\|do\|while\|sub\)\>' 
    let ind = ind + shiftwidth()
  endif

  " Subtract a shiftwidth from else, elseif, end(if|while|for), until
  let line = getline(v:lnum)
  if line =~? '^\s*\(else\|elseif\|loop\|until\|end\%(if\|while\|for\|sub\)\)\>'
    let ind = ind - shiftwidth()
  endif

  return ind
endfunction

function HamGetFreeIndent()
  " Find the previous non-blank line
  let lnum = prevnonblank(v:lnum - 1)

  " Use zero indent at the top of the file
  if lnum == 0
    return 0
  endif

  let ind=HamGetIndent(lnum)
  return ind
endfunction

" Restore:
let &cpo = s:keepcpo
unlet s:keepcpo

" vim:sw=2 tw=80
