" Vim indent file
" Language:	Sass
" Maintainer:	Tim Pope <vimNOSPAM@tpope.org>
" Last Change:	2017 Jun 13

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal autoindent sw=2 et
setlocal indentexpr=GetSassIndent()
setlocal indentkeys=o,O,*<Return>,<:>,!^F

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
  let lastcol = strlen(line)
  let line = substitute(line,'^\s\+','','')
  let indent = indent(lnum)
  let cindent = indent(v:lnum)
  if line !~ s:property && line !~ s:extend && cline =~ s:property
    return indent + shiftwidth()
  else
    return -1
  endif
endfunction

" vim:set sw=2:
