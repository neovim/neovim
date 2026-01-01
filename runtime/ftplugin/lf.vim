" Vim filetype plugin file
" Language: lf file manager configuration file (lfrc)
" Maintainer: Andis Sprinkis <andis@sprinkis.com>
" URL: https://github.com/andis-sprinkis/lf-vim
" Last Change: 6 Apr 2025

if exists("b:did_ftplugin") | finish | endif

let b:did_ftplugin = 1

let s:cpo = &cpo
set cpo&vim

let b:undo_ftplugin = "setlocal comments< commentstring< formatoptions<"

setlocal comments=:#
setlocal commentstring=#\ %s

setlocal formatoptions-=t formatoptions+=rol

let &cpo = s:cpo
unlet s:cpo
