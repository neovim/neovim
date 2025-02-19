" Vim indent file
" Language:            C#
" Maintainer:          Nick Jensen <nickspoon@gmail.com>
" Former Maintainers:  Aquila Deus
"                      Johannes Zellner <johannes@zellner.org>
" Last Change:         2020-03-26
" License:             Vim (see :h license)
" Repository:          https://github.com/nickspoons/vim-cs

if exists('b:did_indent')
  finish
endif
let b:did_indent = 1

let s:save_cpo = &cpoptions
set cpoptions&vim


setlocal indentexpr=GetCSIndent(v:lnum)

function! s:IsCompilerDirective(line)
  " Exclude #region and #endregion - these should be indented normally
  return a:line =~# '^\s*#' && !s:IsRegionDirective(a:line)
endf

function! s:IsRegionDirective(line)
  return a:line =~# '^\s*#\s*region' || a:line =~# '^\s*#\s*endregion'
endf

function! s:IsAttributeLine(line)
  return a:line =~# '^\s*\[[A-Za-z]' && a:line =~# '\]$'
endf

function! s:FindPreviousNonCompilerDirectiveLine(start_lnum)
  for delta in range(0, a:start_lnum)
    let lnum = a:start_lnum - delta
    let line = getline(lnum)
    if !s:IsCompilerDirective(line) && !s:IsRegionDirective(line)
      return lnum
    endif
  endfor
  return 0
endf

function! GetCSIndent(lnum) abort
  " Hit the start of the file, use zero indent.
  if a:lnum == 0
    return 0
  endif

  let this_line = getline(a:lnum)

  " Compiler directives use zero indent if so configured.
  let is_first_col_macro = s:IsCompilerDirective(this_line) && stridx(&l:cinkeys, '0#') >= 0
  if is_first_col_macro
    return cindent(a:lnum)
  endif

  let lnum = s:FindPreviousNonCompilerDirectiveLine(a:lnum - 1)
  let previous_code_line = getline(lnum)
  if s:IsAttributeLine(previous_code_line)
    return indent(lnum)
  elseif s:IsRegionDirective(this_line)
    return cindent(lnum)
  else
    return cindent(a:lnum)
  endif
endfunction

let b:undo_indent = 'setlocal indentexpr<'

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
