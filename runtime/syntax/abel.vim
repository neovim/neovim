" Vim syntax file
" Language:	ABEL
" Maintainer:	John Cook <johncook3@gmail.com>
" Last Change:	2011 Dec 27

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" this language is oblivious to case
syn case ignore

" A bunch of keywords
syn keyword abelHeader		module title device options
syn keyword abelSection		declarations equations test_vectors end
syn keyword abelDeclaration	state truth_table state_diagram property
syn keyword abelType		pin node attribute constant macro library

syn keyword abelTypeId		com reg neg pos buffer dc reg_d reg_t contained
syn keyword abelTypeId		reg_sr reg_jk reg_g retain xor invert contained

syn keyword abelStatement	when then else if with endwith case endcase
syn keyword abelStatement	fuses expr trace

" option to omit obsolete statements
if exists("abel_obsolete_ok")
  syn keyword abelStatement enable flag in
else
  syn keyword abelError enable flag in
endif

" directives
syn match abelDirective "@alternate"
syn match abelDirective "@standard"
syn match abelDirective "@const"
syn match abelDirective "@dcset"
syn match abelDirective "@include"
syn match abelDirective "@page"
syn match abelDirective "@radix"
syn match abelDirective "@repeat"
syn match abelDirective "@irp"
syn match abelDirective "@expr"
syn match abelDirective "@if"
syn match abelDirective "@ifb"
syn match abelDirective "@ifnb"
syn match abelDirective "@ifdef"
syn match abelDirective "@ifndef"
syn match abelDirective "@ifiden"
syn match abelDirective "@ifniden"

syn keyword abelTodo contained TODO XXX FIXME

" wrap up type identifiers to differentiate them from normal strings
syn region abelSpecifier start='istype' end=';' contains=abelTypeIdChar,abelTypeId,abelTypeIdEnd keepend
syn match  abelTypeIdChar "[,']" contained
syn match  abelTypeIdEnd  ";" contained

" string contstants and special characters within them
syn match  abelSpecial contained "\\['\\]"
syn region abelString start=+'+ skip=+\\"+ end=+'+ contains=abelSpecial

" valid integer number formats (decimal, binary, octal, hex)
syn match abelNumber "\<[-+]\=[0-9]\+\>"
syn match abelNumber "\^d[0-9]\+\>"
syn match abelNumber "\^b[01]\+\>"
syn match abelNumber "\^o[0-7]\+\>"
syn match abelNumber "\^h[0-9a-f]\+\>"

" special characters
" (define these after abelOperator so ?= overrides ?)
syn match abelSpecialChar "[\[\](){},;:?]"

" operators
syn match abelLogicalOperator "[!#&$]"
syn match abelRangeOperator "\.\."
syn match abelAlternateOperator "[/*+]"
syn match abelAlternateOperator ":[+*]:"
syn match abelArithmeticOperator "[-%]"
syn match abelArithmeticOperator "<<"
syn match abelArithmeticOperator ">>"
syn match abelRelationalOperator "[<>!=]="
syn match abelRelationalOperator "[<>]"
syn match abelAssignmentOperator "[:?]\=="
syn match abelAssignmentOperator "?:="
syn match abelTruthTableOperator "->"

" signal extensions
syn match abelExtension "\.aclr\>"
syn match abelExtension "\.aset\>"
syn match abelExtension "\.clk\>"
syn match abelExtension "\.clr\>"
syn match abelExtension "\.com\>"
syn match abelExtension "\.fb\>"
syn match abelExtension "\.[co]e\>"
syn match abelExtension "\.l[eh]\>"
syn match abelExtension "\.fc\>"
syn match abelExtension "\.pin\>"
syn match abelExtension "\.set\>"
syn match abelExtension "\.[djksrtq]\>"
syn match abelExtension "\.pr\>"
syn match abelExtension "\.re\>"
syn match abelExtension "\.a[pr]\>"
syn match abelExtension "\.s[pr]\>"

" special constants
syn match abelConstant "\.[ckudfpxz]\."
syn match abelConstant "\.sv[2-9]\."

" one-line comments
syn region abelComment start=+"+ end=+"\|$+ contains=abelNumber,abelTodo
" option to prevent C++ style comments
if !exists("abel_cpp_comments_illegal")
  syn region abelComment start=+//+ end=+$+ contains=abelNumber,abelTodo
endif

syn sync minlines=1

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_abel_syn_inits")
  if version < 508
    let did_abel_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  " The default highlighting.
  HiLink abelHeader		abelStatement
  HiLink abelSection		abelStatement
  HiLink abelDeclaration	abelStatement
  HiLink abelLogicalOperator	abelOperator
  HiLink abelRangeOperator	abelOperator
  HiLink abelAlternateOperator	abelOperator
  HiLink abelArithmeticOperator	abelOperator
  HiLink abelRelationalOperator	abelOperator
  HiLink abelAssignmentOperator	abelOperator
  HiLink abelTruthTableOperator	abelOperator
  HiLink abelSpecifier		abelStatement
  HiLink abelOperator		abelStatement
  HiLink abelStatement		Statement
  HiLink abelIdentifier		Identifier
  HiLink abelTypeId		abelType
  HiLink abelTypeIdChar		abelType
  HiLink abelType		Type
  HiLink abelNumber		abelString
  HiLink abelString		String
  HiLink abelConstant		Constant
  HiLink abelComment		Comment
  HiLink abelExtension		abelSpecial
  HiLink abelSpecialChar	abelSpecial
  HiLink abelTypeIdEnd		abelSpecial
  HiLink abelSpecial		Special
  HiLink abelDirective		PreProc
  HiLink abelTodo		Todo
  HiLink abelError		Error

  delcommand HiLink
endif

let b:current_syntax = "abel"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim:ts=8
