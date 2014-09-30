" Vim indent file
" Language:	Rrst
" Author:	Jakson Alves de Aquino <jalvesaq@gmail.com>
" Last Change:	Wed Jul 09, 2014  07:33PM


" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
runtime indent/r.vim
let s:RIndent = function(substitute(&indentexpr, "()", "", ""))
let b:did_indent = 1

setlocal indentkeys=0{,0},:,!^F,o,O,e
setlocal indentexpr=GetRrstIndent()

if exists("*GetRrstIndent")
  finish
endif

function GetRstIndent()
  let pline = getline(v:lnum - 1)
  let cline = getline(v:lnum)
  if prevnonblank(v:lnum - 1) < v:lnum - 1 || cline =~ '^\s*[-\+\*]\s' || cline =~ '^\s*\d\+\.\s\+'
    return indent(v:lnum)
  elseif pline =~ '^\s*[-\+\*]\s'
    return indent(v:lnum - 1) + 2
  elseif pline =~ '^\s*\d\+\.\s\+'
    return indent(v:lnum - 1) + 3
  endif
  return indent(prevnonblank(v:lnum - 1))
endfunction

function GetRrstIndent()
  if getline(".") =~ '^\.\. {r .*}$' || getline(".") =~ '^\.\. \.\.$'
    return 0
  endif
  if search('^\.\. {r', "bncW") > search('^\.\. \.\.$', "bncW")
    return s:RIndent()
  else
    return GetRstIndent()
  endif
endfunction

" vim: sw=2
