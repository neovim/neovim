" Vim syntax file
" Language:	sendmail
" Maintainer:	Charles E. Campbell <NdrOchipS@PcampbellAfamily.Mbiz>
" Last Change:	Oct 25, 2016
" Version:	8
" URL:	http://www.drchip.org/astronaut/vim/index.html#SYNTAX_SM
if exists("b:current_syntax")
  finish
endif

" Comments
syn match smComment	"^#.*$"	contains=@Spell

" Definitions, Classes, Files, Options, Precedence, Trusted Users, Mailers
syn match smDefine	"^[CDF]."
syn match smDefine	"^O[AaBcdDeFfgHiLmNoQqrSsTtuvxXyYzZ]"
syn match smDefine	"^O\s"he=e-1
syn match smDefine	"^M[a-zA-Z0-9]\+,"he=e-1
syn match smDefine	"^T"	nextgroup=smTrusted
syn match smDefine	"^P"	nextgroup=smMesg
syn match smTrusted	"\S\+$"		contained
syn match smMesg		"\S*="he=e-1	contained nextgroup=smPrecedence
syn match smPrecedence	"-\=[0-9]\+"		contained

" Header Format  H?list-of-mailer-flags?name: format
syn match smHeaderSep contained "[?:]"
syn match smHeader	"^H\(?[a-zA-Z]\+?\)\=[-a-zA-Z_]\+:" contains=smHeaderSep

" Variables
syn match smVar		"\$[a-z\.\|]"

" Rulesets
syn match smRuleset	"^S\d*"

" Rewriting Rules
syn match smRewrite	"^R"			skipwhite nextgroup=smRewriteLhsToken,smRewriteLhsUser

syn match smRewriteLhsUser	contained "[^\t$]\+"		skipwhite nextgroup=smRewriteLhsToken,smRewriteLhsSep
syn match smRewriteLhsToken	contained "\(\$[-*+]\|\$[-=][A-Za-z]\|\$Y\)\+"	skipwhite nextgroup=smRewriteLhsUser,smRewriteLhsSep

syn match smRewriteLhsSep	contained "\t\+"			skipwhite nextgroup=smRewriteRhsToken,smRewriteRhsUser

syn match smRewriteRhsUser	contained "[^\t$]\+"		skipwhite nextgroup=smRewriteRhsToken,smRewriteRhsSep
syn match smRewriteRhsToken	contained "\(\$\d\|\$>\d\|\$#\|\$@\|\$:[-_a-zA-Z]\+\|\$[[\]]\|\$@\|\$:\|\$[A-Za-z]\)\+" skipwhite nextgroup=smRewriteRhsUser,smRewriteRhsSep

syn match smRewriteRhsSep	contained "\t\+"			skipwhite nextgroup=smRewriteComment,smRewriteRhsSep
syn match smRewriteRhsSep	contained "$"

syn match smRewriteComment	contained "[^\t$]*$"

" Clauses
syn match smClauseError		"\$\."
syn match smElse		contained	"\$|"
syn match smClauseCont	contained	"^\t"
syn region smClause	matchgroup=Delimiter start="\$?." matchgroup=Delimiter end="\$\." contains=smElse,smClause,smVar,smClauseCont

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link smClause	Special
hi def link smClauseError	Error
hi def link smComment	Comment
hi def link smDefine	Statement
hi def link smElse	Delimiter
hi def link smHeader	Statement
hi def link smHeaderSep	String
hi def link smMesg	Special
hi def link smPrecedence	Number
hi def link smRewrite	Statement
hi def link smRewriteComment	Comment
hi def link smRewriteLhsToken	String
hi def link smRewriteLhsUser	Statement
hi def link smRewriteRhsToken	String
hi def link smRuleset	Preproc
hi def link smTrusted	Special
hi def link smVar		String

let b:current_syntax = "sm"

" vim: ts=18
