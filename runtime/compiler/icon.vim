" Vim compiler file
" Compiler:	Icon Compiler
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Apr 03

if exists("current_compiler")
  finish
endif
let current_compiler = "icont"

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
