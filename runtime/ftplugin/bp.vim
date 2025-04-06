" Blueprint build system filetype plugin file
" Language: Blueprint
" Maintainer: Bruno BELANYI <bruno.vim@belanyi.fr>
" Latest Revision: 2024-04-19

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal comments=b://,s1:/*,mb:*,ex:*/
setlocal commentstring=//\ %s

let b:undo_ftplugin = "setlocal comments< commentstring<"
