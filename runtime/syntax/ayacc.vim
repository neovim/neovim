" Vim syntax file
" Language:	AYacc
" Maintainer:	Mathieu Clabaut <mathieu.clabaut@free.fr>
" LastChange:	2011 Dec 25
" Original:	Yacc, maintained by Dr. Charles E. Campbell, Jr.
" Comment:	     Replaced sourcing c.vim file by ada.vim and rename yacc*
"		in ayacc*

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
   syntax clear
elseif exists("b:current_syntax")
   finish
endif

" Read the Ada syntax to start with
if version < 600
   so <sfile>:p:h/ada.vim
else
   runtime! syntax/ada.vim
   unlet b:current_syntax
endif

let s:cpo_save = &cpo
set cpo&vim

" Clusters
syn cluster	ayaccActionGroup	contains=ayaccDelim,cInParen,cTodo,cIncluded,ayaccDelim,ayaccCurlyError,ayaccUnionCurly,ayaccUnion,cUserLabel,cOctalZero,cCppOut2,cCppSkip,cErrInBracket,cErrInParen,cOctalError
syn cluster	ayaccUnionGroup	contains=ayaccKey,cComment,ayaccCurly,cType,cStructure,cStorageClass,ayaccUnionCurly

" Yacc stuff
syn match	ayaccDelim	"^[ \t]*[:|;]"
syn match	ayaccOper	"@\d\+"

syn match	ayaccKey	"^[ \t]*%\(token\|type\|left\|right\|start\|ident\)\>"
syn match	ayaccKey	"[ \t]%\(prec\|expect\|nonassoc\)\>"
syn match	ayaccKey	"\$\(<[a-zA-Z_][a-zA-Z_0-9]*>\)\=[\$0-9]\+"
syn keyword	ayaccKeyActn	yyerrok yyclearin

syn match	ayaccUnionStart	"^%union"	skipwhite skipnl nextgroup=ayaccUnion
syn region	ayaccUnion	contained matchgroup=ayaccCurly start="{" matchgroup=ayaccCurly end="}"	contains=@ayaccUnionGroup
syn region	ayaccUnionCurly	contained matchgroup=ayaccCurly start="{" matchgroup=ayaccCurly end="}" contains=@ayaccUnionGroup
syn match	ayaccBrkt	contained "[<>]"
syn match	ayaccType	"<[a-zA-Z_][a-zA-Z0-9_]*>"	contains=ayaccBrkt
syn match	ayaccDefinition	"^[A-Za-z][A-Za-z0-9_]*[ \t]*:"

" special Yacc separators
syn match	ayaccSectionSep	"^[ \t]*%%"
syn match	ayaccSep	"^[ \t]*%{"
syn match	ayaccSep	"^[ \t]*%}"

" I'd really like to highlight just the outer {}.  Any suggestions???
syn match	ayaccCurlyError	"[{}]"
syn region	ayaccAction	matchgroup=ayaccCurly start="{" end="}" contains=ALLBUT,@ayaccActionGroup

if version >= 508 || !exists("did_ayacc_syntax_inits")
   if version < 508
      let did_ayacc_syntax_inits = 1
      command -nargs=+ HiLink hi link <args>
   else
      command -nargs=+ HiLink hi def link <args>
   endif

  " Internal ayacc highlighting links
  HiLink ayaccBrkt	ayaccStmt
  HiLink ayaccKey	ayaccStmt
  HiLink ayaccOper	ayaccStmt
  HiLink ayaccUnionStart	ayaccKey

  " External ayacc highlighting links
  HiLink ayaccCurly	Delimiter
  HiLink ayaccCurlyError	Error
  HiLink ayaccDefinition	Function
  HiLink ayaccDelim	Function
  HiLink ayaccKeyActn	Special
  HiLink ayaccSectionSep	Todo
  HiLink ayaccSep	Delimiter
  HiLink ayaccStmt	Statement
  HiLink ayaccType	Type

  " since Bram doesn't like my Delimiter :|
  HiLink Delimiter	Type
  delcommand HiLink
endif

let b:current_syntax = "ayacc"

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: ts=15
