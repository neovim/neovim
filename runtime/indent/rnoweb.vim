" Vim indent file
" Language:	Rnoweb
" Author:	Jakson Alves de Aquino <jalvesaq@gmail.com>
" Homepage:     https://github.com/jalvesaq/R-Vim-runtime
" Last Change:	Tue Apr 07, 2015  04:38PM


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
