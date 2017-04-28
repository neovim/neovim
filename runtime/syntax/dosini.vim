" Vim syntax file
" Language:               Configuration File (ini file) for MSDOS/MS Windows
" Version:                2.1
" Original Author:        Sean M. McKee <mckee@misslink.net>
" Previous Maintainer:    Nima Talebi <nima@it.net.au>
" Current Maintainer:     Hong Xu <xuhdev@gmail.com>
" Homepage:               http://www.vim.org/scripts/script.php?script_id=3747
"                         https://bitbucket.org/xuhdev/syntax-dosini.vim
" Last Change:            2011 Nov 8


" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" shut case off
syn case ignore

syn match  dosiniNumber   "\<\d\+\>"
syn match  dosiniNumber   "\<\d*\.\d\+\>"
syn match  dosiniNumber   "\<\d\+e[+-]\=\d\+\>"
syn match  dosiniLabel    "^.\{-}="
syn region dosiniHeader   start="^\s*\[" end="\]"
syn match  dosiniComment  "^[#;].*$"

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link dosiniNumber   Number
hi def link dosiniHeader   Special
hi def link dosiniComment  Comment
hi def link dosiniLabel    Type


let b:current_syntax = "dosini"

" vim: sts=2 sw=2 et
