" Vim indent file
" Language:	SDL
" Maintainer:	Michael Piefel <entwurf@piefel.de>
" Last Change:	10 December 2011

" Shamelessly stolen from the Vim-Script indent file

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetSDLIndent()
setlocal indentkeys+==~end,=~state,*<Return>

" Only define the function once.
if exists("*GetSDLIndent")
"  finish
endif

let s:cpo_save = &cpo
set cpo&vim

function! GetSDLIndent()
  " Find a non-blank line above the current line.
  let lnum = prevnonblank(v:lnum - 1)

  " At the start of the file use zero indent.
  if lnum == 0
    return 0
  endif

  let ind = indent(lnum)
  let virtuality = '^\s*\(\(virtual\|redefined\|finalized\)\s\+\)\=\s*'

  " Add a single space to comments which use asterisks
  if getline(lnum) =~ '^\s*\*'
    let ind = ind - 1
  endif
  if getline(v:lnum) =~ '^\s*\*'
    let ind = ind + 1
  endif

  " Add a 'shiftwidth' after states, different blocks, decision (and alternatives), inputs
  if (getline(lnum) =~? '^\s*\(start\|state\|system\|package\|connection\|channel\|alternative\|macro\|operator\|newtype\|select\|substructure\|decision\|generator\|refinement\|service\|method\|exceptionhandler\|asntype\|syntype\|value\|(.*):\|\(priority\s\+\)\=input\|provided\)'
    \ || getline(lnum) =~? virtuality . '\(process\|procedure\|block\|object\)')
    \ && getline(lnum) !~? 'end[[:alpha:]]\+;$'
    let ind = ind + shiftwidth()
  endif

  " Subtract a 'shiftwidth' after states
  if getline(lnum) =~? '^\s*\(stop\|return\>\|nextstate\)'
    let ind = ind - shiftwidth()
  endif

  " Subtract a 'shiftwidth' on on end (uncompleted line)
  if getline(v:lnum) =~? '^\s*end\>'
    let ind = ind - shiftwidth()
  endif

  " Put each alternatives where the corresponding decision was
  if getline(v:lnum) =~? '^\s*\((.*)\|else\):'
    normal k
    let ind = indent(searchpair('^\s*decision', '', '^\s*enddecision', 'bW',
      \ 'synIDattr(synID(line("."), col("."), 0), "name") =~? "sdlString"'))
  endif

  " Put each state where the preceding state was
  if getline(v:lnum) =~? '^\s*state\>'
    let ind = indent(search('^\s*start', 'bW'))
  endif

  " Systems and packages are always in column 0
  if getline(v:lnum) =~? '^\s*\(\(end\)\=system\|\(end\)\=package\)'
    return 0
  endif

  " Put each end* where the corresponding begin was
  if getline(v:lnum) =~? '^\s*end[[:alpha:]]'
    normal k
    let partner=matchstr(getline(v:lnum), '\(' . virtuality . 'end\)\@<=[[:alpha:]]\+')
    let ind = indent(searchpair(virtuality . partner, '', '^\s*end' . partner, 'bW',
      \ 'synIDattr(synID(line("."), col("."), 0), "name") =~? "sdlString"'))
  endif

  return ind
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save

" vim:sw=2
