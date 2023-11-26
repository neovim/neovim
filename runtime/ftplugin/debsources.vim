" Language:     Debian sources.list
" Maintainer:   Debian Vim Maintainers <team+vim@tracker.debian.org>
" Last Change:  2023 Aug 30
" License:      Vim License
" URL:          https://salsa.debian.org/vim-team/vim-debian/blob/main/ftplugin/debsources.vim

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin=1

setlocal comments=:#
setlocal commentstring=#%s
setlocal formatoptions-=t

let b:undo_ftplugin = 'setlocal comments< commentstring< formatoptions<'
