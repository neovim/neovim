" Vim indent file
" Language:     ChaiScript
" Maintainer:	Jason Turner <lefticus 'at' gmail com>

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetChaiScriptIndent()
setlocal autoindent

" Only define the function once.
if exists("*GetChaiScriptIndent")
  finish
endif

function! GetChaiScriptIndent()
  " Find a non-blank line above the current line.
  let lnum = prevnonblank(v:lnum - 1)

  " Hit the start of the file, use zero indent.
  if lnum == 0
    return 0
  endif

  " Add a 'shiftwidth' after lines that start a block:
  " lines containing a {
  let ind = indent(lnum)
  let flag = 0
  let prevline = getline(lnum)
  if prevline =~ '^.*{.*'
    let ind = ind + shiftwidth()
    let flag = 1
  endif

  " Subtract a 'shiftwidth' after lines containing a { followed by a }
  " to keep it balanced
  if flag == 1 && prevline =~ '.*{.*}.*'
    let ind = ind - shiftwidth()
  endif

  " Subtract a 'shiftwidth' on lines ending with }
  if getline(v:lnum) =~ '^\s*\%(}\)'
    let ind = ind - shiftwidth()
  endif

  return ind
endfunction
