" Vim compiler plugin
"
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2024 Sep 10
" Original Author: Konfekt
"
" This compiler plugin is used to reset previously set compiler options.

if exists("g:current_compiler") | unlet g:current_compiler | endif
if exists("b:current_compiler") | unlet b:current_compiler | endif

CompilerSet makeprg&
CompilerSet errorformat&
