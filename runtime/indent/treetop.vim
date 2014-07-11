" Vim indent file
" Language:         Treetop
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2011-03-14

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetTreetopIndent()
setlocal indentkeys=0{,0},!^F,o,O,=end
setlocal nosmartindent

if exists("*GetTreetopIndent")
  finish
endif

function GetTreetopIndent()
  let pnum = prevnonblank(v:lnum - 1)
  if pnum == 0
    return 0
  endif

  let ind = indent(pnum)
  let line = getline(pnum)

  if line =~ '^\s*\%(grammar\|module\|rule\)\>'
    let ind += &sw
  endif

  let line = getline(v:lnum)
  if line =~ '^\s*end\>'
    let ind -= &sw
  end

  retur ind
endfunction
