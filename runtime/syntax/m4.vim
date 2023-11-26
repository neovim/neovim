" Vim syntax file
" Language:		M4
" Maintainer:	Claudio Fleiner (claudio@fleiner.com)
" URL:			http://www.fleiner.com/vim/syntax/m4.vim
" 				(outdated)
" Last Change:	2022 Jun 12

" This file will highlight user function calls if they use only
" capital letters and have at least one argument (i.e. the '('
" must be there). Let me know if this is a problem.

" quit when a syntax file was already loaded
if !exists("main_syntax")
  if exists("b:current_syntax")
	finish
  endif
  " we define it here so that included files can test for it
  let main_syntax='m4'
endif

" define the m4 syntax
syn match  m4Variable contained "\$\d\+"
syn match  m4Special  contained "$[@*#]"
syn match  m4Comment  "\<\(m4_\)\=dnl\>.*" contains=SpellErrors
syn match  m4Comment  "#.*" contains=SpellErrors
syn match  m4Constants "\<\(m4_\)\=__file__"
syn match  m4Constants "\<\(m4_\)\=__line__"
syn keyword m4Constants divnum sysval m4_divnum m4_sysval
syn region m4Paren    matchgroup=m4Delimiter start="(" end=")" contained contains=@m4Top
syn region m4Command  matchgroup=m4Function  start="\<\(m4_\)\=\(define\|defn\|pushdef\)(" end=")" contains=@m4Top
syn region m4Command  matchgroup=m4Preproc   start="\<\(m4_\)\=\(include\|sinclude\)("he=e-1 end=")" contains=@m4Top
syn region m4Command  matchgroup=m4Statement start="\<\(m4_\)\=\(syscmd\|esyscmd\|ifdef\|ifelse\|indir\|builtin\|shift\|errprint\|m4exit\|changecom\|changequote\|changeword\|m4wrap\|debugfile\|divert\|undivert\)("he=e-1 end=")" contains=@m4Top
syn region m4Command  matchgroup=m4builtin start="\<\(m4_\)\=\(len\|index\|regexp\|substr\|translit\|patsubst\|format\|incr\|decr\|eval\|maketemp\)("he=e-1 end=")" contains=@m4Top
syn keyword m4Statement divert undivert
syn region m4Command  matchgroup=m4Type      start="\<\(m4_\)\=\(undefine\|popdef\)("he=e-1 end=")" contains=@m4Top
syn region m4Function matchgroup=m4Type      start="\<[_A-Z][_A-Z0-9]*("he=e-1 end=")" contains=@m4Top
syn region m4String   start="`" end="'" contains=SpellErrors
syn cluster m4Top     contains=m4Comment,m4Constants,m4Special,m4Variable,m4String,m4Paren,m4Command,m4Statement,m4Function

" Define the default highlighting.
" Only when an item doesn't have highlighting yet
hi def link m4Delimiter Delimiter
hi def link m4Comment   Comment
hi def link m4Function  Function
hi def link m4Keyword   Keyword
hi def link m4Special   Special
hi def link m4String    String
hi def link m4Statement Statement
hi def link m4Preproc   PreProc
hi def link m4Type      Type
hi def link m4Special   Special
hi def link m4Variable  Special
hi def link m4Constants Constant
hi def link m4Builtin   Statement

let b:current_syntax = "m4"

if main_syntax == 'm4'
  unlet main_syntax
endif

" vim: ts=4
