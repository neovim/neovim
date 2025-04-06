" Vim compiler file
" Compiler:	Checkstyle
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Apr 03

if exists("current_compiler")
  finish
endif
let current_compiler = "checkstyle"

let s:cpo_save = &cpo
set cpo&vim

" CompilerSet makeprg=java\ com.puppycrawl.tools.checkstyle.Main\ -f\ plain\ -c\ /sun_checks.xml
" CompilerSet makeprg=java\ -jar\ checkstyle-X.XX-all.jar\ -f\ plain\ -c\ /sun_checks.xml

CompilerSet makeprg=checkstyle\ -f\ plain
CompilerSet errorformat=[%tRROR]\ %f:%l:%v:\ %m,
		       \[%tARN]\ %f:%l:%v:\ %m,
		       \[%tRROR]\ %f:%l:\ %m,
		       \[%tARN]\ %f:%l:\ %m,
		       \%-G%.%#

let &cpo = s:cpo_save
unlet s:cpo_save
