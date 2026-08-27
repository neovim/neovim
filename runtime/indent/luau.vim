" Vim indent file
" Language:     Luau
" Maintainer:   Lopy (@lopi-py)
" Last Change:  2026 Jun 17

" only load this indent file when no other was loaded
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal indentexpr=GetLuauIndent()

" make Vim call GetLuauIndent() when it finds a closing keyword or delimiter
setlocal indentkeys+=0=end,0=until,0=else,0=elseif,0=},0=),0=]

setlocal autoindent

let b:undo_indent = "setlocal autoindent< indentexpr< indentkeys<"

" only define the function once
if exists("*GetLuauIndent")
  let &cpo = s:cpo_save
  unlet s:cpo_save
  finish
endif

function GetLuauIndent() abort
  let ignorecase_save = &ignorecase
  try
    let &ignorecase = 0
    return s:GetLuauIndentIntern()
  finally
    let &ignorecase = ignorecase_save
  endtry
endfunction

function s:InDeclareClass(lnum) abort
  let save_cursor = getcurpos()
  call cursor(a:lnum - 1, 1)
  let lnum = search('^\s*\%(end\>\|declare\s\+class\>\)', 'bcnW')
  call setpos('.', save_cursor)
  return lnum > 0 && getline(lnum) =~# '^\s*declare\s\+class\>'
endfunction

function s:IsStringOrComment(lnum, col) abort
  let name = synIDattr(synID(a:lnum, a:col, 1), "name")
  return name =~# '^luau\%(Comment\|.*String\)'
endfunction

function s:LineCommentStart(lnum) abort
  let line = getline(a:lnum)
  let midx = stridx(line, '--')
  while midx != -1
    if !s:IsStringOrComment(a:lnum, midx + 1)
      return midx
    endif
    let midx = stridx(line, '--', midx + 2)
  endwhile
  return -1
endfunction

function s:IsCode(lnum, col) abort
  let comment = s:LineCommentStart(a:lnum)
  return (comment == -1 || a:col <= comment) && !s:IsStringOrComment(a:lnum, a:col)
endfunction

function s:HasBlockCloser(lnum) abort
  let line = getline(a:lnum)
  let midx = match(line, '\<\%(end\|until\)\>')
  while midx != -1
    if s:IsCode(a:lnum, midx + 1)
      return 1
    endif
    let midx = match(line, '\<\%(end\|until\)\>', midx + 1)
  endwhile
  return 0
endfunction

function s:GetLuauIndentIntern() abort
  " find a non-blank line above the current line
  let prevlnum = prevnonblank(v:lnum - 1)

  " hit the start of the file, use zero indent
  if prevlnum == 0
    return 0
  endif

  " add a 'shiftwidth' after lines that start a block
  let ind = indent(prevlnum)
  let prevline = getline(prevlnum)
  let attr = '@\%(\h\w*\|\[[^]]*\]\)\s*'
  let stmt = 'if\>\|for\>\|while\>\|repeat\>\|else\>\|elseif\>\|do\>\|then\>'
  let class = 'class\>\s\+\h\|declare\s\+class\>\s\+\h'
  let func = '\%(\%(public\s\+\)\=function\|local\s\+function\|const\s\+function\|type\s\+function\|return\s\+function\)'
  let declare_func = '^\s*\%(' .. attr .. '\)*declare\s\+function\>'
  let midx = -1
  if prevline =~# '^\s*\%(@\|\%(if\|for\|while\|repeat\|else\|elseif\|do\|then\|class\)\>\|declare\s\+class\>\)'
    let midx = match(prevline, '^\s*\%(' .. attr .. '\)*\%(' .. stmt .. '\|' .. class .. '\)')
  endif
  if midx == -1
    if prevline =~# '^\s*\%(' .. attr .. '\)*declare\s\+extern\s\+type\>'
      let midx = match(prevline, '\<with\>\s*\%(--.*\)\=$')
    endif
    if midx == -1
      let midx = match(prevline, '\%({\|(\|\[\)\s*\%(--\%([^[].*\)\?\)\?$')
      if midx == -1 && stridx(prevline, 'function') != -1 && prevline !~# declare_func
        let midx = match(prevline, '\<' .. func .. '\>\s*\%(\k\|[.:]\)\{-}\s*\%(<[^>]*>\s*\)\=(')
      endif
    endif
  endif

  if midx == -1 && prevline =~ '^\s*)\s*\%(:.\+\)\=\s*\%(--.*\)\=$'
    let save_cursor = getcurpos()
    call cursor(prevlnum, match(prevline, ')') + 1)
    let [par_lnum, par_col] = searchpairpos('(', '', ')', 'bnW')
    call setpos('.', save_cursor)
    if par_lnum > 0
      let funline = getline(par_lnum)
      let funidx = match(funline, '\<' .. func .. '\>')
      if funidx != -1 && funidx < par_col && funline !~# declare_func
        let midx = match(prevline, ')')
      endif
    endif
  endif

  if midx != -1
    " add 'shiftwidth' if this is not in a comment or string and the block
    " does not close on the same line
    if s:IsCode(prevlnum, midx + 1) && !s:HasBlockCloser(prevlnum)
          \ && !(prevline =~# '^\s*\%(public\s\+\)\=function\>' && s:InDeclareClass(prevlnum))
      let ind = ind + shiftwidth()
    endif
  endif

  " subtract a 'shiftwidth' on end, else, elseif, until, '}', ')' and ']'
  let midx = match(getline(v:lnum), '^\s*\%(end\>\|else\>\|elseif\>\|until\>\|}\|)\|\]\)')
  if midx != -1
    if s:IsCode(v:lnum, midx + 1)
      let ind = ind - shiftwidth()
    endif
  endif

  return ind
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet:
