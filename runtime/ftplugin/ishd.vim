" Vim filetype plugin file
" Language:		InstallShield (ft=ishd)
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Johannes Zellner <johannes@zellner.org>
" Last Change:		2024 Jan 14

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1

" Using line continuation here.
let s:cpo_save = &cpo
set cpo-=C

setlocal foldmethod=syntax

let b:undo_ftplugin = "setl fdm<"

" matchit support
if exists("loaded_matchit")
    let b:match_ignorecase = 0
    let b:match_words =
    \ '\%(^\s*\)\@<=\<function\>\s\+[^()]\+\s*(:\%(^\s*\)\@<=\<begin\>\s*$:\%(^\s*\)\@<=\<return\>:\%(^\s*\)\@<=\<end\>\s*;\s*$,' .
    \ '\%(^\s*\)\@<=\<repeat\>\s*$:\%(^\s*\)\@<=\<until\>\s\+.\{-}\s*;\s*$,' .
    \ '\%(^\s*\)\@<=\<switch\>\s*(.\{-}):\%(^\s*\)\@<=\<\%(case\|default\)\>:\%(^\s*\)\@<=\<endswitch\>\s*;\s*$,' .
    \ '\%(^\s*\)\@<=\<while\>\s*(.\{-}):\%(^\s*\)\@<=\<endwhile\>\s*;\s*$,' .
    \ '\%(^\s*\)\@<=\<for\>.\{-}\<\%(to\|downto\)\>:\%(^\s*\)\@<=\<endfor\>\s*;\s*$,' .
    \ '\%(^\s*\)\@<=\<if\>\s*(.\{-})\s*then:\%(^\s*\)\@<=\<else\s*if\>\s*([^)]*)\s*then:\%(^\s*\)\@<=\<else\>:\%(^\s*\)\@<=\<endif\>\s*;\s*$'
    let b:undo_ftplugin .= " | unlet! b:match_ignorecase b:match_words"
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
    let b:browsefilter = "InstallShield Files (*.rul)\t*.rul\n"
    if has("win32")
	let b:browsefilter .= "All Files (*.*)\t*\n"
    else
	let b:browsefilter .= "All Files (*)\t*\n"
    endif
    let b:undo_ftplugin .= " | unlet! b:browsefilter"
endif

let &cpo = s:cpo_save
unlet s:cpo_save
