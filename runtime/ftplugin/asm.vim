" Vim filetype plugin file
" Language:	asm
" Maintainer:	Colin Caine <cmcaine at the common googlemail domain>
" Last Changed: 23 May 2020

if exists("b:did_ftplugin") | finish | endif

setl comments=:;,s1:/*,mb:*,ex:*/,://
setl commentstring=;%s

let b:did_ftplugin = 1
