" Vim indent file
" Language:	Rnoweb
" Author:	Jakson Alves de Aquino <jalvesaq@gmail.com>
" Homepage:     https://github.com/jalvesaq/R-Vim-runtime
" Last Change:	Mon Feb 27, 2023  07:17PM


" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
runtime indent/tex.vim

function s:NoTeXIndent()
  return indent(line("."))
endfunction

if &indentexpr == "" || &indentexpr == "GetRnowebIndent()"
  let s:TeXIndent = function("s:NoTeXIndent")
else
  let s:TeXIndent = function(substitute(&indentexpr, "()", "", ""))
endif

unlet! b:did_indent
runtime indent/r.vim
let s:RIndent = function(substitute(&indentexpr, "()", "", ""))
let b:did_indent = 1

setlocal indentkeys=0{,0},!^F,o,O,e,},=\bibitem,=\item
setlocal indentexpr=GetRnowebIndent()

let b:undo_indent = "setl inde< indk<"

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
