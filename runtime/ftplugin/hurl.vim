" Vim filetype plugin file
" Language:     hurl
" Maintainer:   Melker Ulander <melker.ulander@pm.me>
" Last Changed: 2024 01 26

if exists("b:did_ftplugin") | finish | endif

let b:did_ftplugin = 1
setlocal commentstring=#\ %s

let b:undo_ftplugin = "setlocal commentstring<"
