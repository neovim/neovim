" Vim filetype plugin file
" Language:	LLVM IR
" Last Change:	2024 Oct 22
" Maintainer:	Wu, Zhenyu <wuzhenyu@ustc.edu>

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1

setl comments=:;
setl commentstring=;\ %s

let b:undo_ftplugin = "setl commentstring< comments<"
