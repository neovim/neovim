" Logtalk filetype plugin file
" Language:         Logtalk
" Maintainer:       Paulo Moura <pmoura@logtalk.org>
" Latest Revision:  2018-08-03

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let b:undo_ftplugin = "setl ts< sw< fdm< fdc< ai< dict<"

setlocal ts=4
setlocal sw=4
setlocal fdm=syntax
setlocal fdn=10
setlocal fdc=2
setlocal autoindent
setlocal dict=$VIMRUNTIME/ftplugin/logtalk.dict
