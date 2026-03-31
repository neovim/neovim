" Vim filetype plugin file
" Language: i3 config file
" Original Author: Mohamed Boughaba <mohamed dot bgb at gmail dot com>
" Maintainer: Quentin Hibon
" Version: 0.4
" Last Change: 2021 Dec 14

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1

let b:undo_ftplugin = "setlocal cms<"

setlocal commentstring=#\ %s
