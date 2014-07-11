" Language:      TT2 embedded with HTML
" Maintainer:    vim-perl <vim-perl@googlegroups.com>
" Homepage:      http://github.com/vim-perl/vim-perl
" Bugs/requests: http://github.com/vim-perl/vim-perl/issues
" Last Change:   2013-07-21

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
    finish
endif

" Just use the HTML plugin for now.
runtime! ftplugin/html.vim ftplugin/html_*.vim ftplugin/html/*.vim
