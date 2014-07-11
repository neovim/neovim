" Vim syntax file
" Language:	sendmail
" Maintainer:	Dr. Charles E. Campbell, Jr. <NdrOchipS@PcampbellAfamily.Mbiz>
" Last Change:	Sep 06, 2005
" Version:	4
" URL:	http://mysite.verizon.net/astronaut/vim/index.html#vimlinks_syntax

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
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
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_smil_syntax_inits")
  if version < 508
    let did_smil_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink smClause	Special
  HiLink smClauseError	Error
  HiLink smComment	Comment
  HiLink smDefine	Statement
  HiLink smElse		Delimiter
  HiLink smHeader	Statement
  HiLink smHeaderSep	String
  HiLink smMesg		Special
  HiLink smPrecedence	Number
  HiLink smRewrite	Statement
  HiLink smRewriteComment	Comment
  HiLink smRewriteLhsToken	String
  HiLink smRewriteLhsUser	Statement
  HiLink smRewriteRhsToken	String
  HiLink smRuleset	Preproc
  HiLink smTrusted	Special
  HiLink smVar		String

  delcommand HiLink
endif

let b:current_syntax = "sm"

" vim: ts=18
