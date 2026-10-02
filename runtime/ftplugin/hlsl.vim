" Converted from vim9script
" Language:      HLSL (High-Level Shader Language)
" Maintainer:    Maxim Kim <habamax@gmail.com>
" Last Change:   2026 Aug 11

if exists("b:did_ftplugin")
    finish
endif
let b:did_ftplugin = 1

let s:undo_opts = "setl commentstring< comments<"

setlocal commentstring=//\ %s
setlocal comments=

if exists('b:undo_ftplugin')
    let b:undo_ftplugin ..= "|" .. s:undo_opts
else
    let b:undo_ftplugin = s:undo_opts
endif
