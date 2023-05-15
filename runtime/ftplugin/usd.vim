" Vim filetype plugin file
" Language:     Pixar Animation's Universal Scene Description format
" Maintainer:   Colin Kennedy <colinvfx@gmail.com>
" Last Change:  2023 May 9

if exists("b:did_ftplugin")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

let b:did_ftplugin = 1

setlocal commentstring=#\ %s

let &cpo = s:cpo_save
unlet s:cpo_save
