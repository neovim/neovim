" Vim Compiler File
" Compiler:	Jikes
" Maintainer:	Dan Sharp <dwsharp at hotmail dot com>
" Last Change:	20 Jan 2009
" URL:		http://dwsharp.users.sourceforge.net/vim/compiler

if exists("current_compiler")
  finish
endif
let current_compiler = "jikes"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

" Jikes defaults to printing output on stderr
CompilerSet makeprg=jikes\ -Xstdout\ +E\ \"%\"
CompilerSet errorformat=%f:%l:%v:%*\\d:%*\\d:%*\\s%m
