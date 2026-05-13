" Vim compiler file
" Compiler: Zig Compiler (zig test)
" Upstream: https://github.com/ziglang/zig.vim
" Last Change: 2025 Nov 16 by the Vim Project (set errorformat)
" 2026 May 12 by the Vim Project (remove error format)

if exists('current_compiler')
  finish
endif
runtime compiler/zig.vim
let current_compiler = 'zig_test'

let s:save_cpo = &cpo
set cpo&vim

CompilerSet makeprg=zig\ test\ \%:S\ \$*

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: tabstop=8 shiftwidth=2 softtabstop=2 expandtab
