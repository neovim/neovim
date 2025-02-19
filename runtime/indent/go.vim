" Vim indent file
" Language:	Go
" Maintainer:	David Barnett (https://github.com/google/vim-ft-go)
" Last Change:	2017 Jun 13
"		2023 Aug 28 by Vim Project (undo_indent)
"
" TODO:
" - function invocations split across lines
" - general line splits (line ends in an operator)

if exists('b:did_indent')
  finish
endif
let b:did_indent = 1

" C indentation is too far off useful, mainly due to Go's := operator.
" Let's just define our own.
setlocal nolisp
setlocal autoindent
setlocal indentexpr=GoIndent(v:lnum)
setlocal indentkeys+=<:>,0=},0=)

let b:undo_indent = "setl ai< inde< indk< lisp<"

if exists('*GoIndent')
  finish
endif

function! GoIndent(lnum)
  let l:prevlnum = prevnonblank(a:lnum-1)
  if l:prevlnum == 0
    " top of file
    return 0
  endif

  " grab the previous and current line, stripping comments.
  let l:prevl = substitute(getline(l:prevlnum), '//.*$', '', '')
  let l:thisl = substitute(getline(a:lnum), '//.*$', '', '')
  let l:previ = indent(l:prevlnum)

  let l:ind = l:previ

  if l:prevl =~ '[({]\s*$'
    " previous line opened a block
    let l:ind += shiftwidth()
  endif
  if l:prevl =~# '^\s*\(case .*\|default\):$'
    " previous line is part of a switch statement
    let l:ind += shiftwidth()
  endif
  " TODO: handle if the previous line is a label.

  if l:thisl =~ '^\s*[)}]'
    " this line closed a block
    let l:ind -= shiftwidth()
  endif

  " Colons are tricky.
  " We want to outdent if it's part of a switch ("case foo:" or "default:").
  " We ignore trying to deal with jump labels because (a) they're rare, and
  " (b) they're hard to disambiguate from a composite literal key.
  if l:thisl =~# '^\s*\(case .*\|default\):$'
    let l:ind -= shiftwidth()
  endif

  return l:ind
endfunction

" vim: sw=2 sts=2 et
