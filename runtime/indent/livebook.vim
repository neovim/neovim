" Placeholder livebook indent file.
" This simply uses the markdown indenting.

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif

runtime! indent/markdown.vim
