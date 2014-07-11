" Vim syntax file
" Language:     TSS (Thermal Synthesizer System) Optics
" Maintainer:   Adrian Nagle, anagle@ball.com
" Last Change:  2003 May 11
" Filenames:    *.tssop
" URL:		http://www.naglenet.org/vim/syntax/tssop.vim
" MAIN URL:     http://www.naglenet.org/vim/



" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
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
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_tssop_syntax_inits")
  if version < 508
    let did_tssop_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

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
endif


let b:current_syntax = "tssop"

" vim: ts=8 sw=2
