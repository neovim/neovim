" Vim filetype plugin file
" Language:	OpenCL
" Maintainer:	Wu, Zhenyu <wuzhenyu@ustc.edu>
" Last Change:	2024 Nov 19

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1

setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,:///,://
setlocal commentstring=/*\ %s\ */ define& include&

let b:undo_ftplugin = "setl commentstring< comments<"
