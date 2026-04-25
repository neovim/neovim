" Vim compiler file
" Compiler: Zig Compiler (zig test)
" Upstream: https://github.com/ziglang/zig.vim
" Last Change: 2025 Nov 16 by The Vim Project (set errorformat)

if exists('current_compiler')
  finish
endif
runtime compiler/zig.vim
let current_compiler = 'zig_test'

let s:save_cpo = &cpo
set cpo&vim

CompilerSet makeprg=zig\ test\ \%:S\ \$*
" CompilerSet errorformat=%f:%l:%c: %t%*[^:]: %m, %f:%l:%c: %m, %f:%l: %m
CompilerSet errorformat&

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab
