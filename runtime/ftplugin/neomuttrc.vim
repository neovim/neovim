" Vim filetype plugin file
" Language:             NeoMutt RC File
" Previous Maintainer:  Guillaume Brogi <gui-gui@netcourrier.com>
" Latest Revision:      2017-09-17
" Original version copied from ftplugin/muttrc.vim

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = "setl com< cms< inc< fo<"

setlocal comments=:# commentstring=#\ %s
setlocal formatoptions-=t formatoptions+=croql

let &l:include = '^\s*source\>'

let &cpo = s:cpo_save
unlet s:cpo_save
