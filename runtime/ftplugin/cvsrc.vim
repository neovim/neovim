" Vim filetype plugin file
" Language:         cvs(1) RC file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2008-07-09

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = "setl com< cms< fo<"

setlocal comments= commentstring= formatoptions-=tcroql

let &cpo = s:cpo_save
unlet s:cpo_save
