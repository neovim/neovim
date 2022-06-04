" Vim indent file
" Language: confini

" Quit if an indent file was already loaded.
if exists("b:did_indent")
  finish
endif

" Use the cfg indenting, it's similar enough.
runtime! indent/cfg.vim
