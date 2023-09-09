" Vim indent file
" Language: nginx.conf
" Maintainer: Chris Aumann <me@chr4.org>
" Last Change:  2022 Dec 01

" Only load this indent file when no other was loaded.
if exists('b:did_indent')
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetNginxIndent()

setlocal indentkeys=0{,0},0#,!^F,o,O

let b:undo_indent = 'setl inde< indk<'

" Only define the function once.
if exists('*GetNginxIndent')
  finish
endif

function GetNginxIndent() abort
  let plnum = s:PrevNotAsBlank(v:lnum - 1)

  " Hit the start of the file, use zero indent.
  if plnum == 0
    return 0
  endif

  let ind = indent(plnum)

  " Add a 'shiftwidth' after '{'
  if s:AsEndWith(getline(plnum), '{')
    let ind = ind + shiftwidth()
  end

  " Subtract a 'shiftwidth' on '}'
  " This is the part that requires 'indentkeys'.
  if getline(v:lnum) =~ '^\s*}'
    let ind = ind - shiftwidth()
  endif

  let pplnum = s:PrevNotAsBlank(plnum - 1)

  if s:IsLineContinuation(plnum)
    if !s:IsLineContinuation(pplnum)
      let ind = ind + shiftwidth()
    end
  else
    if s:IsLineContinuation(pplnum)
      let ind = ind - shiftwidth()
    end
  endif

  return ind
endfunction

" Find the first line at or above {lnum} that is non-blank and not a comment.
function s:PrevNotAsBlank(lnum) abort
  let lnum = prevnonblank(a:lnum)
  while lnum > 0
    if getline(lnum) !~ '^\s*#'
      break
    endif
    let lnum = prevnonblank(lnum - 1)
  endwhile
  return lnum
endfunction

" Check whether {line} ends with {pat}, ignoring trailing comments.
function s:AsEndWith(line, pat) abort
  return a:line =~ a:pat . '\m\s*\%(#.*\)\?$'
endfunction

function s:IsLineContinuation(lnum) abort
  return a:lnum > 0 && !s:AsEndWith(getline(a:lnum), '[;{}]')
endfunction
