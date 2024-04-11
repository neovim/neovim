" Vim Compiler File
" Language:             vimdoc
" Maintainer:           Wu, Zhenyu <wuzhenyu@ustc.edu>
" Latest Revision:      2024-04-09
"
" you can get it by `pip install vimdoc` or the package manager of your distribution.

if exists('b:current_compiler')
  finish
endif
let b:current_compiler = 'vimdoc'

let s:save_cpoptions = &cpoptions
set cpoptions&vim

CompilerSet makeprg=vimdoc

let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
