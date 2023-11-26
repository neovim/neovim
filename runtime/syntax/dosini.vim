" Vim syntax file
" Language:               Configuration File (ini file) for MSDOS/MS Windows
" Version:                2.3
" Original Author:        Sean M. McKee <mckee@misslink.net>
" Previous Maintainer:    Nima Talebi <nima@it.net.au>
" Current Maintainer:     Hong Xu <hong@topbug.net>
" Homepage:               http://www.vim.org/scripts/script.php?script_id=3747
" Repository:             https://github.com/xuhdev/syntax-dosini.vim
" Last Change:            2023 Aug 20


" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" using of line-continuation requires cpo&vim
let s:cpo_save = &cpo
set cpo&vim

" shut case off
syn case ignore

syn match  dosiniLabel    "^.\{-}\ze\s*=" nextgroup=dosiniNumber,dosiniValue
syn match  dosiniValue    "=\zs.*"
syn match  dosiniNumber   "=\zs\s*\d\+\s*$"
syn match  dosiniNumber   "=\zs\s*\d*\.\d\+\s*$"
syn match  dosiniNumber   "=\zs\s*\d\+e[+-]\=\d\+\s*$"
syn region dosiniHeader   start="^\s*\[" end="\]"
syn match  dosiniComment  "^[#;].*$"
syn region dosiniSection  start="\s*\[.*\]" end="\ze\s*\[.*\]" fold
      \ contains=dosiniLabel,dosiniValue,dosiniNumber,dosiniHeader,dosiniComment

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link dosiniNumber   Number
hi def link dosiniHeader   Special
hi def link dosiniComment  Comment
hi def link dosiniLabel    Type
hi def link dosiniValue    String


let b:current_syntax = "dosini"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: sts=2 sw=2 et
