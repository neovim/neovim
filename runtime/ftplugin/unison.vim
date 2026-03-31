" Vim filetype plugin file
" Language:             unison
" Maintainer:           Anton Parkhomenko <anton@chuwy.me>
" Latest Revision:      2023-08-07

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let b:undo_ftplugin = "setl cms< isk<"

setlocal commentstring=--\ %s
setlocal iskeyword+=!,'
