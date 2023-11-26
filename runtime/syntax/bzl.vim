" Vim syntax file
" Language:	Bazel (http://bazel.io)
" Maintainer:	David Barnett (https://github.com/google/vim-ft-bzl)
" Last Change:	2015 Aug 11

if exists('b:current_syntax')
  finish
endif


runtime! syntax/python.vim

let b:current_syntax = 'bzl'

syn region bzlRule start='^\w\+($' end='^)\n*' transparent fold
syn region bzlList start='\[' end='\]' transparent fold
