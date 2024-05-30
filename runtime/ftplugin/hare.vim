" Vim filetype plugin.
" Language:     Hare
" Maintainer:   Amelia Clarke <selene@perilune.dev>
" Last Updated: 2024-05-10
" Upstream:     https://git.sr.ht/~sircmpwn/hare.vim

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

" Set the default compiler.
compiler hare

" Formatting settings.
setlocal comments=://
setlocal commentstring=//\ %s
setlocal formatlistpat=^\ \\?-\ 
setlocal formatoptions+=croqnlj/ formatoptions-=t

" Search for Hare modules.
setlocal include=^\\s*use\\>
setlocal includeexpr=hare#FindModule(v:fname)
setlocal isfname+=:
setlocal suffixesadd=.ha

" Add HAREPATH to the default search paths.
setlocal path-=/usr/include,,
let &l:path .= ',' .. hare#GetPath() .. ',,'

let b:undo_ftplugin = 'setl cms< com< flp< fo< inc< inex< isf< pa< sua< mp<'

" Follow the Hare style guide by default.
if get(g:, 'hare_recommended_style', 1)
  setlocal noexpandtab
  setlocal shiftwidth=0
  setlocal softtabstop=0
  setlocal tabstop=8
  setlocal textwidth=80
  let b:undo_ftplugin .= ' et< sts< sw< ts< tw<'
endif

augroup hare.vim
  autocmd!

  " Highlight whitespace errors by default.
  if get(g:, 'hare_space_error', 1)
    autocmd InsertEnter * hi link hareSpaceError NONE
    autocmd InsertLeave * hi link hareSpaceError Error
  endif
augroup END

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: et sts=2 sw=2 ts=8
