" Vim indent file
" Language:	Rrst
" Maintainer: This runtime file is looking for a new maintainer.
" Former Maintainer: Jakson Alves de Aquino <jalvesaq@gmail.com>
" Former Repository: https://github.com/jalvesaq/R-Vim-runtime
" Last Change:	2023 Feb 25
"		2024 Feb 19 by Vim Project (announce adoption)


" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
runtime indent/r.vim
let s:RIndent = function(substitute(&indentexpr, "()", "", ""))
let b:did_indent = 1

setlocal indentkeys=0{,0},:,!^F,o,O,e
setlocal indentexpr=GetRrstIndent()

let b:undo_indent = "setl inde< indk<"

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
