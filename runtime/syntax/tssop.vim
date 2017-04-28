" Vim syntax file
" Language:     TSS (Thermal Synthesizer System) Optics
" Maintainer:   Adrian Nagle, anagle@ball.com
" Last Change:  2003 May 11
" Filenames:    *.tssop
" URL:		http://www.naglenet.org/vim/syntax/tssop.vim
" MAIN URL:     http://www.naglenet.org/vim/



" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif



" Ignore case
syn case ignore



"
"
" Begin syntax definitions for tss optics file.
"

" Define keywords for TSS
syn keyword tssopParam  ir_eps ir_trans ir_spec ir_tspec ir_refract
syn keyword tssopParam  sol_eps sol_trans sol_spec sol_tspec sol_refract
syn keyword tssopParam  color

"syn keyword tssopProp   property

syn keyword tssopArgs   white red blue green yellow orange violet pink
syn keyword tssopArgs   turquoise grey black



" Define matches for TSS
syn match  tssopComment       /comment \+= \+".*"/ contains=tssopParam,tssopCommentString
syn match  tssopCommentString /".*"/ contained

syn match  tssopProp	    "property "
syn match  tssopProp	    "edit/optic "
syn match  tssopPropName    "^property \S\+" contains=tssopProp
syn match  tssopPropName    "^edit/optic \S\+$" contains=tssopProp

syn match  tssopInteger     "-\=\<[0-9]*\>"
syn match  tssopFloat       "-\=\<[0-9]*\.[0-9]*"
syn match  tssopScientific  "-\=\<[0-9]*\.[0-9]*E[-+]\=[0-9]\+\>"



" Define the default highlighting
" Only when an item doesn't have highlighting yet
command -nargs=+ HiLink hi def link <args>

HiLink tssopParam		Statement
HiLink tssopProp		Identifier
HiLink tssopArgs		Special

HiLink tssopComment		Statement
HiLink tssopCommentString	Comment
HiLink tssopPropName		Typedef

HiLink tssopInteger		Number
HiLink tssopFloat		Float
HiLink tssopScientific	Float

delcommand HiLink


let b:current_syntax = "tssop"

" vim: ts=8 sw=2
