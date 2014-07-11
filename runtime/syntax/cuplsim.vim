" Vim syntax file
" Language:	CUPL simulation
" Maintainer:	John Cook <john.cook@kla-tencor.com>
" Last Change:	2001 Apr 25

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" Read the CUPL syntax to start with
if version < 600
  source <sfile>:p:h/cupl.vim
else
  runtime! syntax/cupl.vim
  unlet b:current_syntax
endif

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
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_cuplsim_syn_inits")
  if version < 508
    let did_cuplsim_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  " append to the highlighting links in cupl.vim
  " The default highlighting.
  HiLink cuplsimOrder		cuplStatement
  HiLink cuplsimBase		cuplStatement
  HiLink cuplsimBaseType	cuplStatement
  HiLink cuplsimVectors		cuplStatement
  HiLink cuplsimStimulus	cuplNumber
  HiLink cuplsimOutput		cuplNumber
  HiLink cuplsimOrderFormat	cuplNumber

  delcommand HiLink
endif

let b:current_syntax = "cuplsim"
" vim:ts=8
