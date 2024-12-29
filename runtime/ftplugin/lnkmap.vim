" Vim filetype plugin file
" Language:	TI Linker map
" Document:	https://downloads.ti.com/docs/esd/SPRUI03A/Content/SPRUI03A_HTML/linker_description.html
" Maintainer:	Wu, Zhenyu <wuzhenyu@ustc.edu>
" Last Change:	2024 Dec 25

if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

let b:undo_ftplugin = "setl iskeyword<"

setl iskeyword+=.
