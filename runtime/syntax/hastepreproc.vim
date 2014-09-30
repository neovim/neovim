" Vim syntax file
" Language:	Haste preprocessor files 
" Maintainer:	M. Tranchero - maurizio.tranchero@gmail.com
" Credits:	some parts have been taken from vhdl, verilog, and C syntax
"		files
" Version:	0.5

" HASTE
if exists("b:current_syntax")
    finish
endif
" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif
" Read the C syntax to start with
if version < 600
    so <sfile>:p:h/haste.vim
else
    runtime! syntax/haste.vim
    unlet b:current_syntax
endif

" case is significant
syn case match

" C pre-processor directives
syn match  hastepreprocVar 	display "\$[[:alnum:]_]*"
syn region hastepreprocVar	start="\${" end="}" contains=hastepreprocVar
"
"syn region hastepreproc		start="#\[\s*tg[:alnum:]*" end="]#" contains=hastepreprocVar,hastepreproc,hastepreprocError,@Spell
syn region hastepreproc		start="#\[\s*\(\|tgfor\|tgif\)" end="$" contains=hastepreprocVar,hastepreproc,@Spell
syn region hastepreproc		start="}\s\(else\)\s{" end="$" contains=hastepreprocVar,hastepreproc,@Spell
syn region hastepreproc		start="^\s*#\s*\(ifndef\|ifdef\|else\|endif\)\>" end="$" contains=@hastepreprocGroup,@Spell
syn region hastepreproc		start="\s*##\s*\(define\|undef\)\>" end="$" contains=@hastepreprocGroup,@Spell
syn match hastepreproc		"}\{0,1}\s*]#"

" Define the default highlighting.
" Only when an item doesn't have highlighting yet
hi def link hastepreproc	Preproc
hi def link hastepreprocVar	Special
hi def link hastepreprocError	Error

let b:current_syntax = "hastepreproc"

" vim: ts=8
