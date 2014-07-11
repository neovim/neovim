" Language:      TT2 embedded with HTML
" Maintainer:    vim-perl <vim-perl@googlegroups.com>
" Author:        Moriki, Atsushi <4woods+vim@gmail.com>
" Homepage:      http://github.com/vim-perl/vim-perl
" Bugs/requests: http://github.com/vim-perl/vim-perl/issues
" Last Change:   2013-07-21

if exists("b:current_syntax")
    finish
endif

runtime! syntax/html.vim
unlet b:current_syntax

runtime! syntax/tt2.vim
unlet b:current_syntax

syn cluster htmlPreProc add=@tt2_top_cluster

let b:current_syntax = "tt2html"
