" Vim filetype plugin file
" Language:    Logcheck
" Maintainer:  Debian Vim Maintainers <pkg-vim-maintainers@lists.alioth.debian.org>
" Last Change: 2012 Jan 15
" License:     Vim License
" URL: http://hg.debian.org/hg/pkg-vim/vim/file/unstable/runtime/ftplugin/logcheck.vim

if exists("b:did_ftplugin")
    finish
endif
let b:did_ftplugin = 1

let b:undo_ftplugin = "setl fo<"

" Do not hard-wrap non-comment lines since each line is a self-contained
" regular expression
setlocal formatoptions-=t
