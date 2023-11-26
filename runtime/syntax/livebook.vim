" Placeholder Livebook syntax file.
" This simply uses the markdown syntax.

if exists("b:current_syntax")
    finish
endif

runtime! syntax/markdown.vim
