" Vim syntax file
" Language:	B (A Formal Method with refinement and mathematical proof)
" Maintainer:	Mathieu Clabaut <mathieu.clabaut@gmail.com>
" Contributor:  Csaba Hoch
" LastChange:	8 Dec 2007


" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
   syntax clear
elseif exists("b:current_syntax")
   finish
endif


" A bunch of useful B keywords
syn keyword bStatement	        MACHINE MODEL SEES OPERATIONS INCLUDES DEFINITIONS CONSTRAINTS CONSTANTS VARIABLES CONCRETE_CONSTANTS CONCRETE_VARIABLES ABSTRACT_CONSTANTS ABSTRACT_VARIABLES HIDDEN_CONSTANTS HIDDEN_VARIABLES ASSERT ASSERTIONS  EXTENDS IMPLEMENTATION REFINEMENT IMPORTS USES INITIALISATION INVARIANT PROMOTES PROPERTIES REFINES SETS VALUES VARIANT VISIBLE_CONSTANTS VISIBLE_VARIABLES THEORY XLS THEOREMS LOCAL_OPERATIONS
syn keyword bLabel		CASE IN EITHER OR CHOICE DO OF
syn keyword bConditional	IF ELSE SELECT ELSIF THEN WHEN
syn keyword bRepeat		WHILE FOR
syn keyword bOps		bool card conc closure closure1 dom first fnc front not or id inter iseq iseq1 iterate last max min mod perm pred prj1 prj2 ran rel rev seq seq1 size skip succ tail union
syn keyword bKeywords		LET VAR BE IN BEGIN END  POW POW1 FIN FIN1  PRE  SIGMA STRING UNION IS ANY WHERE

syn keyword bBoolean	TRUE FALSE bfalse btrue
syn keyword bConstant	PI MAXINT MININT User_Pass PatchProver PatchProverH0 PatchProverB0 FLAT ARI DED SUB RES
syn keyword bGuard binhyp band bnot bguard bsearch bflat bfresh bguardi bget bgethyp barith bgetresult bresult bgoal bmatch bmodr bnewv  bnum btest bpattern bprintf bwritef bsubfrm  bvrb blvar bcall bappend bclose

syn keyword bLogic	or not
syn match bLogic	"\(!\|#\|%\|&\|+->>\|+->\|-->>\|->>\|-->\|->\|/:\|/<:\|/<<:\|/=\|/\\\|/|\\\|::\|:\|;:\|<+\|<->\|<--\|<-\|<:\|<<:\|<<|\|<=>\|<|\|==\|=>\|>+>>\|>->\|>+>\|||\||->\)"
syn match bNothing      /:=/

syn keyword cTodo contained	TODO FIXME XXX

" String and Character constants
" Highlight special characters (those which have a backslash) differently
syn match bSpecial contained	"\\[0-7][0-7][0-7]\=\|\\."
syn region bString		start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=bSpecial
syn match bCharacter		"'[^\\]'"
syn match bSpecialCharacter	"'\\.'"
syn match bSpecialCharacter	"'\\[0-7][0-7]'"
syn match bSpecialCharacter	"'\\[0-7][0-7][0-7]'"

"catch errors caused by wrong parenthesis
syn region bParen		transparent start='(' end=')' contains=ALLBUT,bParenError,bIncluded,bSpecial,bTodo,bUserLabel,bBitField
syn match bParenError		")"
syn match bInParen contained	"[{}]"

"integer number, or floating point number without a dot and with "f".
syn case ignore
syn match bNumber		"\<[0-9]\+\>"
"syn match bIdentifier	"\<[a-z_][a-z0-9_]*\>"
syn case match

  syn region bComment		start="/\*" end="\*/" contains=bTodo
  syn match bComment		"//.*" contains=bTodo
syntax match bCommentError	"\*/"

syn keyword bType		INT INTEGER BOOL NAT NATURAL NAT1 NATURAL1

syn region bPreCondit	start="^\s*#\s*\(if\>\|ifdef\>\|ifndef\>\|elif\>\|else\>\|endif\>\)" skip="\\$" end="$" contains=bComment,bString,bCharacter,bNumber,bCommentError
syn region bIncluded contained start=+"+ skip=+\\\\\|\\"+ end=+"+
syn match bIncluded contained "<[^>]*>"
syn match bInclude		"^\s*#\s*include\>\s*["<]" contains=bIncluded

syn region bDefine		start="^\s*#\s*\(define\>\|undef\>\)" skip="\\$" end="$" contains=ALLBUT,bPreCondit,bIncluded,bInclude,bDefine,bInParen
syn region bPreProc		start="^\s*#\s*\(pragma\>\|line\>\|warning\>\|warn\>\|error\>\)" skip="\\$" end="$" contains=ALLBUT,bPreCondit,bIncluded,bInclude,bDefine,bInParen

syn sync ccomment bComment minlines=10

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet

if version >= 508 || !exists("did_b_syntax_inits")
   if version < 508
      let did_b_syntax_inits = 1
      command -nargs=+ HiLink hi link <args>
   else
      command -nargs=+ HiLink hi def link <args>
   endif

  " The default methods for highlighting.  Can be overridden later
  HiLink bLabel	Label
  HiLink bUserLabel	Label
  HiLink bConditional	Conditional
  HiLink bRepeat	Repeat
  HiLink bLogic	Special
  HiLink bCharacter	Character
  HiLink bSpecialCharacter bSpecial
  HiLink bNumber	Number
  HiLink bFloat	Float
  HiLink bOctalError	bError
  HiLink bParenError	bError
" HiLink bInParen	bError
  HiLink bCommentError	bError
  HiLink bBoolean	Identifier
  HiLink bConstant	Identifier
  HiLink bGuard	Identifier
  HiLink bOperator	Operator
  HiLink bKeywords	Operator
  HiLink bOps		Identifier
  HiLink bStructure	Structure
  HiLink bStorageClass	StorageClass
  HiLink bInclude	Include
  HiLink bPreProc	PreProc
  HiLink bDefine	Macro
  HiLink bIncluded	bString
  HiLink bError	Error
  HiLink bStatement	Statement
  HiLink bPreCondit	PreCondit
  HiLink bType		Type
  HiLink bCommentError	bError
  HiLink bCommentString bString
  HiLink bComment2String bString
  HiLink bCommentSkip	bComment
  HiLink bString	String
  HiLink bComment	Comment
  HiLink bSpecial	SpecialChar
  HiLink bTodo		Todo
  "hi link bIdentifier	Identifier
  delcommand HiLink
endif

let b:current_syntax = "b"

" vim: ts=8
