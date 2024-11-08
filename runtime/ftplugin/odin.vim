" Vim filetype plugin file
" Language: Odin
" Maintainer: Maxim Kim <habamax@gmail.com>
" Website: https://github.com/habamax/vim-odin
" Last Change:	2024 Jan 15
"		2024-May 23 by Riley Bruins <ribru17@gmail.com> ('commentstring')
"
" This file has been manually translated from Vim9 script.

if exists("b:did_ftplugin")
    finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = 'setlocal commentstring<'
      \ .. '| setlocal comments<'
      \ .. '| setlocal suffixesadd<'

setlocal suffixesadd=.odin
setlocal commentstring=//\ %s
setlocal comments=s1:/*,mb:*,ex:*/,://

let &cpo = s:cpo_save
unlet s:cpo_save
