" Vim syntax file
" Language:     Tolk
" Maintainer:   redavy <hello.redavy@proton.me>
" Upstream:     https://github.com/redavy/vim-tolk
" Last Update:  28 May 2026

if exists("b:current_syntax")
  finish
endif

" Keywords
syn keyword tolkKeyword  do if as fun asm get try var val lazy
syn keyword tolkKeyword  else enum true tolk const false throw
syn keyword tolkKeyword  redef while catch return assert import
syn keyword tolkKeyword  global repeat contract mutate struct
syn keyword tolkKeyword  match type null void never

" Strings
syn region tolkString  start=+"+ end=+"+
syn region tolkString  start=+'+ end=+'+

" Numbers
syn match tolkNumber  "\<[0-9]\+\>"
syn match tolkNumber  "\<0[xX][0-9a-fA-F]\+\>"
syn match tolkNumber  "\<[0-9]\+\.[0-9]\+\>"

" Comments
syn match  tolkComment  "//.*$"
syn region tolkComment  start="/\*" end="\*/"

" Highlights
hi link tolkKeyword    Keyword
hi link tolkString     String
hi link tolkNumber     Number
hi link tolkComment    Comment

let b:current_syntax = "tolk"
