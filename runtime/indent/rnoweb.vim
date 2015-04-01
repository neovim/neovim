" Vim indent file
" Language:	Rnoweb
" Author:	Jakson Alves de Aquino <jalvesaq@gmail.com>
" Last Change:	Sun Mar 22, 2015  09:28AM


" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
runtime indent/tex.vim
let s:TeXIndent = function(substitute(&indentexpr, "()", "", ""))
unlet b:did_indent
runtime indent/r.vim
let s:RIndent = function(substitute(&indentexpr, "()", "", ""))
let b:did_indent = 1

setlocal indentkeys=0{,0},!^F,o,O,e,},=\bibitem,=\item
setlocal indentexpr=GetRnowebIndent()

if exists("*GetRnowebIndent")
  finish
endif

function GetRnowebIndent()
  let curline = getline(".")
  if curline =~ '^<<.*>>=$' || curline =~ '^\s*@$'
    return 0
  endif
  if search("^<<", "bncW") > search("^@", "bncW")
    return s:RIndent()
  endif
  return s:TeXIndent()
endfunction

" vim: sw=2
