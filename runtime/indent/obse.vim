" Vim indent file
" Language:    Oblivion Language (obl)
" Original Creator: Kat <katisntgood@gmail.com>
" Maintainer:  Kat <katisntgood@gmail.com>
" Created:     01 November 2021
" Last Change: 13 November 2022

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1
let b:undo_indent = 'setlocal indentkeys< indentexpr<'

setlocal indentexpr=GetOblIndent()
setlocal indentkeys+==~endif,=~else,=~loop,=~end

if exists("*GetOblIndent")
  finish
endif
let s:keepcpo = &cpo
set cpo&vim

let s:SKIP_LINES = '^\s*\(;.*\)'
function! GetOblIndent()

  let lnum = prevnonblank(v:lnum - 1)
  let cur_text = getline(v:lnum)
  if lnum == 0
    return 0
  endif
  let prev_text = getline(lnum)
  let found_cont = 0
  let ind = indent(lnum)

  " indent next line on start terms
  let i = match(prev_text, '\c^\s*\(\s\+\)\?\(\(if\|while\|foreach\|begin\|else\%[if]\)\>\)')
  if i >= 0
    let ind += shiftwidth()
    if strpart(prev_text, i, 1) == '|' && has('syntax_items')
          \ && synIDattr(synID(lnum, i, 1), "name") =~ '\(Comment\|String\)$'
      let ind -= shiftwidth()
    endif
  endif
  " indent current line on end/else terms
  if cur_text =~ '\c^\s*\(\s\+\)\?\(\(loop\|endif\|else\%[if]\)\>\)'
    let ind = ind - shiftwidth()
  " if we are at a begin block just go to column 0
  elseif cur_text =~ '\c^\s*\(\s\+\)\?\(\(begin\|end\)\>\)'
    let ind = 0
  endif
  return ind
endfunction

let &cpo = s:keepcpo
unlet s:keepcpo
