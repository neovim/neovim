" Vim syntax file
" Language:		Haskell
" Maintainer:		Haskell Cafe mailinglist <haskell-cafe@haskell.org>
" Last Change:		2008 Dec 15
" Original Author:	John Williams <jrw@pobox.com>
"
" Thanks to Ryan Crumley for suggestions and John Meacham for
" pointing out bugs. Also thanks to Ian Lynagh and Donald Bruce Stewart
" for providing the inspiration for the inclusion of the handling
" of C preprocessor directives, and for pointing out a bug in the
" end-of-line comment handling.
"
" Options-assign a value to these variables to turn the option on:
"
" hs_highlight_delimiters - Highlight delimiter characters--users
"			    with a light-colored background will
"			    probably want to turn this on.
" hs_highlight_boolean - Treat True and False as keywords.
" hs_highlight_types - Treat names of primitive types as keywords.
" hs_highlight_more_types - Treat names of other common types as keywords.
" hs_highlight_debug - Highlight names of debugging functions.
" hs_allow_hash_operator - Don't highlight seemingly incorrect C
"			   preprocessor directives but assume them to be
"			   operators
"
" 2004 Feb 19: Added C preprocessor directive handling, corrected eol comments
"	       cleaned away literate haskell support (should be entirely in
"	       lhaskell.vim)
" 2004 Feb 20: Cleaned up C preprocessor directive handling, fixed single \
"	       in eol comment character class
" 2004 Feb 23: Made the leading comments somewhat clearer where it comes
"	       to attribution of work.
" 2008 Dec 15: Added comments as contained element in import statements

" Remove any old syntax stuff hanging around
if version < 600
  syn clear
elseif exists("b:current_syntax")
  finish
endif

" (Qualified) identifiers (no default highlighting)
syn match ConId "\(\<[A-Z][a-zA-Z0-9_']*\.\)\=\<[A-Z][a-zA-Z0-9_']*\>"
syn match VarId "\(\<[A-Z][a-zA-Z0-9_']*\.\)\=\<[a-z][a-zA-Z0-9_']*\>"

" Infix operators--most punctuation characters and any (qualified) identifier
" enclosed in `backquotes`. An operator starting with : is a constructor,
" others are variables (e.g. functions).
syn match hsVarSym "\(\<[A-Z][a-zA-Z0-9_']*\.\)\=[-!#$%&\*\+/<=>\?@\\^|~.][-!#$%&\*\+/<=>\?@\\^|~:.]*"
syn match hsConSym "\(\<[A-Z][a-zA-Z0-9_']*\.\)\=:[-!#$%&\*\+./<=>\?@\\^|~:]*"
syn match hsVarSym "`\(\<[A-Z][a-zA-Z0-9_']*\.\)\=[a-z][a-zA-Z0-9_']*`"
syn match hsConSym "`\(\<[A-Z][a-zA-Z0-9_']*\.\)\=[A-Z][a-zA-Z0-9_']*`"

" Reserved symbols--cannot be overloaded.
syn match hsDelimiter  "(\|)\|\[\|\]\|,\|;\|_\|{\|}"

" Strings and constants
syn match   hsSpecialChar	contained "\\\([0-9]\+\|o[0-7]\+\|x[0-9a-fA-F]\+\|[\"\\'&\\abfnrtv]\|^[A-Z^_\[\\\]]\)"
syn match   hsSpecialChar	contained "\\\(NUL\|SOH\|STX\|ETX\|EOT\|ENQ\|ACK\|BEL\|BS\|HT\|LF\|VT\|FF\|CR\|SO\|SI\|DLE\|DC1\|DC2\|DC3\|DC4\|NAK\|SYN\|ETB\|CAN\|EM\|SUB\|ESC\|FS\|GS\|RS\|US\|SP\|DEL\)"
syn match   hsSpecialCharError	contained "\\&\|'''\+"
syn region  hsString		start=+"+  skip=+\\\\\|\\"+  end=+"+  contains=hsSpecialChar
syn match   hsCharacter		"[^a-zA-Z0-9_']'\([^\\]\|\\[^']\+\|\\'\)'"lc=1 contains=hsSpecialChar,hsSpecialCharError
syn match   hsCharacter		"^'\([^\\]\|\\[^']\+\|\\'\)'" contains=hsSpecialChar,hsSpecialCharError
syn match   hsNumber		"\<[0-9]\+\>\|\<0[xX][0-9a-fA-F]\+\>\|\<0[oO][0-7]\+\>"
syn match   hsFloat		"\<[0-9]\+\.[0-9]\+\([eE][-+]\=[0-9]\+\)\=\>"

" Keyword definitions. These must be patters instead of keywords
" because otherwise they would match as keywords at the start of a
" "literate" comment (see lhs.vim).
syn match hsModule		"\<module\>"
syn match hsImport		"\<import\>.*"he=s+6 contains=hsImportMod,hsLineComment,hsBlockComment
syn match hsImportMod		contained "\<\(as\|qualified\|hiding\)\>"
syn match hsInfix		"\<\(infix\|infixl\|infixr\)\>"
syn match hsStructure		"\<\(class\|data\|deriving\|instance\|default\|where\)\>"
syn match hsTypedef		"\<\(type\|newtype\)\>"
syn match hsStatement		"\<\(do\|case\|of\|let\|in\)\>"
syn match hsConditional		"\<\(if\|then\|else\)\>"

" Not real keywords, but close.
if exists("hs_highlight_boolean")
  " Boolean constants from the standard prelude.
  syn match hsBoolean "\<\(True\|False\)\>"
