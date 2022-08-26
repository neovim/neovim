" Vim filetype plugin file
" Language:	InstallShield (ft=ishd)
" Maintainer:	Johannes Zellner <johannes@zellner.org>
" Last Change:	Sat, 24 May 2003 11:55:36 CEST

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1

setlocal foldmethod=syntax

" Using line continuation here.
let s:cpo_save = &cpo
set cpo-=C

" matchit support
if exists("loaded_matchit")
    let b:match_ignorecase=0
    let b:match_words=
    \ '\%(^\s*\)\@<=\<function\>\s\+[^()]\+\s*(:\%(^\s*\)\@<=\<begin\>\s*$:\%(^\s*\)\@<=\<return\>:\%(^\s*\)\@<=\<end\>\s*;\s*$,' .
    \ '\%(^\s*\)\@<=\<repeat\>\s*$:\%(^\s*\)\@<=\<until\>\s\+.\{-}\s*;\s*$,' .
    \ '\%(^\s*\)\@<=\<switch\>\s*(.\{-}):\%(^\s*\)\@<=\<\%(case\|default\)\>:\%(^\s*\)\@<=\<endswitch\>\s*;\s*$,' .
    \ '\%(^\s*\)\@<=\<while\>\s*(.\{-}):\%(^\s*\)\@<=\<endwhile\>\s*;\s*$,' .
    \ '\%(^\s*\)\@<=\<for\>.\{-}\<\%(to\|downto\)\>:\%(^\s*\)\@<=\<endfor\>\s*;\s*$,' .
    \ '\%(^\s*\)\@<=\<if\>\s*(.\{-})\s*then:\%(^\s*\)\@<=\<else\s*if\>\s*([^)]*)\s*then:\%(^\s*\)\@<=\<else\>:\%(^\s*\)\@<=\<endif\>\s*;\s*$'
endif

if has("gui_win32") && !exists("b:browsefilter")
    let b:browsefilter = "InstallShield Files (*.rul)\t*.rul\n" .
		       \ "All Files (*.*)\t*.*\n"
endif

let &cpo = s:cpo_save
unlet s:cpo_save
