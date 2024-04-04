" Vim compiler file
" Compiler:	onsgmls
" Maintainer:	Robert Rowsome <rowsome@wam.umd.edu>
" Last Change:	2019 Jul 23
"		2024 Apr 03 by The Vim Project (removed :CompilerSet definition)

if exists("current_compiler")
  finish
endif
let current_compiler = "onsgmls"

let s:cpo_save = &cpo
set cpo-=C

CompilerSet makeprg=onsgmls\ -s\ %:S

CompilerSet errorformat=onsgmls:%f:%l:%c:%t:%m,
		    \onsgmls:%f:%l:%c:%m

let &cpo = s:cpo_save
unlet s:cpo_save
