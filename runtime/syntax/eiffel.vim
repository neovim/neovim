" Eiffel syntax file
" Language:	Eiffel
" Maintainer: Jocelyn Fiat <jfiat@eiffel.com>
" Previous maintainer:	Reimer Behrends <behrends@cse.msu.edu>
" Contributions from: Thilo Six
" 
" URL: https://github.com/eiffelhub/vim-eiffel
" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

let s:keepcpo= &cpo
set cpo&vim

" Option handling

if exists("eiffel_ignore_case")
  syn case ignore
else
  syn case match
  if exists("eiffel_pedantic") || exists("eiffel_strict")
    syn keyword eiffelError	current void result precursor none
    syn keyword eiffelError	CURRENT VOID RESULT PRECURSOR None
    syn keyword eiffelError	TRUE FALSE
  endif
  if exists("eiffel_pedantic")
    syn keyword eiffelError	true false
    syn match eiffelError	"\<[a-z_]\+[A-Z][a-zA_Z_]*\>"
    syn match eiffelError	"\<[A-Z][a-z_]*[A-Z][a-zA-Z_]*\>"
  endif
  if exists("eiffel_lower_case_predef")
    syn keyword eiffelPredefined current void result precursor
  endif
endif

if exists("eiffel_hex_constants")
  syn match  eiffelNumber	"\d[0-9a-fA-F]*[xX]"
endif

" Keyword definitions

syn keyword eiffelTopStruct	note indexing feature creation inherit
syn match   eiffelTopStruct	"\<class\>"
syn match   eiffelKeyword	"\<end\>"
syn match   eiffelTopStruct	"^end\>\(\s*--\s\+class\s\+\<[A-Z][A-Z0-9_]*\>\)\=" contains=eiffelClassName
syn match   eiffelBrackets	"[[\]]"
syn match eiffelBracketError	"\]"
syn region eiffelGeneric	transparent matchgroup=eiffelBrackets start="\[" end="\]" contains=ALLBUT,eiffelBracketError,eiffelGenericDecl,eiffelStringError,eiffelStringEscape,eiffelGenericCreate,eiffelTopStruct
if exists("eiffel_ise")
  syn match   eiffelAgent	"\<agent\>"
  syn match   eiffelConvert	"\<convert\>"
  syn match   eiffelCreate	"\<create\>"
  syn match   eiffelTopStruct	contained "\<create\>"
  syn match   eiffelTopStruct	contained "\<convert\>"
  syn match   eiffelGenericCreate  contained "\<create\>"
  syn match   eiffelTopStruct	"^create\>"
  syn region  eiffelGenericDecl	transparent matchgroup=eiffelBrackets contained start="\[" end="\]" contains=ALLBUT,eiffelCreate,eiffelTopStruct,eiffelGeneric,eiffelBracketError,eiffelStringEscape,eiffelStringError,eiffelBrackets
  syn region  eiffelClassHeader	start="^class\>" end="$" contains=ALLBUT,eiffelCreate,eiffelGenericCreate,eiffelGeneric,eiffelStringEscape,eiffelStringError,eiffelBrackets
endif
syn keyword eiffelDeclaration	is do once deferred unique local attribute assign
syn keyword eiffelDeclaration	attached detachable Unique
syn keyword eiffelProperty	expanded obsolete separate frozen
syn keyword eiffelProperty	prefix infix
syn keyword eiffelInheritClause	rename redefine undefine select export as
syn keyword eiffelAll		all
syn keyword eiffelKeyword	external alias some
syn keyword eiffelStatement	if else elseif inspect
syn keyword eiffelStatement	when then
syn match   eiffelAssertion	"\<require\(\s\+else\)\=\>"
syn match   eiffelAssertion	"\<ensure\(\s\+then\)\=\>"
syn keyword eiffelAssertion	check
syn keyword eiffelDebug		debug
syn keyword eiffelStatement	across from until loop
syn keyword eiffelAssertion	variant
syn match   eiffelAssertion	"\<invariant\>"
syn match   eiffelTopStruct	"^invariant\>"
syn keyword eiffelException	rescue retry

syn keyword eiffelPredefined	Current Void Result Precursor

