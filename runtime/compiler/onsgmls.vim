" Vim compiler file
" Compiler:	onsgmls
" Maintainer:	Robert Rowsome <rowsome@wam.umd.edu>
" Last Change:	2019 Jul 23

if exists("current_compiler")
  finish
endif
let current_compiler = "onsgmls"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo-=C

CompilerSet makeprg=onsgmls\ -s\ %:S

CompilerSet errorformat=onsgmls:%f:%l:%c:%t:%m,
		    \onsgmls:%f:%l:%c:%m

let &cpo = s:cpo_save
unlet s:cpo_save
