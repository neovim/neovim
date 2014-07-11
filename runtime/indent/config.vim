" Vim indent file
" Language:         Autoconf configure.{ac,in} file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-12-20
" TODO:             how about nested [()]'s in one line
"                   what's wrong with '\\\@!'?

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif

runtime! indent/sh.vim          " will set b:did_indent

setlocal indentexpr=GetConfigIndent()
setlocal indentkeys=!^F,o,O,=then,=do,=else,=elif,=esac,=fi,=fin,=fil,=done
setlocal nosmartindent

" Only define the function once.
if exists("*GetConfigIndent")
  finish
endif

" get the offset (indent) of the end of the match of 'regexp' in 'line'
function s:GetOffsetOf(line, regexp)
  let end = matchend(a:line, a:regexp)
  let width = 0
  let i = 0
  while i < end
    if a:line[i] != "\t"
      let width = width + 1
    else
      let width = width + &ts - (width % &ts)
    endif
    let i = i + 1
  endwhile
  return width
endfunction

function GetConfigIndent()
  " Find a non-blank line above the current line.
  let lnum = prevnonblank(v:lnum - 1)

  " Hit the start of the file, use zero indent.
  if lnum == 0
    return 0
  endif

  " where to put this
  let ind = GetShIndent()
  let line = getline(lnum)

  " if previous line has unmatched, unescaped opening parentheses,
  " indent to its position. TODO: not failsafe if multiple ('s
  if line =~ '\\\@<!([^)]*$'
    let ind = s:GetOffsetOf(line, '\\\@!(')
  endif

  " if previous line has unmatched opening bracket,
  " indent to its position. TODO: same as above
  if line =~ '\[[^]]*$'
    let ind = s:GetOffsetOf(line, '\[')
  endif

  " if previous line had an unmatched closing parantheses,
  " indent to the matching opening parantheses
  if line =~ '[^(]\+\\\@<!)$'
    call search(')', 'bW')
    let lnum = searchpair('\\\@<!(', '', ')', 'bWn')
    let ind = indent(lnum)
  endif

  " if previous line had an unmatched closing bracket,
  " indent to the matching opening bracket
  if line =~ '[^[]\+]$'
    call search(']', 'bW')
    let lnum = searchpair('\[', '', ']', 'bWn')
    let ind = indent(lnum)
  endif

  return ind
endfunction
