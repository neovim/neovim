" Vim syntax file
" Language:	Good old CFG files
" Maintainer:	Igor N. Prischepoff (igor@tyumbit.ru, pri_igor@mail.ru)
" Last change:	2012 Aug 11

" quit when a syntax file was already loaded
if exists ("b:current_syntax")
    finish
endif

" case off
syn case ignore
syn keyword CfgOnOff  ON OFF YES NO TRUE FALSE  contained
syn match UncPath "\\\\\p*" contained
"Dos Drive:\Path
syn match CfgDirectory "[a-zA-Z]:\\\p*" contained
"Parameters
syn match   CfgParams    ".\{0}="me=e-1 contains=CfgComment
"... and their values (don't want to highlight '=' sign)
syn match   CfgValues    "=.*"hs=s+1 contains=CfgDirectory,UncPath,CfgComment,CfgString,CfgOnOff

" Sections
syn match CfgSection	    "\[.*\]"
syn match CfgSection	    "{.*}"

" String
syn match  CfgString	"\".*\"" contained
syn match  CfgString    "'.*'"   contained

" Comments (Everything before '#' or '//' or ';')
syn match  CfgComment	"#.*"
syn match  CfgComment	";.*"
syn match  CfgComment	"\/\/.*"

" Define the default highlighting.
" Only when an item doesn't have highlighting yet
hi def link CfgOnOff     Label
hi def link CfgComment	Comment
hi def link CfgSection	Type
hi def link CfgString	String
hi def link CfgParams    Keyword
hi def link CfgValues    Constant
hi def link CfgDirectory Directory
hi def link UncPath      Directory


let b:current_syntax = "cfg"
" vim:ts=8
