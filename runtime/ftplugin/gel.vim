" Vim filetype plugin file
" Language:	TI Code Composer Studio General Extension Language
" Document:	https://downloads.ti.com/ccs/esd/documents/users_guide/ccs_debug-gel.html
" Maintainer:	Wu, Zhenyu <wuzhenyu@ustc.edu>
" Last Change:	2024 Dec 25

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1

setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,:///,://
setlocal commentstring=/*\ %s\ */

let b:undo_ftplugin = "setl commentstring< comments<"
