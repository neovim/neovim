" Vim indent file
" Language:	asm
" Maintainer:	Philip Jones <philj56@gmail.com>
" Upstream:	https://github.com/philj56/vim-asm-indent
" Last Change:	2017-Jul-01
"		2024 Apr 25 by Vim Project (undo_indent)

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=s:getAsmIndent()
setlocal indentkeys=<:>,!^F,o,O

let b:undo_indent = "setlocal indentexpr< indentkeys<"

function! s:getAsmIndent()
  let line = getline(v:lnum)
  let ind = shiftwidth()

  " If the line is a label (starts with ':' terminated keyword), 
  " then don't indent
  if line =~ '^\s*\k\+:'
    let ind = 0
  endif

  return ind
endfunction