endif
if exists("hs_highlight_types")
  " Primitive types from the standard prelude and libraries.
  syn match hsType "\<\(Int\|Integer\|Char\|Bool\|Float\|Double\|IO\|Void\|Addr\|Array\|String\)\>"
endif
if exists("hs_highlight_more_types")
  " Types from the standard prelude libraries.
  syn match hsType "\<\(Maybe\|Either\|Ratio\|Complex\|Ordering\|IOError\|IOResult\|ExitCode\)\>"
  syn match hsMaybe    "\<Nothing\>"
  syn match hsExitCode "\<\(ExitSuccess\)\>"
  syn match hsOrdering "\<\(GT\|LT\|EQ\)\>"
endif
if exists("hs_highlight_debug")
  " Debugging functions from the standard prelude.
  syn match hsDebug "\<\(undefined\|error\|trace\)\>"
endif


" Comments
syn match   hsLineComment      "---*\([^-!#$%&\*\+./<=>\?@\\^|~].*\)\?$"
syn region  hsBlockComment     start="{-"  end="-}" contains=hsBlockComment
syn region  hsPragma	       start="{-#" end="#-}"

" C Preprocessor directives. Shamelessly ripped from c.vim and trimmed
" First, see whether to flag directive-like lines or not
if (!exists("hs_allow_hash_operator"))
    syn match	cError		display "^\s*\(%:\|#\).*$"
endif
" Accept %: for # (C99)
syn region	cPreCondit	start="^\s*\(%:\|#\)\s*\(if\|ifdef\|ifndef\|elif\)\>" skip="\\$" end="$" end="//"me=s-1 contains=cComment,cCppString,cCommentError
syn match	cPreCondit	display "^\s*\(%:\|#\)\s*\(else\|endif\)\>"
syn region	cCppOut		start="^\s*\(%:\|#\)\s*if\s\+0\+\>" end=".\@=\|$" contains=cCppOut2
syn region	cCppOut2	contained start="0" end="^\s*\(%:\|#\)\s*\(endif\>\|else\>\|elif\>\)" contains=cCppSkip
syn region	cCppSkip	contained start="^\s*\(%:\|#\)\s*\(if\>\|ifdef\>\|ifndef\>\)" skip="\\$" end="^\s*\(%:\|#\)\s*endif\>" contains=cCppSkip
syn region	cIncluded	display contained start=+"+ skip=+\\\\\|\\"+ end=+"+
syn match	cIncluded	display contained "<[^>]*>"
syn match	cInclude	display "^\s*\(%:\|#\)\s*include\>\s*["<]" contains=cIncluded
syn cluster	cPreProcGroup	contains=cPreCondit,cIncluded,cInclude,cDefine,cCppOut,cCppOut2,cCppSkip,cCommentStartError
syn region	cDefine		matchgroup=cPreCondit start="^\s*\(%:\|#\)\s*\(define\|undef\)\>" skip="\\$" end="$"
syn region	cPreProc	matchgroup=cPreCondit start="^\s*\(%:\|#\)\s*\(pragma\>\|line\>\|warning\>\|warn\>\|error\>\)" skip="\\$" end="$" keepend

syn region	cComment	matchgroup=cCommentStart start="/\*" end="\*/" contains=cCommentStartError,cSpaceError contained
syntax match	cCommentError	display "\*/" contained
syntax match	cCommentStartError display "/\*"me=e-1 contained
syn region	cCppString	start=+L\="+ skip=+\\\\\|\\"\|\\$+ excludenl end=+"+ end='$' contains=cSpecial contained

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_hs_syntax_inits")
  if version < 508
    let did_hs_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink hsModule			  hsStructure
  HiLink hsImport			  Include
  HiLink hsImportMod			  hsImport
  HiLink hsInfix			  PreProc
  HiLink hsStructure			  Structure
  HiLink hsStatement			  Statement
  HiLink hsConditional			  Conditional
  HiLink hsSpecialChar			  SpecialChar
  HiLink hsTypedef			  Typedef
  HiLink hsVarSym			  hsOperator
  HiLink hsConSym			  hsOperator
  HiLink hsOperator			  Operator
  if exists("hs_highlight_delimiters")
    " Some people find this highlighting distracting.
    HiLink hsDelimiter			  Delimiter
  endif
  HiLink hsSpecialCharError		  Error
  HiLink hsString			  String
  HiLink hsCharacter			  Character
  HiLink hsNumber			  Number
  HiLink hsFloat			  Float
  HiLink hsConditional			  Conditional
  HiLink hsLiterateComment		  hsComment
  HiLink hsBlockComment		  hsComment
  HiLink hsLineComment			  hsComment
  HiLink hsComment			  Comment
  HiLink hsPragma			  SpecialComment
  HiLink hsBoolean			  Boolean
  HiLink hsType			  Type
  HiLink hsMaybe			  hsEnumConst
  HiLink hsOrdering			  hsEnumConst
  HiLink hsEnumConst			  Constant
  HiLink hsDebug			  Debug

  HiLink cCppString		hsString
  HiLink cCommentStart		hsComment
  HiLink cCommentError		hsError
  HiLink cCommentStartError	hsError
  HiLink cInclude		Include
  HiLink cPreProc		PreProc
  HiLink cDefine		Macro
  HiLink cIncluded		hsString
  HiLink cError			Error
  HiLink cPreCondit		PreCondit
  HiLink cComment		Comment
  HiLink cCppSkip		cCppOut
  HiLink cCppOut2		cCppOut
  HiLink cCppOut		Comment

  delcommand HiLink
endif

let b:current_syntax = "haskell"

" Options for vi: ts=8 sw=2 sts=2 nowrap noexpandtab ft=vim
