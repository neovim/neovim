" Vim filetype plugin file
" Language:     Git revision list
" Author:       Fionn Fitzmaurice (github.com/fionn)
" Maintainer:   Fionn Fitzmaurice (github.com/fionn)
" License:      Vim & Apache 2.0

if exists("b:did_ftplugin")
    finish
endif
let b:did_ftplugin = 1

setlocal comments=:#
setlocal commentstring=#\ %s
setlocal keywordprg=git\ show

let b:undo_ftplugin = "setl comments< commentstring< keywordprg<"
