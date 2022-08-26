" Vim filetype plugin file
" Language:      XS (Perl extension interface language)
" Maintainer:    vim-perl <vim-perl@googlegroups.com>
" Homepage:      https://github.com/vim-perl/vim-perl
" Bugs/requests: https://github.com/vim-perl/vim-perl/issues
" License:       Vim License (see :help license)
" Last Change:   2018 Mar 28

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
    finish
endif

" Just use the C plugin for now.
runtime! ftplugin/c.vim ftplugin/c_*.vim ftplugin/c/*.vim
