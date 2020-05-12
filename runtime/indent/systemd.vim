" Vim indent file
" Language:  systemd.unit(5)

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif

" Looks a lot like dosini files.
runtime! indent/dosini.vim
