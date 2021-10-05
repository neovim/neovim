" Vim indent file
" Language:		FrameScript
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Nikolai Weibull <now@bitwi.se>
" Last Change:		24 Sep 2021

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetFrameScriptIndent()
setlocal indentkeys=!^F,o,O,0=~Else,0=~EndIf,0=~EndLoop,0=~EndSub
setlocal nosmartindent

let b:undo_indent = "setl inde< indk< si<"

if exists("*GetFrameScriptIndent")
  finish
endif

function GetFrameScriptIndent()
  let lnum = prevnonblank(v:lnum - 1)

  if lnum == 0
    return 0
  endif

  if getline(v:lnum) =~ '^\s*\*'
    return cindent(v:lnum)
  endif

  let ind = indent(lnum)

  if getline(lnum) =~? '^\s*\%(If\|Loop\|Sub\)'
    let ind = ind + shiftwidth()
  endif

  if getline(v:lnum) =~? '^\s*\%(Else\|End\%(If\|Loop\|Sub\)\)'
    let ind = ind - shiftwidth()
  endif

  return ind
endfunction
