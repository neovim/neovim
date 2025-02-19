" Vim filetype plugin file
" Language:	Go
" Maintainer:	David Barnett (https://github.com/google/vim-ft-go)
" Last Change:	2014 Aug 16
" 2024 Jul 16 by Vim Project (add recommended indent style)

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal formatoptions-=t

setlocal comments=s1:/*,mb:*,ex:*/,://
setlocal commentstring=//\ %s

let b:undo_ftplugin = 'setl fo< com< cms<'

if get(g:, 'go_recommended_style', 1)
  setlocal noexpandtab softtabstop=0 shiftwidth=0
  let b:undo_ftplugin ..= ' | setl et< sts< sw<'
endif

" vim: sw=2 sts=2 et
