" the Requirements File Format syntax support for Vim
" Version: 1.8.0
" Author:  raimon <raimon49@hotmail.com>
" Upstream: https://github.com/raimon49/requirements.txt.vim
" License: MIT LICENSE
" The MIT License (MIT)
"
" Copyright (c) 2015 raimon
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to deal
" in the Software without restriction, including without limitation the rights
" to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
" copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in all
" copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
" SOFTWARE.
if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:save_cpoptions = &cpoptions
set cpoptions&vim

let b:undo_ftplugin = "setl iskeyword< commentstring<"
" pip options contain "-"
setlocal iskeyword+=-
setlocal commentstring=#\ %s

if !exists('current_compiler')
  let b:undo_ftplugin ..= "| compiler make"
  compiler  pip_compile
endif

let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
" vim: et sw=4 ts=4 sts=4:
