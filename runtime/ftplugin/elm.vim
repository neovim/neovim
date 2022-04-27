" Elm filetype plugin file
" Language: Elm
" Maintainer: Andreas Scharf <as@99n.de>
" Latest Revision: 2022-04-25

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal comments=s1fl:{-,mb:\ ,ex:-},:--
setlocal commentstring=--\ %s

let b:undo_ftplugin = "setl com< cms<"

let &cpo = s:cpo_save
unlet s:cpo_save
