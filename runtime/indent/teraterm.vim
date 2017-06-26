" Vim indent file
" Language:	Tera Term Language (TTL)
"		Based on Tera Term Version 4.92
" Maintainer:	Ken Takata
" URL:		https://github.com/k-takata/vim-teraterm
" Last Change:	2016 Aug 17
" Filenames:	*.ttl
" License:	VIM License

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal nosmartindent
setlocal noautoindent
setlocal indentexpr=GetTeraTermIndent(v:lnum)
setlocal indentkeys=!^F,o,O,e
setlocal indentkeys+==elseif,=endif,=loop,=next,=enduntil,=endwhile

if exists("*GetTeraTermIndent")
  finish
endif

" The shiftwidth() function is relatively new.
" Don't require it to exist.
if exists('*shiftwidth')
  let s:sw = function('shiftwidth')
else
  function s:sw() abort
    return &shiftwidth
  endfunction
endif

function! GetTeraTermIndent(lnum)
  let l:prevlnum = prevnonblank(a:lnum-1)
  if l:prevlnum == 0
    " top of file
    return 0
  endif

  " grab the previous and current line, stripping comments.
  let l:prevl = substitute(getline(l:prevlnum), ';.*$', '', '')
  let l:thisl = substitute(getline(a:lnum), ';.*$', '', '')
  let l:previ = indent(l:prevlnum)

  let l:ind = l:previ

  if l:prevl =~ '^\s*if\>.*\<then\>'
    " previous line opened a block
    let l:ind += s:sw()
  endif
  if l:prevl =~ '^\s*\%(elseif\|else\|do\|until\|while\|for\)\>'
    " previous line opened a block
    let l:ind += s:sw()
  endif
  if l:thisl =~ '^\s*\%(elseif\|else\|endif\|enduntil\|endwhile\|loop\|next\)\>'
    " this line closed a block
    let l:ind -= s:sw()
  endif

  return l:ind
endfunction

" vim: ts=8 sw=2 sts=2
