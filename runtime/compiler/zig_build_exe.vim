" Vim compiler file
" Compiler: Zig Compiler (zig build-exe)
" Upstream: https://github.com/ziglang/zig.vim
" Last Change: 2024 Apr 05 by The Vim Project (removed :CompilerSet definition)

if exists('current_compiler')
  finish
endif
runtime compiler/zig.vim
let current_compiler = 'zig_build_exe'

let s:save_cpo = &cpo
set cpo&vim

if has('patch-7.4.191')
  CompilerSet makeprg=zig\ build-exe\ \%:S\ \$* 
else
  CompilerSet makeprg=zig\ build-exe\ \"%\"\ \$* 
endif

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab
