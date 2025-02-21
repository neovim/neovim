" Vim filetype plugin file
" Language:             Configuration File (ini file) for MS-DOS/MS Windows
" Maintainer:           This runtime file is looking for a new maintainer.
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2025 Feb 20

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = "setl com< cms< fo<"

setlocal comments=:;,:# commentstring=;\ %s formatoptions-=t formatoptions+=croql

let &cpo = s:cpo_save
unlet s:cpo_save
