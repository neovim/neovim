" Vim filetype plugin file
" Language:     Debian autopkgtest control files
" Maintainer:   Debian Vim Maintainers
" Last Change:  2025 Jul 05
" URL:          https://salsa.debian.org/vim-team/vim-debian/blob/main/ftplugin/autopkgtest.vim

" Do these settings once per buffer
if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin=1

setlocal comments=:#
setlocal commentstring=#\ %s

" Clean unloading
let b:undo_ftplugin = 'setlocal comments< commentstring<'
