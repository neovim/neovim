" Vim indent file
" Language:         Eterm configuration file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-12-20

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetEtermIndent()
setlocal indentkeys=!^F,o,O,=end
setlocal nosmartindent

if exists("*GetEtermIndent")
  finish
endif

function GetEtermIndent()
  let lnum = prevnonblank(v:lnum - 1)
  if lnum == 0
    return 0
  endif

  let ind = indent(lnum)

  if getline(lnum) =~ '^\s*begin\>'
    let ind = ind + &sw
  endif

  if getline(v:lnum) =~ '^\s*end\>'
    let ind = ind - &sw
  endif

  return ind
endfunction
