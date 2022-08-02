" Vim syntax file
" Language:	Elm Filter rules
" Maintainer:	Charles E. Campbell <NcampObell@SdrPchip.AorgM-NOSPAM>
" Last Change:	Aug 31, 2016
" Version:	9
" URL:	http://www.drchip.org/astronaut/vim/index.html#SYNTAX_ELMFILT

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn cluster elmfiltIfGroup	contains=elmfiltCond,elmfiltOper,elmfiltOperKey,,elmfiltNumber,elmfiltOperKey

syn match	elmfiltParenError	"[()]"
syn match	elmfiltMatchError	"/"
syn region	elmfiltIf	start="\<if\>" end="\<then\>"	contains=elmfiltParen,elmfiltParenError skipnl skipwhite nextgroup=elmfiltAction
syn region	elmfiltParen	contained	matchgroup=Delimiter start="(" matchgroup=Delimiter end=")"	contains=elmfiltParen,@elmfiltIfGroup,elmfiltThenError
syn region	elmfiltMatch	contained	matchgroup=Delimiter start="/" skip="\\/" matchgroup=Delimiter end="/"	skipnl skipwhite nextgroup=elmfiltOper,elmfiltOperKey
syn match	elmfiltThenError	"\<then.*$"
syn match	elmfiltComment	"^#.*$"		contains=@Spell

syn keyword	elmfiltAction	contained	delete execute executec forward forwardc leave save savecopy skipnl skipwhite nextgroup=elmfiltString
syn match	elmfiltArg	contained	"[^\\]%[&0-9dDhmrsSty&]"lc=1

syn match	elmfiltOperKey	contained	"\<contains\>"			skipnl skipwhite nextgroup=elmfiltString
syn match	elmfiltOperKey	contained	"\<matches\s"			nextgroup=elmfiltMatch,elmfiltSpaceError
syn keyword	elmfiltCond	contained	cc bcc lines always subject sender from to lines received	skipnl skipwhite nextgroup=elmfiltString
syn match	elmfiltNumber	contained	"\d\+"
syn keyword	elmfiltOperKey	contained	and not				skipnl skipwhite nextgroup=elmfiltOper,elmfiltOperKey,elmfiltString
syn match	elmfiltOper	contained	"\~"				skipnl skipwhite nextgroup=elmfiltMatch
syn match	elmfiltOper	contained	"<=\|>=\|!=\|<\|<\|="		skipnl skipwhite nextgroup=elmfiltString,elmfiltCond,elmfiltOperKey
syn region	elmfiltString	contained	start='"' skip='"\(\\\\\)*\\["%]' end='"'	contains=elmfiltArg skipnl skipwhite nextgroup=elmfiltOper,elmfiltOperKey,@Spell
syn region	elmfiltString	contained	start="'" skip="'\(\\\\\)*\\['%]" end="'"	contains=elmfiltArg skipnl skipwhite nextgroup=elmfiltOper,elmfiltOperKey,@Spell
syn match	elmfiltSpaceError	contained	"\s.*$"

" Define the default highlighting.
if !exists("skip_elmfilt_syntax_inits")

  hi def link elmfiltAction	Statement
  hi def link elmfiltArg	Special
  hi def link elmfiltComment	Comment
  hi def link elmfiltCond	Statement
  hi def link elmfiltIf	Statement
  hi def link elmfiltMatch	Special
  hi def link elmfiltMatchError	Error
  hi def link elmfiltNumber	Number
  hi def link elmfiltOper	Operator
  hi def link elmfiltOperKey	Type
  hi def link elmfiltParenError	Error
  hi def link elmfiltSpaceError	Error
  hi def link elmfiltString	String
  hi def link elmfiltThenError	Error

endif

let b:current_syntax = "elmfilt"
" vim: ts=9
