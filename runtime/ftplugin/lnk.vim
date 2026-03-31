" Vim filetype plugin file
" Language:	TI linker command file
" Document:	https://software-dl.ti.com/ccs/esd/documents/sdto_cgt_Linker-Command-File-Primer.html
" Maintainer:	Wu, Zhenyu <wuzhenyu@ustc.edu>
" Last Change:	2024 Dec 31

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1

setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,:///,://
setlocal commentstring=/*\ %s\ */
setlocal iskeyword+=.

let b:undo_ftplugin = "setl commentstring< comments< iskeyword<"
