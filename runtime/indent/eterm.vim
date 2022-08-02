" Vim indent file
" Language:		Eterm configuration file
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Nikolai Weibull <now@bitwi.se>
" Last Change:		24 Sep 2021

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetEtermIndent()
setlocal indentkeys=!^F,o,O,=end
setlocal nosmartindent

let b:undo_indent = "setl inde< indk< si<"

if exists("*GetEtermIndent")
  finish
endif

function GetEtermIndent()
  let lnum = prevnonblank(v:lnum - 1)
  if lnum == 0
    return 0
  endif

  let ind = indent(lnum)

  if getline(lnum) =~ '^\s*begin\>'
    let ind = ind + shiftwidth()
  endif

  if getline(v:lnum) =~ '^\s*end\>'
    let ind = ind - shiftwidth()
  endif

  return ind
endfunction
