" Vim syntax file
" Language:	Elm Filter rules
" Maintainer:	Charles E. Campbell <NdrOchipS@PcampbellAfamily.Mbiz>
" Last Change:	Oct 23, 2014
" Version:	6
" URL:	http://www.drchip.org/astronaut/vim/index.html#SYNTAX_ELMFILT

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
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
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_elmfilt_syntax_inits")
  if version < 508
    let did_elmfilt_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink elmfiltAction	Statement
  HiLink elmfiltArg	Special
  HiLink elmfiltComment	Comment
  HiLink elmfiltCond	Statement
  HiLink elmfiltIf	Statement
  HiLink elmfiltMatch	Special
  HiLink elmfiltMatchError	Error
  HiLink elmfiltNumber	Number
  HiLink elmfiltOper	Operator
  HiLink elmfiltOperKey	Type
  HiLink elmfiltParenError	Error
  HiLink elmfiltSpaceError	Error
  HiLink elmfiltString	String
  HiLink elmfiltThenError	Error

  delcommand HiLink
endif

let b:current_syntax = "elmfilt"
" vim: ts=9
