" Vim indent file
" Language:             asm
" Maintainer:           Philip Jones <philj56@gmail.com>
" Upstream:             https://github.com/philj56/vim-asm-indent
" Latest Revision:      2017-07-01

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=s:getAsmIndent()
setlocal indentkeys=<:>,!^F,o,O

let b:undo_ftplugin .= "indentexpr< indentkeys<"

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
