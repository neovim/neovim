" Vim indent file
" Language: Apache Thrift
" Maintainer: Yinzuo Jiang <jiangyinzuo@foxmail.com>
" Last Change: 2024/07/29

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal cindent
setlocal indentexpr=GetThriftIndent()

let b:undo_indent = "set cindent< indentexpr<"

" Only define the function once.
if exists("*GetThriftIndent")
  finish
endif

let s:keepcpo= &cpo
set cpo&vim

function! SkipThriftBlanksAndComments(startline)
  let lnum = a:startline
  while lnum > 1
    let lnum = prevnonblank(lnum)
    if getline(lnum) =~ '\*/\s*$'
      while getline(lnum) !~ '/\*' && lnum > 1
        let lnum = lnum - 1
      endwhile
      if getline(lnum) =~ '^\s*/\*'
        let lnum = lnum - 1
      else
        break
      endif
    elseif getline(lnum) =~ '^\s*\(//\|#\)'
      let lnum = lnum - 1
    else
      break
    endif
  endwhile
  return lnum
endfunction

function GetThriftIndent()
  " Thrift is just like C; use the built-in C indenting and then correct a few
  " specific cases.
  let theIndent = cindent(v:lnum)

  " If we're in the middle of a comment then just trust cindent
  if getline(v:lnum) =~ '^\s*\*'
    return theIndent
  endif

  let line = substitute(getline(v:lnum), '\(//\|#\).*$', '', '')
  let previousNum = SkipThriftBlanksAndComments(v:lnum - 1)
  let previous = substitute(getline(previousNum), '\(//\|#\).*$', '', '')

  let l:indent = indent(previousNum)
  if previous =~ "{" && previous !~ "}"
    let l:indent += shiftwidth()
  endif
  if line =~ "}" && line !~ "{"
    let l:indent -= shiftwidth()
  endif
  return l:indent
endfunction

let &cpo = s:keepcpo
unlet s:keepcpo

" vim: sw=2 sts=2 et
