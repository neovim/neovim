" Vim syntax file
" Language:	Property Specification Language (PSL)
" Maintainer:	Daniel Kho <daniel.kho@logik.haus>
" Last Changed:	2021 Apr 17 by Daniel Kho

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Read in VHDL syntax files
runtime! syntax/vhdl.vim
unlet b:current_syntax

let s:cpo_save = &cpo
set cpo&vim

" case is not significant
syn case	ignore

" Add ! character to keyword recognition.
setlocal iskeyword+=33

" PSL keywords
syn keyword	pslOperator	A AF AG AX
syn keyword	pslOperator	E EF EG EX
syn keyword	pslOperator	F G U W X X!
syn keyword	pslOperator	abort always assert assume async_abort
syn keyword	pslOperator	before before! before!_ before_ bit bitvector boolean
syn keyword	pslOperator	clock const countones cover
syn keyword	pslOperator	default
syn keyword	pslOperator	ended eventually!
syn keyword	pslOperator	fairness fell for forall
syn keyword	pslOperator	hdltype
syn keyword	pslOperator	in inf inherit isunknown
syn keyword	pslOperator	mutable
syn keyword	pslOperator	never next next! next_a next_a! next_e next_e! next_event next_event! next_event_a next_event_a! next_event_e next_event_e! nondet nondet_vector numeric
syn keyword	pslOperator	onehot onehot0
syn keyword	pslOperator	property prev
syn keyword	pslOperator	report restrict restrict! rose
syn keyword	pslOperator	sequence stable string strong sync_abort
syn keyword	pslOperator	union until until! until!_ until_
syn keyword	pslOperator	vmode vpkg vprop vunit
syn keyword	pslOperator	within
"" Common keywords with VHDL
"syn keyword	pslOperator	and is not or to

" PSL operators
syn match	pslOperator	"=>\||=>"
syn match	pslOperator	"<-\|->"
syn match	pslOperator	"@"


"Modify the following as needed.  The trade-off is performance versus functionality.
syn sync	minlines=600

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link pslSpecial	    Special
hi def link pslStatement    Statement
hi def link pslCharacter    Character
hi def link pslString	    String
hi def link pslVector	    Number
hi def link pslBoolean	    Number
hi def link pslTodo	    Todo
hi def link pslFixme	    Fixme
hi def link pslComment	    Comment
hi def link pslNumber	    Number
hi def link pslTime	    Number
hi def link pslType	    Type
hi def link pslOperator	    Operator
hi def link pslError	    Error
hi def link pslAttribute    Special
hi def link pslPreProc	    PreProc


let b:current_syntax = "psl"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8
