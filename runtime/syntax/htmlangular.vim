" Vim syntax file
" Language: Angular HTML template
" Maintainer: Dennis van den Berg <dennis@vdberg.dev>
" Last Change: 2024 Aug 22

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

if !exists("main_syntax")
  let main_syntax = 'html'
endif

runtime! syntax/html.vim
unlet b:current_syntax

let b:current_syntax = "htmlangular"
