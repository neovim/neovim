" Vim filetype plugin.
" Language:     Haredoc (Hare documentation format)
" Maintainer:   Amelia Clarke <selene@perilune.dev>
" Last Updated: 2024-05-02
" Upstream:     https://git.sr.ht/~selene/hare.vim

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

" Formatting settings.
setlocal comments=:\	
setlocal formatlistpat=^\ \\?-\ 
setlocal formatoptions+=tnlj formatoptions-=c formatoptions-=q

" Search for Hare modules.
setlocal includeexpr=hare#FindModule(v:fname)
setlocal isfname+=:
setlocal suffixesadd=.ha

" Add HAREPATH to the default search paths.
setlocal path-=/usr/include,,
let &l:path .= ',' .. hare#GetPath() .. ',,'

let b:undo_ftplugin = 'setl com< flp< fo< inex< isf< pa< sua<'

" Follow the Hare style guide by default.
if get(g:, 'hare_recommended_style', 1)
  setlocal noexpandtab
  setlocal shiftwidth=0
  setlocal softtabstop=0
  setlocal tabstop=8
  setlocal textwidth=80
  let b:undo_ftplugin .= ' et< sts< sw< ts< tw<'
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: et sts=2 sw=2 ts=8
