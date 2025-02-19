" Vim compiler file
" Compiler: Zig Compiler
" Upstream: https://github.com/ziglang/zig.vim

if exists("current_compiler")
    finish
endif
let current_compiler = "zig"

let s:save_cpo = &cpo
set cpo&vim

" a subcommand must be provided for the this compiler (test, build-exe, etc)
if has('patch-7.4.191')
    CompilerSet makeprg=zig\ \$*\ \%:S
else
    CompilerSet makeprg=zig\ \$*\ \"%\"
endif

" TODO: improve errorformat as needed.

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab
