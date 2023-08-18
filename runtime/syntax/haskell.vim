" Vim syntax file
" Language:		Haskell
" Maintainer:		Haskell Cafe mailinglist <haskell-cafe@haskell.org>
" Last Change:		2020 Oct 4 by Marcin Szamotulski <profunctor@pm.me>
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

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" (Qualified) identifiers (no default highlighting)
syn match ConId "\(\<[A-Z][a-zA-Z0-9_']*\.\)*\<[A-Z][a-zA-Z0-9_']*\>" contains=@NoSpell
syn match VarId "\(\<[A-Z][a-zA-Z0-9_']*\.\)*\<[a-z][a-zA-Z0-9_']*\>" contains=@NoSpell

" Infix operators--most punctuation characters and any (qualified) identifier
" enclosed in `backquotes`. An operator starting with : is a constructor,
" others are variables (e.g. functions).
syn match hsVarSym "\(\<[A-Z][a-zA-Z0-9_']*\.\)\=[-!#$%&\*\+/<=>\?@\\^|~.][-!#$%&\*\+/<=>\?@\\^|~:.]*"
syn match hsConSym "\(\<[A-Z][a-zA-Z0-9_']*\.\)\=:[-!#$%&\*\+./<=>\?@\\^|~:]*"
syn match hsVarSym "`\(\<[A-Z][a-zA-Z0-9_']*\.\)\=[a-z][a-zA-Z0-9_']*`"
syn match hsConSym "`\(\<[A-Z][a-zA-Z0-9_']*\.\)\=[A-Z][a-zA-Z0-9_']*`"

" (Non-qualified) identifiers which start with # are labels
syn match hsLabel "#[a-z][a-zA-Z0-9_']*\>"

" Reserved symbols--cannot be overloaded.
syn match hsDelimiter  "(\|)\|\[\|\]\|,\|;\|{\|}"

" Strings and constants
syn match   hsSpecialChar	contained "\\\([0-9]\+\|o[0-7]\+\|x[0-9a-fA-F]\+\|[\"\\'&\\abfnrtv]\|^[A-Z^_\[\\\]]\)"
syn match   hsSpecialChar	contained "\\\(NUL\|SOH\|STX\|ETX\|EOT\|ENQ\|ACK\|BEL\|BS\|HT\|LF\|VT\|FF\|CR\|SO\|SI\|DLE\|DC1\|DC2\|DC3\|DC4\|NAK\|SYN\|ETB\|CAN\|EM\|SUB\|ESC\|FS\|GS\|RS\|US\|SP\|DEL\)"
syn match   hsSpecialCharError	contained "\\&\|'''\+"
syn region  hsString		start=+"+  skip=+\\\\\|\\"+  end=+"+  contains=hsSpecialChar,@NoSpell
syn match   hsCharacter		"[^a-zA-Z0-9_']'\([^\\]\|\\[^']\+\|\\'\)'"lc=1 contains=hsSpecialChar,hsSpecialCharError
syn match   hsCharacter		"^'\([^\\]\|\\[^']\+\|\\'\)'" contains=hsSpecialChar,hsSpecialCharError
syn match   hsNumber		"\v<[0-9]%(_*[0-9])*>|<0[xX]_*[0-9a-fA-F]%(_*[0-9a-fA-F])*>|<0[oO]_*%(_*[0-7])*>|<0[bB]_*[01]%(_*[01])*>"
syn match   hsFloat		"\v<[0-9]%(_*[0-9])*\.[0-9]%(_*[0-9])*%(_*[eE][-+]?[0-9]%(_*[0-9])*)?>|<[0-9]%(_*[0-9])*_*[eE][-+]?[0-9]%(_*[0-9])*>|<0[xX]_*[0-9a-fA-F]%(_*[0-9a-fA-F])*\.[0-9a-fA-F]%(_*[0-9a-fA-F])*%(_*[pP][-+]?[0-9]%(_*[0-9])*)?>|<0[xX]_*[0-9a-fA-F]%(_*[0-9a-fA-F])*_*[pP][-+]?[0-9]%(_*[0-9])*>"

