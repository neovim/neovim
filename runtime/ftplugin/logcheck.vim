" Vim filetype plugin file
" Language:    Logcheck
" Maintainer:  Debian Vim Maintainers
" Last Change: 2023 Jan 16
" License:     Vim License
" URL: https://salsa.debian.org/vim-team/vim-debian/blob/main/ftplugin/logcheck.vim

if exists('b:did_ftplugin')
    finish
endif
let b:did_ftplugin = 1

let b:undo_ftplugin = 'setl fo<'

" Do not hard-wrap non-comment lines since each line is a self-contained
" regular expression
setlocal formatoptions-=t
