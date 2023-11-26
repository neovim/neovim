" Vim filetype plugin file
" Language:             MS Windows URL shortcut file
" Maintainer:           ObserverOfTime <chronobserver@disroot.org>
" Latest Revision:      2023-06-04

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpoptions
set cpoptions&vim

let b:undo_ftplugin = "setl com< cms< fo<"

setlocal comments=:; commentstring=;\ %s
setlocal formatoptions-=t formatoptions+=croql

let &cpoptions = s:cpo_save
unlet s:cpo_save
