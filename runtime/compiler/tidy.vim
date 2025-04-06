" Vim compiler file
" Compiler:	HTML Tidy
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Apr 03

if exists("current_compiler")
  finish
endif
let current_compiler = "tidy"

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=tidy\ -quiet\ -errors\ --gnu-emacs\ yes
CompilerSet errorformat=%f:%l:%c:\ %trror:\ %m,
		       \%f:%l:%c:\ %tarning:\ %m,
		       \%f:%l:%c:\ %tnfo:\ %m,
		       \%f:%l:%c:\ %m,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
