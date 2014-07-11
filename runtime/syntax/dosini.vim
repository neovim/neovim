" Vim syntax file
" Language:               Configuration File (ini file) for MSDOS/MS Windows
" Version:                2.1
" Original Author:        Sean M. McKee <mckee@misslink.net>
" Previous Maintainer:    Nima Talebi <nima@it.net.au>
" Current Maintainer:     Hong Xu <xuhdev@gmail.com>
" Homepage:               http://www.vim.org/scripts/script.php?script_id=3747
"                         https://bitbucket.org/xuhdev/syntax-dosini.vim
" Last Change:            2011 Nov 8


" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
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
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_dosini_syntax_inits")
  if version < 508
    let did_dosini_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink dosiniNumber   Number
  HiLink dosiniHeader   Special
  HiLink dosiniComment  Comment
  HiLink dosiniLabel    Type

  delcommand HiLink
endif

let b:current_syntax = "dosini"

" vim: sts=2 sw=2 et
