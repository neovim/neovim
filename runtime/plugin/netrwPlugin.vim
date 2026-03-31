" Load the netrw package.

if &cp || exists("g:loaded_netrw") || exists("g:loaded_netrwPlugin")
  finish
endif

packadd netrw

" vim:ts=8 sts=2 sw=2 et
