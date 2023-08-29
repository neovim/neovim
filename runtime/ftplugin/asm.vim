" Vim filetype plugin file
" Language:	asm
" Maintainer:	Colin Caine <cmcaine at the common googlemail domain>
" Last Change:  23 May 2020
" 		2023 Aug 28 by Vim Project (undo_ftplugin)

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1

setl comments=:;,s1:/*,mb:*,ex:*/,://
setl commentstring=;%s

let b:undo_ftplugin = "setl commentstring< comments<"
