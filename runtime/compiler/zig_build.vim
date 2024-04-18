" Vim compiler file
" Compiler: Zig Compiler (zig build)
" Upstream: https://github.com/ziglang/zig.vim
" Last Change: 2024 Apr 05 by The Vim Project (removed :CompilerSet definition)

if exists('current_compiler')
  finish
endif
runtime compiler/zig.vim
let current_compiler = 'zig_build'

let s:save_cpo = &cpo
set cpo&vim

if exists('g:zig_build_makeprg_params')
	execute 'CompilerSet makeprg=zig\ build\ '.escape(g:zig_build_makeprg_params, ' \|"').'\ $*'
else
	CompilerSet makeprg=zig\ build\ $*
endif

" TODO: anything to add to errorformat for zig build specifically?

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab
