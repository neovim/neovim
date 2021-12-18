" Vim indent file
" Language:		Tcl
" Maintainer:		Chris Heithoff <chrisheithoff@gmail.com>
" Previous Maintainer:	Nikolai Weibull <now@bitwi.se>
" Last Change:		24 Sep 2021

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetTclIndent()
setlocal indentkeys=0{,0},!^F,o,O,0]
setlocal nosmartindent

let b:undo_indent = "setl inde< indk< si<"

if exists("*GetTclIndent")
  finish
endif

function s:prevnonblanknoncomment(lnum)
  let lnum = prevnonblank(a:lnum)
  while lnum > 0
    let line = getline(lnum)
    if line !~ '^\s*\(#\|$\)'
      break
    endif
    let lnum = prevnonblank(lnum - 1)
  endwhile
  return lnum
endfunction

function s:ends_with_backslash(lnum)
  let line = getline(a:lnum)
  if line =~ '\\\s*$'
    return 1
  else
    return 0
  endif
endfunction 

function s:count_braces(lnum, count_open)
  let n_open = 0
  let n_close = 0
  let line = getline(a:lnum)
  let pattern = '[{}]'
  let i = match(line, pattern)
  while i != -1
    if synIDattr(synID(a:lnum, i + 1, 0), 'name') !~ 'tcl\%(Comment\|String\)'
      if line[i] == '{'
        let n_open += 1
      elseif line[i] == '}'
        if n_open > 0
          let n_open -= 1
        else
          let n_close += 1
        endif
      endif
    endif
    let i = match(line, pattern, i + 1)
  endwhile
  return a:count_open ? n_open : n_close
endfunction

function GetTclIndent()
  let line = getline(v:lnum)

  " Get the line number of the previous non-blank or non-comment line.
  let pnum = s:prevnonblanknoncomment(v:lnum - 1)
  if pnum == 0
    return 0
  endif

  " ..and the previous line before the previous line.
  let pnum2 = s:prevnonblanknoncomment(pnum-1)

  " Default indentation is to preserve the previous indentation.
  let ind = indent(pnum)
 
  " ...but if previous line introduces an open brace, then increase current line's indentation
  if s:count_braces(pnum, 1) > 0
    let ind += shiftwidth()
  else
    " Look for backslash line continuation on the previous two lines.
    let slash1 = s:ends_with_backslash(pnum)
    let slash2 = s:ends_with_backslash(pnum2)
    if slash1 && !slash2
      " If the previous line begins a line continuation.
      let ind += shiftwidth()
    elseif !slash1 && slash2
      " If two lines ago was the end of a line continuation group of lines.
      let ind -= shiftwidth()
    endif
  endif

  " If the current line begins with a closed brace, then decrease the indentation by one.
  if line =~ '^\s*}'
    let ind -= shiftwidth()
  endif
  
  return ind
endfunction
