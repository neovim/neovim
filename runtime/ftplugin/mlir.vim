" Vim filetype plugin file
" Language:	MLIR

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1

setl comments=:///,://
setl commentstring=//\ %s

let b:undo_ftplugin = "setl commentstring< comments<"
