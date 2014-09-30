" Vim ftplugin file
" Language:         NSIS script
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2008-07-09

let s:cpo_save = &cpo
set cpo&vim

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let b:undo_ftplugin = "setl com< cms< fo< def< inc<"

setlocal comments=s1:/*,mb:*,ex:*/,b:#,:; commentstring=;\ %s
setlocal formatoptions-=t formatoptions+=croql
setlocal define=^\\s*!define\\%(\\%(utc\\)\\=date\\|math\\)\\=
setlocal include=^\\s*!include\\%(/NONFATAL\\)\\=

let &cpo = s:cpo_save
unlet s:cpo_save
