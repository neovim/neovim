" PostScript indent file
" Language:	PostScript
" Maintainer:	Mike Williams <mrw@netcomuk.co.uk> (Invalid email address)
" 		Doug Kearns <dougkearns@gmail.com>
" Last Change:	2nd July 2001
"

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=PostscrIndentGet(v:lnum)
setlocal indentkeys+=0],0=>>,0=%%,0=end,0=restore,0=grestore indentkeys-=:,0#,e

" Catch multiple instantiations
if exists("*PostscrIndentGet")
  finish
endif

function! PostscrIndentGet(lnum)
  " Find a non-empty non-comment line above the current line.
  " Note: ignores DSC comments as well!
  let lnum = a:lnum - 1
  while lnum != 0
    let lnum = prevnonblank(lnum)
    if getline(lnum) !~ '^\s*%.*$'
      break
    endif
    let lnum = lnum - 1
  endwhile

  " Hit the start of the file, use user indent.
  if lnum == 0
    return -1
  endif

  " Start with the indent of the previous line
  let ind = indent(lnum)
  let pline = getline(lnum)

  " Indent for dicts, arrays, and saves with possible trailing comment
  if pline =~ '\(begin\|<<\|g\=save\|{\|[\)\s*\(%.*\)\=$'
    let ind = ind + shiftwidth()
  endif

  " Remove indent for popped dicts, and restores.
  if pline =~ '\(end\|g\=restore\)\s*$'
    let ind = ind - shiftwidth()

  " Else handle immediate dedents of dicts, restores, and arrays.
  elseif getline(a:lnum) =~ '\(end\|>>\|g\=restore\|}\|]\)'
    let ind = ind - shiftwidth()

  " Else handle DSC comments - always start of line.
  elseif getline(a:lnum) =~ '^\s*%%'
    let ind = 0
  endif

  " For now catch excessive left indents if they occur.
  if ind < 0
    let ind = -1
  endif

  return ind
endfunction

" vim:sw=2
