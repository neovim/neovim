" Load the netrw package.

if !has("patch-9.1.1054") || !has('nvim')
  echoerr 'netrw needs vim v9.1.1054'
  finish
endif

if &cp || exists("g:loaded_netrw") || exists("g:loaded_netrwPlugin")
  finish
endif

packadd netrw

" vim:ts=8 sts=2 sw=2 et
