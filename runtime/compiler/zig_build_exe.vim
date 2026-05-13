" Vim compiler file
" Compiler: Zig Compiler (zig build-exe)
" Upstream: https://github.com/ziglang/zig.vim
" Last Change: 2025 Nov 16 by the Vim Project (set errorformat)
" 2026 May 12 by the Vim project (remove errorformat)

if exists('current_compiler')
  finish
endif
runtime compiler/zig.vim
let current_compiler = 'zig_build_exe'

let s:save_cpo = &cpo
set cpo&vim

CompilerSet makeprg=zig\ build-exe\ \%:S\ \$*

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: tabstop=8 shiftwidth=2 softtabstop=2 expandtab
