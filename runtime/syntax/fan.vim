" Vim syntax file
" Language:     Fantom
" Maintainer:   Kamil Toman <kamil.toman@gmail.com>
" Last Change:  2010 May 27
" Based on Java syntax file by Claudio Fleiner <claudio@fleiner.com>

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" keyword definitions
syn keyword fanExternal	        using native
syn keyword fanError		goto void serializable volatile
syn keyword fanConditional	if else switch
syn keyword fanRepeat		do while for foreach each
syn keyword fanBoolean		true false
syn keyword fanConstant 	null
syn keyword fanTypedef		this super
syn keyword fanOperator	        new is isnot as
syn keyword fanLongOperator     plus minus mult div mod get set slice lshift rshift and or xor inverse negate increment decrement equals compare
syn keyword fanType		Void Bool Int Float Decimal Str Duration Uri Type Range List Map Obj
syn keyword fanStatement	return
syn keyword fanStorageClass	static const final
syn keyword fanSlot      	virtual override once
syn keyword fanField      	readonly
syn keyword fanExceptions	throw try catch finally
syn keyword fanAssert		assert
syn keyword fanTypedef		class enum mixin
syn match   fanFacet            "@[_a-zA-Z][_a-zA-Z0-9_]*\>"
syn keyword fanBranch		break continue
syn keyword fanScopeDecl	public internal protected private abstract

if exists("fan_space_errors")
  if !exists("fan_no_trail_space_error")
    syn match   fanSpaceError  "\s\+$"
  endif
  if !exists("fan_no_tab_space_error")
    syn match   fanSpaceError  " \+\t"me=e-1
  endif
endif

syn region  fanLabelRegion     transparent matchgroup=fanLabel start="\<case\>" matchgroup=NONE end=":" contains=fanNumber,fanCharacter
syn keyword fanLabel		default
syn keyword fanLabel		case

" The following cluster contains all fan groups except the contained ones
syn cluster fanTop add=fanExternal,fanError,fanConditional,fanRepeat,fanBoolean,fanConstant,fanTypedef,fanOperator,fanLongOperator,fanType,fanType,fanStatement,fanStorageClass,fanSlot,fanField,fanExceptions,fanAssert,fanClassDecl,fanTypedef,fanFacet,fanBranch,fanScopeDecl,fanLabelRegion,fanLabel

" Comments
syn keyword fanTodo		 contained TODO FIXME XXX
syn region  fanComment		 start="/\*"  end="\*/" contains=@fanCommentSpecial,fanTodo,fanComment,@Spell
syn match   fanCommentStar      contained "^\s*\*[^/]"me=e-1
syn match   fanCommentStar      contained "^\s*\*$"
syn match   fanLineComment      "//.*" contains=@fanCommentSpecial2,fanTodo,@Spell
syn match   fanDocComment       "\*\*.*" contains=@fanCommentSpecial2,fanTodo,@Spell
hi def link fanCommentString fanString
hi def link fanComment2String fanString
hi def link fanCommentCharacter fanCharacter

syn cluster fanTop add=fanComment,fanLineComment,fanDocComment

" match the special comment /**/
syn match   fanComment		 "/\*\*/"

" Strings and constants
syn match   fanSpecialError    	 	contained "\\."
syn match   fanSpecialCharError 	contained "[^']"
syn match   fanSpecialChar      	contained "\\\([4-9]\d\|[0-3]\d\d\|[\"\\'ntbrf]\|u\x\{4\}\|\$\)"
syn match   fanStringSubst      	contained "\$[A-Za-z][A-Za-z_.]*"
syn match   fanStringSubst      	contained "\${[^}]*}"
syn region  fanString		start=+"+ end=+"+ contains=fanSpecialChar,fanSpecialError,fanStringSubst,@Spell
syn region  fanTripleString	start=+"""+ end=+"""+ contains=fanSpecialChar,fanSpecialError,fanStringSubst,@Spell
syn region  fanDSL		start=+<|+ end=+|>+ 
syn match   fanUri		 "`[^`]*`"
syn match   fanCharacter	 "'[^']*'" contains=fanSpecialChar,fanSpecialCharError
syn match   fanCharacter	 "'\\''" contains=fanSpecialChar
syn match   fanCharacter	 "'[^\\]'"
syn match   fanNumber		 "\<\(0[0-7]*\|0[xX]\x\+\|\d\+\)[lL]\=\>"
syn match   fanNumber		 "\(\<\d\+\.\d*\|\.\d\+\)\([eE][-+]\=\d\+\)\=[fFdD]\="
syn match   fanNumber		 "\<\d\+[eE][-+]\=\d\+[fFdD]\=\>"
syn match   fanNumber		 "\<\d\+\([eE][-+]\=\d\+\)\=[fFdD]\>"

syn cluster fanTop add=fanString,fanCharacter,fanNumber,fanSpecial,fanStringError

" The default highlighting.
hi def link fanBranch			Conditional
hi def link fanLabel			Label
hi def link fanUserLabel		Label
hi def link fanConditional		Conditional
hi def link fanRepeat			Repeat
hi def link fanExceptions		Exception
hi def link fanAssert			Statement
hi def link fanStorageClass		StorageClass
hi def link fanSlot        		StorageClass
hi def link fanField        		StorageClass
hi def link fanScopeDecl		StorageClass
hi def link fanBoolean		Boolean
hi def link fanSpecial		Special
hi def link fanSpecialError		Error
hi def link fanSpecialCharError	Error
hi def link fanTripleString		String
hi def link fanString			String
hi def link fanDSL			String
hi def link fanCharacter		String
hi def link fanStringSubst		Identifier
hi def link fanUri			SpecialChar
hi def link fanSpecialChar		SpecialChar
hi def link fanNumber			Number
hi def link fanError			Error
hi def link fanStringError		Error
hi def link fanStatement		Statement
hi def link fanOperator		Operator
hi def link fanLongOperator		Operator
hi def link fanComment		Comment
hi def link fanDocComment		Comment
hi def link fanLineComment		Comment
hi def link fanConstant		Constant
hi def link fanTypedef		Typedef
hi def link fanTodo			Todo
hi def link fanFacet                  PreProc

hi def link fanCommentTitle		SpecialComment
hi def link fanCommentStar		SpecialComment
hi def link fanType			Identifier
hi def link fanExternal		Include

hi def link fanSpaceError		Error

let b:current_syntax = "fan"

" vim: ts=8
