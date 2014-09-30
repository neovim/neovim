" Vim indent file
" Language:		JSON
" Maintainer:		David Barnett <daviebdawg+vim@gmail.com>
" Last Change:		2014 Jul 16

if exists('b:did_indent')
   finish
endif

" JSON is a subset of JavaScript. JavaScript indenting should work fine.
runtime! indent/javascript.vim

let b:did_indent = 1
