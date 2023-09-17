" Vim filetype plugin file
" Language:     Kotlin
" Maintainer:   Alexander Udalov
" URL:          https://github.com/udalov/kotlin-vim
" Last Change:  7 November 2021
"               2023 Sep 17 by Vim Project (browsefilter)

if exists('b:did_ftplugin') | finish | endif
let b:did_ftplugin = 1

let s:save_cpo = &cpo
set cpo&vim

setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,://
setlocal commentstring=//\ %s

setlocal formatoptions-=t formatoptions+=croqnl
silent! setlocal formatoptions+=j

setlocal includeexpr=substitute(v:fname,'\\.','/','g')
setlocal suffixesadd=.kt

let b:undo_ftplugin = "setlocal comments< commentstring< ".
    \ "formatoptions< includeexpr< suffixesadd<"

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Kotlin Source Files (*.kt, *kts)\t*.kt;*.kts\n" .
	\ "All Files (*.*)\t*.*\n"
  let b:undo_ftplugin .= " | unlet! b:browsefilter"
endif

let &cpo = s:save_cpo
unlet s:save_cpo