" Keyword definitions.
syn keyword hsModule		module
syn match   hsImportGroup	"\<import\>.*" contains=hsImport,hsImportModuleName,hsImportMod,hsLineComment,hsBlockComment,hsImportList,@NoSpell nextgroup=hsImport
syn keyword hsImport import contained nextgroup=hsImportModuleName
syn match   hsImportModuleName '\<[A-Z][A-Za-z.]*' contained
syn region  hsImportList start='(' skip='([^)]\{-})' end=')' keepend contained contains=ConId,VarId,hsDelimiter,hsBlockComment,hsTypedef,@NoSpell

syn keyword hsImportMod contained as qualified hiding
syn keyword hsInfix infix infixl infixr
syn keyword hsStructure class data deriving instance default where
syn keyword hsTypedef type
syn keyword hsNewtypedef newtype
syn keyword hsTypeFam family
syn keyword hsStatement mdo do case of let in
syn keyword hsConditional if then else

" Not real keywords, but close.
if exists("hs_highlight_boolean")
  " Boolean constants from the standard prelude.
  syn keyword hsBoolean True False
endif
if exists("hs_highlight_types")
  " Primitive types from the standard prelude and libraries.
  syn keyword hsType Int Integer Char Bool Float Double IO Void Addr Array String
endif
if exists("hs_highlight_more_types")
  " Types from the standard prelude libraries.
  syn keyword hsType Maybe Either Ratio Complex Ordering IOError IOResult ExitCode
  syn keyword hsMaybe Nothing
  syn keyword hsExitCode ExitSuccess
  syn keyword hsOrdering GT LT EQ
endif
if exists("hs_highlight_debug")
  " Debugging functions from the standard prelude.
  syn keyword hsDebug undefined error trace
endif


" Comments
syn match   hsLineComment      "---*\([^-!#$%&\*\+./<=>\?@\\^|~].*\)\?$" contains=@Spell
syn region  hsBlockComment     start="{-"  end="-}" contains=hsBlockComment,@Spell
syn region  hsPragma	       start="{-#" end="#-}"

syn keyword hsTodo	        contained FIXME TODO XXX NOTE

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
" Only when an item doesn't have highlighting yet

hi def link hsModule			  hsStructure
hi def link hsImport			  Include
hi def link hsImportMod			  hsImport
hi def link hsInfix			  PreProc
hi def link hsStructure			  Structure
hi def link hsStatement			  Statement
hi def link hsConditional		  Conditional
hi def link hsSpecialChar		  SpecialChar
hi def link hsTypedef			  Typedef
hi def link hsNewtypedef		  Typedef
hi def link hsVarSym			  hsOperator
hi def link hsConSym			  hsOperator
hi def link hsOperator			  Operator
hi def link hsTypeFam			  Structure
if exists("hs_highlight_delimiters")
" Some people find this highlighting distracting.
hi def link hsDelimiter			  Delimiter
endif
hi def link hsSpecialCharError		  Error
hi def link hsString			  String
hi def link hsCharacter			  Character
hi def link hsNumber			  Number
hi def link hsFloat			  Float
hi def link hsConditional			  Conditional
hi def link hsLiterateComment		  hsComment
hi def link hsBlockComment		  hsComment
hi def link hsLineComment			  hsComment
hi def link hsComment			  Comment
hi def link hsPragma			  SpecialComment
hi def link hsBoolean			  Boolean
hi def link hsType			  Type
hi def link hsMaybe			  hsEnumConst
hi def link hsOrdering			  hsEnumConst
hi def link hsEnumConst			  Constant
hi def link hsDebug			  Debug
hi def link hsLabel			  Special

hi def link cCppString			  hsString
hi def link cCommentStart		  hsComment
hi def link cCommentError		  hsError
hi def link cCommentStartError		  hsError
hi def link cInclude			  Include
hi def link cPreProc			  PreProc
hi def link cDefine			  Macro
hi def link cIncluded			  hsString
hi def link cError			  Error
hi def link cPreCondit			  PreCondit
hi def link cComment			  Comment
hi def link cCppSkip			  cCppOut
hi def link cCppOut2			  cCppOut
hi def link cCppOut			  Comment

let b:current_syntax = "haskell"

" Options for vi: ts=8 sw=2 sts=2 nowrap noexpandtab ft=vim
