" Vim indent file
" Language:    Hamster Script 
" Version:     2.0.6.0
" Last Change: Wed Nov 08 2006 12:02:42 PM
" Maintainer:  David Fishburn <fishburn@ianywhere.com>

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentkeys+==~if,=~else,=~endif,=~endfor,=~endwhile
setlocal indentkeys+==~do,=~until,=~while,=~repeat,=~for,=~loop
setlocal indentkeys+==~sub,=~endsub

" Define the appropriate indent function but only once
setlocal indentexpr=HamGetFreeIndent()
if exists("*HamGetFreeIndent")
  finish
endif

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

" vim:sw=2 tw=80