" Operators
syn match   eiffelOperator	"\<and\(\s\+then\)\=\>"
syn match   eiffelOperator	"\<or\(\s\+else\)\=\>"
syn keyword eiffelOperator	xor implies not
syn keyword eiffelOperator	strip old
syn keyword eiffelOperator	Strip
syn match   eiffelOperator	"\$"
syn match   eiffelCreation	"!"
syn match   eiffelExport	"[{}]"
syn match   eiffelArray		"<<"
syn match   eiffelArray		">>"
syn match   eiffelConstraint	"->"
syn match   eiffelOperator	"[@#|&][^ \e\t\b%]*"

" Special classes
syn keyword eiffelAnchored	like
syn keyword eiffelBitType	BIT

" Constants
if !exists("eiffel_pedantic")
  syn keyword eiffelBool	true false
endif
syn keyword eiffelBool		True False
syn region  eiffelString	start=+"+ skip=+%"+ end=+"+ contains=eiffelStringEscape,eiffelStringError
syn match   eiffelStringEscape	contained "%[^/]"
syn match   eiffelStringEscape	contained "%/\d\+/"
syn match   eiffelStringEscape	contained "^[ \t]*%"
syn match   eiffelStringEscape	contained "%[ \t]*$"
syn match   eiffelStringError	contained "%/[^0-9]"
syn match   eiffelStringError	contained "%/\d\+[^0-9/]"
syn match   eiffelBadConstant	"'\(%[^/]\|%/\d\+/\|[^'%]\)\+'"
syn match   eiffelBadConstant	"''"
syn match   eiffelCharacter	"'\(%[^/]\|%/\d\+/\|[^'%]\)'" contains=eiffelStringEscape
syn match   eiffelNumber	"-\=\<\d\+\(_\d\+\)*\>"
syn match   eiffelNumber	"\<[01]\+[bB]\>"
syn match   eiffelNumber	"-\=\<\d\+\(_\d\+\)*\.\(\d\+\(_\d\+\)*\)\=\([eE][-+]\=\d\+\(_\d\+\)*\)\="
syn match   eiffelNumber	"-\=\.\d\+\(_\d\+\)*\([eE][-+]\=\d\+\(_\d\+\)*\)\="
syn match   eiffelComment	"--.*" contains=eiffelTodo

syn case match

" Case sensitive stuff

syn keyword eiffelTodo		contained TODO XXX FIXME
syn match   eiffelClassName	"\<[A-Z][A-Z0-9_]*\>"

" Catch mismatched parentheses
syn match eiffelParenError	")"
syn region eiffelParen		transparent start="(" end=")" contains=ALLBUT,eiffelParenError,eiffelStringError,eiffelStringEscape

if exists("eiffel_fold")
"    setlocal foldmethod=indent
"    syn sync fromstart
endif

" Should suffice for even very long strings and expressions
syn sync lines=40

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_eiffel_syntax_inits")
  if version < 508
    let did_eiffel_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink eiffelKeyword		Statement
  HiLink eiffelProperty		Statement
  HiLink eiffelInheritClause	Statement
  HiLink eiffelStatement	Statement
  HiLink eiffelDeclaration	Statement
  HiLink eiffelAssertion	Statement
  HiLink eiffelDebug		Statement
  HiLink eiffelException	Statement
  HiLink eiffelGenericCreate	Statement

  HiLink eiffelAgent		Statement
  HiLink eiffelConvert		Statement

  HiLink eiffelTopStruct	PreProc

  HiLink eiffelAll		Special
  HiLink eiffelAnchored		Special
  HiLink eiffelBitType		Special


  HiLink eiffelBool		Boolean
  HiLink eiffelString		String
  HiLink eiffelCharacter	Character
  HiLink eiffelClassName	Type
  HiLink eiffelNumber		Number

  HiLink eiffelStringEscape	Special

  HiLink eiffelOperator		Special
  HiLink eiffelArray		Special
  HiLink eiffelExport		Special
  HiLink eiffelCreation		Special
  HiLink eiffelBrackets		Special
  HiLink eiffelGeneric		Special
  HiLink eiffelGenericDecl	Special
  HiLink eiffelConstraint	Special
  HiLink eiffelCreate		Special

  HiLink eiffelPredefined	Constant

  HiLink eiffelComment		Comment

  HiLink eiffelError		Error
  HiLink eiffelBadConstant	Error
  HiLink eiffelStringError	Error
  HiLink eiffelParenError	Error
  HiLink eiffelBracketError	Error

  HiLink eiffelTodo		Todo

  delcommand HiLink
endif

let b:current_syntax = "eiffel"

let &cpo = s:keepcpo
unlet s:keepcpo

" vim: ts=8
