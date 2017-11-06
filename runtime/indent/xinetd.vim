" Vim indent file
" Language:             xinetd.conf(5) configuration file
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2006-12-20

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetXinetdIndent()
setlocal indentkeys=0{,0},!^F,o,O
setlocal nosmartindent

if exists("*GetXinetdIndent")
  finish
endif
let s:keepcpo= &cpo
set cpo&vim

function s:count_braces(lnum, count_open)
  let n_open = 0
  let n_close = 0
  let line = getline(a:lnum)
  let pattern = '[{}]'
  let i = match(line, pattern)
  while i != -1
    if synIDattr(synID(a:lnum, i + 1, 0), 'name') !~ 'ld\%(Comment\|String\)'
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

function GetXinetdIndent()
  let pnum = prevnonblank(v:lnum - 1)
  if pnum == 0
    return 0
  endif

  return indent(pnum) + s:count_braces(pnum, 1) * shiftwidth()
        \ - s:count_braces(v:lnum, 0) * shiftwidth()
endfunction

let &cpo = s:keepcpo
unlet s:keepcpo
