" Vim syntax file
" Language:	bc - An arbitrary precision calculator language
" Maintainer:	Vladimir Scholtz <vlado@gjh.sk>
" Last change:	2012 Jun 01
" 		(Dominique Pelle added @Spell)
" Available on:	www.gjh.sk/~vlado/bc.vim

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn case ignore

" Keywords
syn keyword bcKeyword if else while for break continue return limits halt quit
syn keyword bcKeyword define
syn keyword bcKeyword length read sqrt print

" Variable
syn keyword bcType auto

" Constant
syn keyword bcConstant scale ibase obase last
syn keyword bcConstant BC_BASE_MAX BC_DIM_MAX BC_SCALE_MAX BC_STRING_MAX
syn keyword bcConstant BC_ENV_ARGS BC_LINE_LENGTH

" Any other stuff
syn match bcIdentifier		"[a-z_][a-z0-9_]*"

" String
 syn match bcString		"\"[^"]*\"" contains=@Spell

" Number
syn match bcNumber		"[0-9]\+"

" Comment
syn match bcComment		"\#.*" contains=@Spell
syn region bcComment		start="/\*" end="\*/" contains=@Spell

" Parent ()
syn cluster bcAll contains=bcList,bcIdentifier,bcNumber,bcKeyword,bcType,bcConstant,bcString,bcParentError
syn region bcList		matchgroup=Delimiter start="(" skip="|.\{-}|" matchgroup=Delimiter end=")" contains=@bcAll
syn region bcList		matchgroup=Delimiter start="\[" skip="|.\{-}|" matchgroup=Delimiter end="\]" contains=@bcAll
syn match bcParenError			"]"
syn match bcParenError			")"



syn case match

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_bc_syntax_inits")
  if version < 508
    let did_bc_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink bcKeyword		Statement
  HiLink bcType		Type
  HiLink bcConstant		Constant
  HiLink bcNumber		Number
  HiLink bcComment		Comment
  HiLink bcString		String
  HiLink bcSpecialChar		SpecialChar
  HiLink bcParenError		Error

  delcommand HiLink
endif

let b:current_syntax = "bc"
" vim: ts=8
