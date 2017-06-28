" Vim syntax file
" Language:	CUPL simulation
" Maintainer:	John Cook <john.cook@kla-tencor.com>
" Last Change:	2001 Apr 25

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Read the CUPL syntax to start with
runtime! syntax/cupl.vim
unlet b:current_syntax

" omit definition-specific stuff
syn clear cuplStatement
syn clear cuplFunction
syn clear cuplLogicalOperator
syn clear cuplArithmeticOperator
syn clear cuplAssignmentOperator
syn clear cuplEqualityOperator
syn clear cuplTruthTableOperator
syn clear cuplExtension

" simulation order statement
syn match  cuplsimOrder "order:" nextgroup=cuplsimOrderSpec skipempty
syn region cuplsimOrderSpec start="." end=";"me=e-1 contains=cuplComment,cuplsimOrderFormat,cuplBitVector,cuplSpecialChar,cuplLogicalOperator,cuplCommaOperator contained

" simulation base statement
syn match   cuplsimBase "base:" nextgroup=cuplsimBaseSpec skipempty
syn region  cuplsimBaseSpec start="." end=";"me=e-1 contains=cuplComment,cuplsimBaseType contained
syn keyword cuplsimBaseType octal decimal hex contained

" simulation vectors statement
syn match cuplsimVectors "vectors:"

" simulator format control
syn match cuplsimOrderFormat "%\d\+\>" contained

" simulator control
syn match cuplsimStimulus "[10ckpx]\+"
syn match cuplsimStimulus +'\(\x\|x\)\+'+
syn match cuplsimOutput "[lhznx*]\+"
syn match cuplsimOutput +"\x\+"+

syn sync minlines=1

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

" append to the highlighting links in cupl.vim
" The default highlighting.
hi def link cuplsimOrder		cuplStatement
hi def link cuplsimBase		cuplStatement
hi def link cuplsimBaseType	cuplStatement
hi def link cuplsimVectors		cuplStatement
hi def link cuplsimStimulus	cuplNumber
hi def link cuplsimOutput		cuplNumber
hi def link cuplsimOrderFormat	cuplNumber


let b:current_syntax = "cuplsim"
" vim:ts=8
