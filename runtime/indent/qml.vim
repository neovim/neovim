" Vim indent file
" Language:     QML
" Maintainer:   Chase Knowlden <haroldknowlden@gmail.com>
" Last Change:  2023 Aug 16
"
" Improved JavaScript indent script.

" Indent script in place for this already?
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1
let b:undo_indent = "setlocal indentexpr< indentkeys<"

setlocal indentexpr=s:GetQmlIndent()
setlocal indentkeys=0{,0},0),0],:,!^F,o,O,e,*<Return>,=*/

" Only define functions once per session
if exists("*s:GetQmlIndent")
  finish
endif

" Clean up a line of code by removing trailing '//' and '/* */' comments, and trimming
" whitespace
function! s:Trim(line)
  return substitute(substitute(substitute(a:line, '// .*', '', ''), '/\* .* \*/', '', ''), '^\s*\|\s*$', '', 'g')
endfunction

function! s:GetQmlIndent()
  let num = v:lnum
  let line = s:Trim(getline(num))

  let pnum = prevnonblank(num - 1)
  if pnum == 0
    return 0
  endif
  let pline = s:Trim(getline(pnum))

  let ind = indent(pnum)

  " bracket/brace/paren blocks
  if pline =~ '[{[(]$'
    let ind += &sw
  endif
  if line =~ '^[}\])]'
    let ind -= &sw
  endif

  " '/*' comments
  if pline =~ '^/\*.*\*/'
    " no indent for single-line form
  elseif pline =~ '^/\*'
    let ind += 1
  elseif pline =~ '^\*/'
    let ind -= 1
  endif

  return ind
endfunction
