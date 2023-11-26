" Vim compiler file
" Compiler: Zig Compiler (zig test)
" Upstream: https://github.com/ziglang/zig.vim

if exists('current_compiler')
  finish
endif
runtime compiler/zig.vim
let current_compiler = 'zig_test'

let s:save_cpo = &cpo
set cpo&vim


if exists(':CompilerSet') != 2
  command -nargs=* CompilerSet setlocal <args>
endif

if has('patch-7.4.191')
  CompilerSet makeprg=zig\ test\ \%:S\ \$* 
else
  CompilerSet makeprg=zig\ test\ \"%\"\ \$* 
endif

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab
