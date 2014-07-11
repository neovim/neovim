" Vim indent file
" Language:         FrameScript
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2008-07-19

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetFrameScriptIndent()
setlocal indentkeys=!^F,o,O,0=~Else,0=~EndIf,0=~EndLoop,0=~EndSub
setlocal nosmartindent

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
    let ind = ind + &sw
  endif

  if getline(v:lnum) =~? '^\s*\%(Else\|End\%(If\|Loop\|Sub\)\)'
    let ind = ind - &sw
  endif

  return ind
endfunction
