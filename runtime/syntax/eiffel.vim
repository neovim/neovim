" Eiffel syntax file
" Language:	Eiffel
" Maintainer: Jocelyn Fiat <jfiat@eiffel.com>
" Previous maintainer:	Reimer Behrends <behrends@cse.msu.edu>
" Contributions from: Thilo Six
" 
" URL: https://github.com/eiffelhub/vim-eiffel
" quit when a syntax file was already loaded
if exists("b:current_syntax")
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
" Only when an item doesn't have highlighting yet

hi def link eiffelKeyword		Statement
hi def link eiffelProperty		Statement
hi def link eiffelInheritClause	Statement
hi def link eiffelStatement	Statement
hi def link eiffelDeclaration	Statement
hi def link eiffelAssertion	Statement
hi def link eiffelDebug		Statement
hi def link eiffelException	Statement
hi def link eiffelGenericCreate	Statement

hi def link eiffelAgent		Statement
hi def link eiffelConvert		Statement

hi def link eiffelTopStruct	PreProc

hi def link eiffelAll		Special
hi def link eiffelAnchored		Special
hi def link eiffelBitType		Special


hi def link eiffelBool		Boolean
hi def link eiffelString		String
hi def link eiffelCharacter	Character
hi def link eiffelClassName	Type
hi def link eiffelNumber		Number

hi def link eiffelStringEscape	Special

hi def link eiffelOperator		Special
hi def link eiffelArray		Special
hi def link eiffelExport		Special
hi def link eiffelCreation		Special
hi def link eiffelBrackets		Special
hi def link eiffelGeneric		Special
hi def link eiffelGenericDecl	Special
hi def link eiffelConstraint	Special
hi def link eiffelCreate		Special

hi def link eiffelPredefined	Constant

hi def link eiffelComment		Comment

hi def link eiffelError		Error
hi def link eiffelBadConstant	Error
hi def link eiffelStringError	Error
hi def link eiffelParenError	Error
hi def link eiffelBracketError	Error

hi def link eiffelTodo		Todo


let b:current_syntax = "eiffel"

let &cpo = s:keepcpo
unlet s:keepcpo

" vim: ts=8
