" Vim syntax file
" Language:	JavaScript
" Maintainer:	Claudio Fleiner <claudio@fleiner.com>
" Updaters:	Scott Shattuck (ss) <ss@technicalpursuit.com>
" URL:		http://www.fleiner.com/vim/syntax/javascript.vim
" Changes:	(ss) added keywords, reserved words, and other identifiers
"		(ss) repaired several quoting and grouping glitches
"		(ss) fixed regex parsing issue with multiple qualifiers [gi]
"		(ss) additional factoring of keywords, globals, and members
" Last Change:	2022 Jun 09
" 		2013 Jun 12: adjusted javaScriptRegexpString (Kevin Locke)
" 		2018 Apr 14: adjusted javaScriptRegexpString (LongJohnCoder)
" 		2024 Aug 14: fix a few stylistic issues (#15480)
" 		2025 Aug 07: as is a reserved keyword (#17912)

" tuning parameters:
" unlet javaScript_fold

if !exists("main_syntax")
  " quit when a syntax file was already loaded
  if exists("b:current_syntax")
    finish
  endif
  let main_syntax = 'javascript'
elseif exists("b:current_syntax") && b:current_syntax == "javascript"
  finish
endif

let s:cpo_save = &cpo
set cpo&vim


syn keyword javaScriptCommentTodo      TODO FIXME XXX TBD contained
syn match   javaScriptLineComment      "\/\/.*" contains=@Spell,javaScriptCommentTodo
syn match   javaScriptCommentSkip      "^[ \t]*\*\($\|[ \t]\+\)"
syn region  javaScriptComment	       start="/\*"  end="\*/" contains=@Spell,javaScriptCommentTodo
syn match   javaScriptSpecial	       "\\\d\d\d\|\\."
syn region  javaScriptStringD	       start=+"+  skip=+\\\\\|\\"+  end=+"\|$+	contains=javaScriptSpecial,@htmlPreproc
syn region  javaScriptStringS	       start=+'+  skip=+\\\\\|\\'+  end=+'\|$+	contains=javaScriptSpecial,@htmlPreproc
syn region  javaScriptStringT	       start=+`+  skip=+\\\\\|\\`+  end=+`+	contains=javaScriptSpecial,javaScriptEmbed,@htmlPreproc

syn region  javaScriptEmbed	       start=+${+  end=+}+	contains=@javaScriptEmbededExpr

" number handling by Christopher Leonard chris.j.leonard@gmx.com
syn match   javaScriptSpecialCharacter "'\\.'"
syn match   javaScriptNumber           "\<0[bB][0-1]\+\(_[0-1]\+\)*\>"
syn match   javaScriptNumber           "\<0[oO][0-7]\+\(_[0-7]\+\)*\>"
syn match   javaScriptNumber           "\<0\([0-7]\+\(_[0-7]\+\)*\)\?\>"
syn match   javaScriptNumber           "\<0[xX][0-9a-fA-F]\+\(_[0-9a-fA-F]\+\)*\>"
syn match   javaScriptNumber           "\<\d\+\(_\d\+\)*[eE][+-]\?\d\+\>"
syn match   javaScriptNumber           "\<[1-9]\d*\(_\d\+\)*\(\.\(\d\+\(_\d\+\)*\([eE][+-]\?\d\+\)\?\)\?\)\?\>"
syn match   javaScriptNumber           "\<\(\d\+\(_\d\+\)*\)\?\.\d\+\(_\d\+\)*\([eE][+-]\?\d\+\)\?\>"
syn match   javaScriptNumber           "\<\d\+\(_\d\+\)*\.\(\d\+\(_\d\+\)*\([eE][+-]\?\d\+\)\?\)\?\>"
syn region  javaScriptRegexpString     start=+[,(=+]\s*/[^/*]+ms=e-1,me=e-1 skip=+\\\\\|\\/+ end=+/[gimuys]\{0,2\}\s*$+ end=+/[gimuys]\{0,2\}\s*[+;.,)\]}]+me=e-1 end=+/[gimuys]\{0,2\}\s\+\/+me=e-1 contains=@htmlPreproc,javaScriptComment oneline

syn keyword javaScriptConditional	if else switch
syn keyword javaScriptRepeat		while for do in of
syn keyword javaScriptBranch		break continue
syn keyword javaScriptOperator		new delete instanceof typeof
syn keyword javaScriptType		Array Boolean Date Function Number Object String RegExp
syn keyword javaScriptStatement		return with await yield
syn keyword javaScriptBoolean		true false
syn keyword javaScriptNull		null undefined
syn keyword javaScriptIdentifier	arguments this
syn keyword javaScriptLabel		case default
syn keyword javaScriptException		try catch finally throw
syn keyword javaScriptMessage		alert confirm prompt status
syn keyword javaScriptGlobal		self window top parent
syn keyword javaScriptMember		document event location
syn keyword javaScriptDeprecated	escape unescape
syn keyword javaScriptReserved		abstract as boolean byte char class const debugger double enum export extends final float from goto implements import int interface let long native package private protected public short super synchronized throws transient var volatile async
syn keyword javaScriptModifier  static

syn cluster  javaScriptEmbededExpr	contains=javaScriptBoolean,javaScriptNull,javaScriptIdentifier,javaScriptStringD,javaScriptStringS,javaScriptStringT

if exists("javaScript_fold")
    syn match	javaScriptFunction	"\<function\>"
    syn region	javaScriptFunctionFold	start="\<function\>.*[^};]$" end="^\z1}.*$" transparent fold keepend

    syn sync match javaScriptSync	grouphere javaScriptFunctionFold "\<function\>"
    syn sync match javaScriptSync	grouphere NONE "^}"

    setlocal foldmethod=syntax
    setlocal foldtext=getline(v:foldstart)
else
    syn keyword javaScriptFunction	function
    syn match	javaScriptBraces	   "[{}\[\]]"
    syn match	javaScriptParens	   "[()]"
endif

if main_syntax == "javascript"
  syn sync fromstart
  syn sync maxlines=100

  syn sync ccomment javaScriptComment
endif

" Define the default highlighting.
" Only when an item doesn't have highlighting yet
hi def link javaScriptComment		Comment
hi def link javaScriptLineComment		Comment
hi def link javaScriptCommentTodo		Todo
hi def link javaScriptSpecial		Special
hi def link javaScriptStringS		String
hi def link javaScriptStringD		String
hi def link javaScriptStringT		String
hi def link javaScriptCharacter		Character
hi def link javaScriptSpecialCharacter	javaScriptSpecial
hi def link javaScriptNumber		Number
hi def link javaScriptConditional		Conditional
hi def link javaScriptRepeat		Repeat
hi def link javaScriptBranch		Conditional
hi def link javaScriptOperator		Operator
hi def link javaScriptType			Type
hi def link javaScriptStatement		Statement
hi def link javaScriptFunction		Keyword
hi def link javaScriptBraces		Function
hi def link javaScriptError		Error
hi def link javaScrParenError		javaScriptError
hi def link javaScriptNull			Keyword
hi def link javaScriptBoolean		Boolean
hi def link javaScriptRegexpString		String

hi def link javaScriptIdentifier		Identifier
hi def link javaScriptLabel		Label
hi def link javaScriptException		Exception
hi def link javaScriptMessage		Keyword
hi def link javaScriptGlobal		Keyword
hi def link javaScriptMember		Keyword
hi def link javaScriptDeprecated		Exception
hi def link javaScriptReserved		Keyword
hi def link javaScriptModifier		StorageClass
hi def link javaScriptDebug		Debug
hi def link javaScriptConstant		Label
hi def link javaScriptEmbed		Special



let b:current_syntax = "javascript"
if main_syntax == 'javascript'
  unlet main_syntax
endif
let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8
