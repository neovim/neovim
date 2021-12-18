" Vim compiler file
" Compiler:	GNU Awk
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2020 Feb 10

if exists("current_compiler")
  finish
endif
let current_compiler = "gawk"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo&vim

CompilerSet makeprg=gawk
CompilerSet errorformat=%Z%.awk:\ %f:%l:\ %p^\ %m,
		       \%Eg%\\=awk:\ %f:%l:\ fatal:\ %m,
		       \%Egawk:\ %f:%l:\ error:\ %m,
		       \%Wgawk:\ %f:%l:\ warning:\ %m,
		       \%Egawk:\ %f:%l:\ %.%#,
		       \gawk:\ %f:%l:\ %tatal:\ %m,
		       \gawk:\ %f:%l:\ %trror:\ %m,
		       \gawk:\ %f:%l:\ %tarning:\ %m,
		       \gawk:\ %tatal:\ %m,
		       \gawk:\ %trror:\ %m,
		       \gawk:\ %tarning:\ %m,
		       \%+C%.%#,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
