" Vim indent file
" Language:	Sass
" Maintainer:	Tim Pope <vimNOSPAM@tpope.org>
" Last Change:	2023 Dec 28

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal autoindent
setlocal indentexpr=GetSassIndent()
setlocal indentkeys=o,O,*<Return>,<:>,!^F

let b:undo_indent = "setl ai< inde< indk<"

" Only define the function once.
if exists("*GetSassIndent")
  finish
endif

let s:property = '^\s*:\|^\s*[[:alnum:]#{}-]\+\%(:\|\s*=\)'
let s:extend = '^\s*\%(@extend\|@include\|+\)'

function! GetSassIndent()
  let lnum = prevnonblank(v:lnum-1)
  let line = substitute(getline(lnum),'\s\+$','','')
  let cline = substitute(substitute(getline(v:lnum),'\s\+$','',''),'^\s\+','','')
  let line = substitute(line,'^\s\+','','')
  let indent = indent(lnum)
  if line !~ s:property && line !~ s:extend && cline =~ s:property
    return indent + shiftwidth()
  else
    return -1
  endif
endfunction

" vim:set sw=2:
