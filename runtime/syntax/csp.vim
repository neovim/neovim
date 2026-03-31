" Vim syntax file
" Language:	CSP (Communication Sequential Processes, using FDR input syntax)
" Maintainer:	Jan Bredereke <brederek@tzi.de>
" Version:	0.6.0
" Last change:	Mon Mar 25, 2002
" URL:		http://www.tzi.de/~brederek/vim/
" Copying:	You may distribute and use this file freely, in the same
"		way as the vim editor itself.
"
" To Do:	- Probably I missed some keywords or operators, please
"		  fix them and notify me, the maintainer.
"		- Currently, we do lexical highlighting only. It would be
"		  nice to have more actual syntax checks, including
"		  highlighting of wrong syntax.
"		- The additional syntax for the RT-Tester (pseudo-comments)
"		  should be optional.

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" case is significant to FDR:
syn case match

" Block comments in CSP are between {- and -}
syn region cspComment	start="{-"  end="-}" contains=cspTodo
" Single-line comments start with --
syn region cspComment	start="--"  end="$" contains=cspTodo,cspOldRttComment,cspSdlRttComment keepend

" Numbers:
syn match  cspNumber "\<\d\+\>"

" Conditionals:
syn keyword  cspConditional if then else

" Operators on processes:
" -> ? : ! ' ; /\ \ [] |~| [> & [[..<-..]] ||| [|..|] || [..<->..] ; : @ |||
syn match  cspOperator "->"
syn match  cspOperator "/\\"
syn match  cspOperator "[^/]\\"lc=1
syn match  cspOperator "\[\]"
syn match  cspOperator "|\~|"
syn match  cspOperator "\[>"
syn match  cspOperator "\[\["
syn match  cspOperator "\]\]"
syn match  cspOperator "<-"
syn match  cspOperator "|||"
syn match  cspOperator "[^|]||[^|]"lc=1,me=e-1
syn match  cspOperator "[^|{\~]|[^|}\~]"lc=1,me=e-1
syn match  cspOperator "\[|"
syn match  cspOperator "|\]"
syn match  cspOperator "\[[^>]"me=e-1
syn match  cspOperator "\]"
syn match  cspOperator "<->"
syn match  cspOperator "[?:!';@]"
syn match  cspOperator "&"
syn match  cspOperator "\."

" (not on processes:)
" syn match  cspDelimiter	"{|"
" syn match  cspDelimiter	"|}"
" syn match  cspDelimiter	"{[^-|]"me=e-1
" syn match  cspDelimiter	"[^-|]}"lc=1

" Keywords:
syn keyword cspKeyword		length null head tail concat elem
syn keyword cspKeyword		union inter diff Union Inter member card
syn keyword cspKeyword		empty set Set Seq
syn keyword cspKeyword		true false and or not within let
syn keyword cspKeyword		nametype datatype diamond normal
syn keyword cspKeyword		sbisim tau_loop_factor model_compress
syn keyword cspKeyword		explicate
syn match cspKeyword		"transparent"
syn keyword cspKeyword		external chase prioritize
syn keyword cspKeyword		channel Events
syn keyword cspKeyword		extensions productions
syn keyword cspKeyword		Bool Int

" Reserved keywords:
syn keyword cspReserved		attribute embed module subtype

" Include:
syn region cspInclude matchgroup=cspIncludeKeyword start="^include" end="$" keepend contains=cspIncludeArg
syn region cspIncludeArg start='\s\+\"' end= '\"\s*' contained

" Assertions:
syn keyword cspAssert		assert deterministic divergence free deadlock
syn keyword cspAssert		livelock
syn match cspAssert		"\[T="
syn match cspAssert		"\[F="
syn match cspAssert		"\[FD="
syn match cspAssert		"\[FD\]"
syn match cspAssert		"\[F\]"

" Types and Sets
" (first char a capital, later at least one lower case, no trailing underscore):
syn match cspType     "\<_*[A-Z][A-Z_0-9]*[a-z]\(\|[A-Za-z_0-9]*[A-Za-z0-9]\)\>"

" Processes (all upper case, no trailing underscore):
" (For identifiers that could be types or sets, too, this second rule set
" wins.)
syn match cspProcess		"\<[A-Z_][A-Z_0-9]*[A-Z0-9]\>"
syn match cspProcess		"\<[A-Z_]\>"

" reserved identifiers for tool output (ending in underscore):
syn match cspReservedIdentifier	"\<[A-Za-z_][A-Za-z_0-9]*_\>"

" ToDo markers:
syn match cspTodo		"FIXME"	contained
syn match cspTodo		"TODO"	contained
syn match cspTodo		"!!!"	contained

" RT-Tester pseudo comments:
" (The now obsolete syntax:)
syn match cspOldRttComment	"^--\$\$AM_UNDEF"lc=2		contained
syn match cspOldRttComment	"^--\$\$AM_ERROR"lc=2		contained
syn match cspOldRttComment	"^--\$\$AM_WARNING"lc=2		contained
syn match cspOldRttComment	"^--\$\$AM_SET_TIMER"lc=2	contained
syn match cspOldRttComment	"^--\$\$AM_RESET_TIMER"lc=2	contained
syn match cspOldRttComment	"^--\$\$AM_ELAPSED_TIMER"lc=2	contained
syn match cspOldRttComment	"^--\$\$AM_OUTPUT"lc=2		contained
syn match cspOldRttComment	"^--\$\$AM_INPUT"lc=2		contained
" (The current syntax:)
syn region cspRttPragma matchgroup=cspRttPragmaKeyword start="^pragma\s\+" end="\s*$" oneline keepend contains=cspRttPragmaArg,cspRttPragmaSdl
syn keyword cspRttPragmaArg	AM_ERROR AM_WARNING AM_SET_TIMER contained
syn keyword cspRttPragmaArg	AM_RESET_TIMER AM_ELAPSED_TIMER  contained
syn keyword cspRttPragmaArg	AM_OUTPUT AM_INPUT AM_INTERNAL   contained
" the "SDL_MATCH" extension:
syn region cspRttPragmaSdl	matchgroup=cspRttPragmaKeyword start="SDL_MATCH\s\+" end="\s*$" contains=cspRttPragmaSdlArg contained
syn keyword cspRttPragmaSdlArg	TRANSLATE nextgroup=cspRttPragmaSdlTransName contained
syn keyword cspRttPragmaSdlArg	PARAM SKIP OPTIONAL CHOICE ARRAY nextgroup=cspRttPragmaSdlName contained
syn match cspRttPragmaSdlName	"\s*\S\+\s*" nextgroup=cspRttPragmaSdlTail contained
syn region cspRttPragmaSdlTail  start="" end="\s*$" contains=cspRttPragmaSdlTailArg contained
syn keyword cspRttPragmaSdlTailArg	SUBSET_USED DEFAULT_VALUE Present contained
syn match cspRttPragmaSdlTransName	"\s*\w\+\s*" nextgroup=cspRttPragmaSdlTransTail contained
syn region cspRttPragmaSdlTransTail  start="" end="\s*$" contains=cspRttPragmaSdlTransTailArg contained
syn keyword cspRttPragmaSdlTransTailArg	sizeof contained
syn match cspRttPragmaSdlTransTailArg	"\*" contained
syn match cspRttPragmaSdlTransTailArg	"(" contained
syn match cspRttPragmaSdlTransTailArg	")" contained

" temporary syntax extension for commented-out "pragma SDL_MATCH":
syn match cspSdlRttComment	"pragma\s\+SDL_MATCH\s\+" nextgroup=cspRttPragmaSdlArg contained

syn sync lines=250

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

" The default methods for highlighting.  Can be overridden later
" (For vim version <=5.7, the command groups are defined in
" $VIMRUNTIME/syntax/synload.vim )
hi def link cspComment			Comment
hi def link cspNumber			Number
hi def link cspConditional			Conditional
hi def link cspOperator			Delimiter
hi def link cspKeyword			Keyword
hi def link cspReserved			SpecialChar
hi def link cspInclude			Error
hi def link cspIncludeKeyword		Include
hi def link cspIncludeArg			Include
hi def link cspAssert			PreCondit
hi def link cspType			Type
hi def link cspProcess			Function
hi def link cspTodo			Todo
hi def link cspOldRttComment		Define
hi def link cspRttPragmaKeyword		Define
hi def link cspSdlRttComment		Define
hi def link cspRttPragmaArg		Define
hi def link cspRttPragmaSdlArg		Define
hi def link cspRttPragmaSdlName		Default
hi def link cspRttPragmaSdlTailArg		Define
hi def link cspRttPragmaSdlTransName	Default
hi def link cspRttPragmaSdlTransTailArg	Define
hi def link cspReservedIdentifier	Error
" (Currently unused vim method: Debug)


let b:current_syntax = "csp"

" vim: ts=8
