" Vim compiler file
" Compiler: Zig Compiler (zig build-exe)
" Upstream: https://github.com/ziglang/zig.vim

if exists('current_compiler')
  finish
endif
runtime compiler/zig.vim
let current_compiler = 'zig_build_exe'

let s:save_cpo = &cpo
set cpo&vim


if exists(':CompilerSet') != 2
  command -nargs=* CompilerSet setlocal <args>
endif

if has('patch-7.4.191')
  CompilerSet makeprg=zig\ build-exe\ \%:S\ \$* 
else
  CompilerSet makeprg=zig\ build-exe\ \"%\"\ \$* 
endif

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab
