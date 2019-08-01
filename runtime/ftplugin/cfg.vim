" Vim filetype plugin file
" Language:		Configuration File
" Maintainer:		Christian Brabandt <cb@256bit.org>
" Latest Revision:	2018-12-24

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = "setl cms< fo<"

setlocal commentstring=#\ %s formatoptions-=t formatoptions+=croql

let &cpo = s:cpo_save
unlet s:cpo_save
