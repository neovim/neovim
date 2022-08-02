" Vim indent file
" Language:	MSDOS batch file (with NT command extensions)
" Maintainer:	Ken Takata
" URL:		https://github.com/k-takata/vim-dosbatch-indent
" Last Change:	2021-10-18
" Filenames:	*.bat
" License:	VIM License

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal nosmartindent
setlocal noautoindent
setlocal indentexpr=GetDosBatchIndent(v:lnum)
setlocal indentkeys=!^F,o,O
setlocal indentkeys+=0=)

let b:undo_indent = "setl ai< inde< indk< si<"

if exists("*GetDosBatchIndent")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

function! GetDosBatchIndent(lnum)
  let l:prevlnum = prevnonblank(a:lnum-1)
  if l:prevlnum == 0
    " top of file
    return 0
  endif

  " grab the previous and current line, stripping comments.
  let l:prevl = substitute(getline(l:prevlnum), '\c^\s*\%(@\s*\)\?rem\>.*$', '', '')
  let l:thisl = getline(a:lnum)
  let l:previ = indent(l:prevlnum)

  let l:ind = l:previ

  if l:prevl =~? '^\s*@\=if\>.*(\s*$' ||
        \ l:prevl =~? '\<do\>\s*(\s*$' ||
        \ l:prevl =~? '\<else\>\s*\%(if\>.*\)\?(\s*$' ||
        \ l:prevl =~? '^.*\(&&\|||\)\s*(\s*$'
    " previous line opened a block
    let l:ind += shiftwidth()
  endif
  if l:thisl =~ '^\s*)'
    " this line closed a block
    let l:ind -= shiftwidth()
  endif

  return l:ind
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8 sw=2 sts=2
