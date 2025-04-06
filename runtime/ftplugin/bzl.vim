" Vim filetype plugin file
" Language:	Bazel (http://bazel.io)
" Maintainer:	David Barnett (https://github.com/google/vim-ft-bzl)
" Last Change:	2021 Jan 19
" 		2023 Aug 28 by Vim Project (undo_ftplugin)

""
" @section Introduction, intro
" Core settings for the bzl filetype, used for BUILD and *.bzl files for the
" Bazel build system (http://bazel.io/).

if exists('b:did_ftplugin')
  finish
endif


" Vim 7.4.051 has opinionated settings in ftplugin/python.vim that try to force
" PEP8 conventions on every python file, but these conflict with Google's
" indentation guidelines. As a workaround, we explicitly source the system
" ftplugin, but save indentation settings beforehand and restore them after.
let s:save_expandtab = &l:expandtab
let s:save_shiftwidth = &l:shiftwidth
let s:save_softtabstop = &l:softtabstop
let s:save_tabstop = &l:tabstop

" NOTE: Vim versions before 7.3.511 had a ftplugin/python.vim that was broken
" for compatible mode.
let s:save_cpo = &cpo
set cpo&vim

" Load base python ftplugin (also defines b:did_ftplugin).
source $VIMRUNTIME/ftplugin/python.vim

" NOTE: Vim versions before 7.4.104 and later set this in ftplugin/python.vim.
setlocal comments=b:#,fb:-

" Restore pre-existing indentation settings.
let &l:expandtab = s:save_expandtab
let &l:shiftwidth = s:save_shiftwidth
let &l:softtabstop = s:save_softtabstop
let &l:tabstop = s:save_tabstop

setlocal formatoptions-=t

" Initially defined in the python ftplugin sourced above
let b:undo_ftplugin .= " | setlocal fo<"

" Make gf work with imports in BUILD files.
setlocal includeexpr=substitute(v:fname,'//','','')

" Enable syntax-based folding, if specified.
if get(g:, 'ft_bzl_fold', 0)
  setlocal foldmethod=syntax
  setlocal foldtext=BzlFoldText()
  let b:undo_ftplugin .= " | setlocal fdm< fdt<"
endif

if exists('*BzlFoldText')
  let &cpo = s:save_cpo
  unlet s:save_cpo
  finish
endif

function BzlFoldText() abort
  let l:start_num = nextnonblank(v:foldstart)
  let l:end_num = prevnonblank(v:foldend)

  if l:end_num <= l:start_num + 1
    " If the fold is empty, don't print anything for the contents.
    let l:content = ''
  else
    " Otherwise look for something matching the content regex.
    " And if nothing matches, print an ellipsis.
    let l:content = '...'
    for l:line in getline(l:start_num + 1, l:end_num - 1)
      let l:content_match = matchstr(l:line, '\m\C^\s*name = \zs.*\ze,$')
      if !empty(l:content_match)
        let l:content = l:content_match
        break
      endif
    endfor
  endif

  " Enclose content with start and end
  let l:start_text = getline(l:start_num)
  let l:end_text = substitute(getline(l:end_num), '^\s*', '', '')
  let l:text = l:start_text . ' ' . l:content . ' ' . l:end_text

  " Compute the available width for the displayed text.
  let l:width = winwidth(0) - &foldcolumn - (&number ? &numberwidth : 0)
  let l:lines_folded = ' ' . string(1 + v:foldend - v:foldstart) . ' lines'

  " Expand tabs, truncate, pad, and concatenate
  let l:text = substitute(l:text, '\t', repeat(' ', &tabstop), 'g')
  let l:text = strpart(l:text, 0, l:width - len(l:lines_folded))
  let l:padding = repeat(' ', l:width - len(l:lines_folded) - len(l:text))
  return l:text . l:padding . l:lines_folded
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
