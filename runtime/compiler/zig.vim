" Vim compiler file
" Compiler: Zig Compiler
" Upstream: https://github.com/ziglang/zig.vim
" Last Change:
" 2026 May 12 by the Vim project (set errormformat)

if exists("current_compiler")
    finish
endif
let current_compiler = "zig"

let s:save_cpo = &cpo
set cpo&vim

" a subcommand must be provided for the this compiler (test, build-exe, etc)
CompilerSet makeprg=zig\ \$*\ \%:S

CompilerSet errorformat=
            \%-G,
            \%-G\ %#+-\ %.%#,
            \%-Ginstall,
            \%-Ginstall\ transitive\ failure,
            \%-Grun,
            \%-Grun\ transitive\ failure,
            \%-Gtest,
            \%-Gtest\ transitive\ failure,
            \%-Gfailed\ command:\ %.%#,
            \%-Gerror:\ %*\\d\ compilation\ errors,
            \%-GBuild\ Summary:\ %.%#,
            \%-Gerror:\ the\ following\ build\ command\ failed\ with\ exit\ code\ %*\\d:,
            \%-G.zig-cache%.%#,
            \%E%f:%l:%c:\ error:\ %m,
            \%I%f:%l:%c:\ note:\ %m

" zig has no warnings, but zig cc and zig c++ do
CompilerSet errorformat+=
            \%W%f:%l:%c:\ warning:\ %m,
            \%-G%*\\d\ warnings\ generated.

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab
