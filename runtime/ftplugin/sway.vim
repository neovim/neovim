" Vim filetype plugin
" Language:	Sway
" Maintainer:	Riley Bruins <ribru17@gmail.com>
" Last Change:	2024 Nov 01

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setl commentstring=//\ %s
" From Rust comments
setl comments=s0:/*!,ex:*/,s1:/*,mb:*,ex:*/,:///,://!,://

let b:undo_ftplugin = 'setl com< cms<'
