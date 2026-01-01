" Vim syntax file
" Language:	OpenCL
" Last Change:	2024 Nov 19
" Maintainer:	Wu, Zhenyu <wuzhenyu@ustc.edu>

if exists("b:current_syntax")
  finish
endif

" TODO: support openCL specific keywords
runtime! syntax/c.vim

let current_syntax = "opencl"
