" Vim indent file
" Language: Haskell Cabal Build file
" Maintainer: Mateo Gjika <@mateoxh>

if exists('b:did_indent')
  finish
endif

let b:did_indent = 1

setlocal indentexpr=GetCabalIndent()
setlocal indentkeys=!^F,o,O,e,0=elif,<:>

let b:undo_indent = 'setlocal inde< indk<'

let s:save_cpo = &cpo
set cpo&vim

function! GetCabalIndent() abort
  let categories = '\v\c^<(executable|(foreign-)?library|flag|source-repository|test-suite|benchmark|common|custom-setup)>'
  let line = getline(v:lnum)
  let prevline = getline(v:lnum - 1)

  if line =~# categories
    return 0
  endif

  if line =~# '^\s*--'
    return -1
  endif

  if line =~# '^\s*}'
    let [lnum, col] = s:searchpairpos('{','','}','bnW')
    if [lnum, col] == [0, 0]
      return -1
    else
      return indent(lnum)
    endif
  endif

  if line =~# '^\s*||'
    if prevline =~# '^\s*||'
      return indent(v:lnum - 1)
    else
      return indent(v:lnum - 1) + 1
    endif
  endif

  if line =~# '\v^\s*<elif>'
    let [lnum, col] = s:searchpairpos('\v<if>', '', '\v<elif>\zs', 'bnW')
    return col - 1
  elseif line =~# '\v^\s*<else>'
    let [lnum, col] = s:searchpairpos('\v<if>', '\v<elif>', '\v<else>\zs', 'bnW')
    return col - 1
  endif

  if prevline =~# '\v^\s*<(if|elif|else)>'
    return indent(v:lnum - 1) + shiftwidth()
  endif

  if prevline =~# categories
    return indent(v:lnum - 1) + shiftwidth()
  endif

  if empty(prevline) || line =~# '\v^\s*\S+:'
    call cursor(v:lnum, 1)
    let prevCond = search('\v^\s*<(if|elif|else)>', 'bnW', 0, 0,
          \ "synIDattr(synID(line('.'),col('.'),1),'name') =~? 'comment'")
    let prevCat = search(categories, 'bnW', 0, 0,
          \ "synIDattr(synID(line('.'),col('.'),1),'name') =~? 'comment'")
    if prevCond > prevCat
      return indent(v:lnum) > indent(prevCond)
            \ ? indent(prevCond) + shiftwidth()
            \ : indent(prevCond)
    elseif prevCat > 0
      return indent(prevCat) + shiftwidth()
    else
      return 0
    endif
  endif

  if line !~# '\v^\s*(<if>|--)'
    if prevline =~# '\v^\s*\S+:$'
      return indent(v:lnum - 1) + shiftwidth()
    endif
    if prevline =~# '\v^\s*\S+:\s*\S'
      return match(prevline, '\v^\s*\S+:\s*\zs')
    endif
  endif

  return indent(prevnonblank(v:lnum - 1))
endfunction

function! s:searchpairpos(start, middle, end, flags) abort
  return searchpairpos(a:start, a:middle, a:end, a:flags,
        \ "synIDattr(synID(line('.'),col('.'),1),'name') =~? 'comment'")
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
