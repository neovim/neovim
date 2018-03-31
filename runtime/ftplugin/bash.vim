" Vim filetype plugin file
" Language: bash
" Maintainer: Mahmoud Al-Qudsi <mqudsi@neosmart.net>
" Last Changed: 1 March 2018

" let b:is_bash=1
" runtime! ftplugin/sh.vim
" runtime! ftplugin/sh_*.vim ftplugin/sh/*.vim
"
if exists("b:did_ftplugin_bash") | finish | endif

let b:is_bash=1
runtime! ftplugin/sh.vim
runtime! ftplugin/sh_*.vim ftplugin/sh/*.vim

autocmd FileType bash set filetype=sh
autocmd Syntax bash set syntax=sh

let b:did_ft_plugin_bash=1
