" Vim syntax file
" Language:		lace
" Maintainer:	Jocelyn Fiat <utilities@eiffel.com>
" Last Change:	2001 May 09

" Copyright Interactive Software Engineering, 1998
" You are free to use this file as you please, but
" if you make a change or improvement you must send
" it to the maintainer at <utilities@eiffel.com>


" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" LACE is case insensitive, but the style guide lines are not.

if !exists("lace_case_insensitive")
	syn case match
else
	syn case ignore
endif

" A bunch of useful LACE keywords
syn keyword laceTopStruct		system root default option visible cluster
syn keyword laceTopStruct		external generate end
syn keyword laceOptionClause	collect assertion debug optimize trace
syn keyword laceOptionClause	profile inline precompiled multithreaded
syn keyword laceOptionClause	exception_trace dead_code_removal
syn keyword laceOptionClause	array_optimization
syn keyword laceOptionClause	inlining_size inlining
syn keyword laceOptionClause	console_application dynamic_runtime
syn keyword laceOptionClause	line_generation
syn keyword laceOptionMark		yes no all
syn keyword laceOptionMark		require ensure invariant loop check
syn keyword laceClusterProp		use include exclude
syn keyword laceAdaptClassName	adapt ignore rename as
syn keyword laceAdaptClassName	creation export visible
syn keyword laceExternal		include_path object makefile

" Operators
syn match   laceOperator		"\$"
syn match   laceBrackets		"[[\]]"
syn match   laceExport			"[{}]"

" Constants
syn keyword laceBool		true false
syn keyword laceBool		True False
syn region  laceString		start=+"+ skip=+%"+ end=+"+ contains=laceEscape,laceStringError
syn match   laceEscape		contained "%[^/]"
syn match   laceEscape		contained "%/\d\+/"
syn match   laceEscape		contained "^[ \t]*%"
syn match   laceEscape		contained "%[ \t]*$"
syn match   laceStringError	contained "%/[^0-9]"
syn match   laceStringError	contained "%/\d\+[^0-9/]"
syn match   laceStringError	"'\(%[^/]\|%/\d\+/\|[^'%]\)\+'"
syn match   laceCharacter	"'\(%[^/]\|%/\d\+/\|[^'%]\)'" contains=laceEscape
syn match   laceNumber		"-\=\<\d\+\(_\d\+\)*\>"
syn match   laceNumber		"\<[01]\+[bB]\>"
syn match   laceNumber		"-\=\<\d\+\(_\d\+\)*\.\(\d\+\(_\d\+\)*\)\=\([eE][-+]\=\d\+\(_\d\+\)*\)\="
syn match   laceNumber		"-\=\.\d\+\(_\d\+\)*\([eE][-+]\=\d\+\(_\d\+\)*\)\="
syn match   laceComment		"--.*" contains=laceTodo


syn case match

" Case sensitive stuff

syn keyword laceTodo		TODO XXX FIXME
syn match	laceClassName	"\<[A-Z][A-Z0-9_]*\>"
syn match	laceCluster		"[a-zA-Z][a-zA-Z0-9_]*\s*:"
syn match	laceCluster		"[a-zA-Z][a-zA-Z0-9_]*\s*(\s*[a-zA-Z][a-zA-Z0-9_]*\s*)\s*:"

" Catch mismatched parentheses
syn match laceParenError	")"
syn match laceBracketError	"\]"
syn region laceGeneric		transparent matchgroup=laceBrackets start="\[" end="\]" contains=ALLBUT,laceBracketError
syn region laceParen		transparent start="(" end=")" contains=ALLBUT,laceParenError

" Should suffice for even very long strings and expressions
syn sync lines=40

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link laceTopStruct			PreProc

hi def link laceOptionClause		Statement
hi def link laceOptionMark			Constant
hi def link laceClusterProp		Label
hi def link laceAdaptClassName		Label
hi def link laceExternal			Statement
hi def link laceCluster			ModeMsg

hi def link laceEscape				Special

hi def link laceBool				Boolean
hi def link laceString				String
hi def link laceCharacter			Character
hi def link laceClassName			Type
hi def link laceNumber				Number

hi def link laceOperator			Special
hi def link laceArray				Special
hi def link laceExport				Special
hi def link laceCreation			Special
hi def link laceBrackets			Special
hi def link laceConstraint			Special

hi def link laceComment			Comment

hi def link laceError				Error
hi def link laceStringError		Error
hi def link laceParenError			Error
hi def link laceBracketError		Error
hi def link laceTodo				Todo


let b:current_syntax = "lace"

" vim: ts=4
