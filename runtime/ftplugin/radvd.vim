" Vim filetype plugin file
" Language:	radvd configuration
" Maintainer:	mdspan <mdspan.github@gmail.com>
" Last Change:	2026 Aug 27

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal comments=s1:/*,mb:*,ex:*/,://,:# commentstring=#\ %s

let b:undo_ftplugin = "setl com< cms<"
