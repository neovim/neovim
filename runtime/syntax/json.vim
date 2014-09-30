" Vim syntax file
" Language:		JSON
" Maintainer:		David Barnett <daviebdawg+vim@gmail.com>
" Last Change:		2014 Jul 16

" For version 5.x: Clear all syntax items.
" For version 6.x and later: Quit when a syntax file was already loaded.
if exists('b:current_syntax')
  finish
endif

" Use JavaScript syntax. JSON is a subset of JavaScript.
runtime! syntax/javascript.vim
unlet b:current_syntax

let b:current_syntax = 'json'
