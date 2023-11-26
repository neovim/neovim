" Vim compiler file
" Compiler:	Icon Compiler
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2022 Jun 16

if exists("current_compiler")
  finish
endif
let current_compiler = "icont"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=icont\ -s
CompilerSet errorformat=%-G%\\d%\\+\ errors%\\=,
		       \%ERun-time\ error\ %n,
		       \%ERun-time\ error\ %n\ in\ %m,
		       \%ZTraceback:,
                       \%+Coffending\ value:\ %.%#,
                       \%CFile\ %f;\ Line\ %l,
                       \%EFile\ %f;\ Line\ %l\ #\ %m,
		       \%EFile\ %f;\ %m,
		       \%E%f:%l:\ #\ %m,
		       \%E%f:\ %m,
		       \%+C%.%#,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
