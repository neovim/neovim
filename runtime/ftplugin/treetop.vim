" Vim filetype plugin file
" Language:         Treetop
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2011-03-14

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal comments=b:# commentstring=#\ %s formatoptions-=tcroq formatoptions+=l

let b:undo_ftplugin = "setl com< cms< fo<"

let &cpo = s:cpo_save
unlet s:cpo_save
