" Vim Compiler File
" Language:             vimdoc
" Maintainer:           Wu, Zhenyu <wuzhenyu@ustc.edu> (invalid)
" Latest Revision:      2024-04-13
" Last Change: 2025 Nov 16 by The Vim Project (set errorformat)
"
" If you can not find 'vimdoc' in the package manager of your distribution e.g
" 'pip', then you may need to build it from its source.

if exists('b:current_compiler')
  finish
endif
let b:current_compiler = 'vimdoc'

let s:save_cpoptions = &cpoptions
set cpoptions&vim

CompilerSet makeprg=vimdoc
" CompilerSet errorformat=%f:%l:%c:\ %m,%f:%l:\ %m
CompilerSet errorformat&

let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
