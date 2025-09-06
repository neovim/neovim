" Vim syntax file
" Language:	M4
" Maintainer:	Claudio Fleiner (claudio@fleiner.com)
" Last Change:	2022 Jun 12
" 2025 Sep 2 by Vim project: fix a few syntax issues #18192
" 2025 Sep 5 by Vim project: introduce m4Disabled region #18200

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

" Reference: The Open Group Base Specifications, M4
" https://pubs.opengroup.org/onlinepubs/9799919799/

" Quoting in M4:
" – Quotes are nestable;
" – The delimiters can be redefined with changequote(); here we only handle
"   the default pair: ` ... ';
" – Quoted text in M4 is rescanned, not treated as a literal string.
"   Therefore the region is marked transparent so contained items retain
"   their normal highlighting.
syn region m4Quoted
  \ matchgroup=m4QuoteDelim
  \ start=+`+
  \ end=+'+
  \ contains=@m4Top
  \ transparent

" Comments in M4:
" – According to the Open Group Base Specification, comments start with
"   a <number-sign> (#) and end at <newline>, unless redefined with changecom().
"   We only handle the default here.
" – Comments in M4 are not like in most languages: they do not remove the text,
"   they simply prevent any macros from being expanded, while the text remains
"   in the output. This region therefore disables any other matches.
" – Comments themselves are disabled when quoted.
syn region m4Disabled start=+#+ end=+$+ containedin=ALLBUT,m4Quoted

" define the m4 syntax
syn match  m4Variable contained "\$\d\+"
syn match  m4Special  contained "$[@*#]"
syn match  m4Comment  "\<\(m4_\)\=dnl\>.*" contains=SpellErrors
syn match  m4Constants "\<\(m4_\)\=__file__"
syn match  m4Constants "\<\(m4_\)\=__line__"
syn keyword m4Constants divnum sysval m4_divnum m4_sysval
syn region m4Paren    matchgroup=m4Delimiter start="(" end=")" contained contains=@m4Top
syn region m4Command  matchgroup=m4Function  start="\<\(m4_\)\=\(define\|defn\|pushdef\)(" end=")" contains=@m4Top
syn region m4Command  matchgroup=m4Preproc   start="\<\(m4_\)\=\(include\|sinclude\)("he=e-1 end=")" contains=@m4Top
syn region m4Command  matchgroup=m4Statement start="\<\(m4_\)\=\(syscmd\|esyscmd\|ifdef\|ifelse\|indir\|builtin\|shift\|errprint\|m4exit\|changecom\|changequote\|changeword\|m4wrap\|debugfile\|divert\|undivert\)("he=e-1 end=")" contains=@m4Top
syn region m4Command  matchgroup=m4Builtin start="\<\(m4_\)\=\(len\|index\|regexp\|substr\|translit\|patsubst\|format\|incr\|decr\|eval\|maketemp\)("he=e-1 end=")" contains=@m4Top
syn keyword m4Statement divert undivert
syn region m4Command  matchgroup=m4Type      start="\<\(m4_\)\=\(undefine\|popdef\)("he=e-1 end=")" contains=@m4Top
syn region m4Function matchgroup=m4Type      start="\<[_A-Z][_A-Z0-9]*("he=e-1 end=")" contains=@m4Top
syn cluster m4Top     contains=m4Comment,m4Constants,m4Special,m4Variable,m4Paren,m4Command,m4Statement,m4Function,m4Quoted

" Define the default highlighting.
" Only when an item doesn't have highlighting yet
hi def link m4QuoteDelim  Delimiter
hi def link m4Delimiter   Delimiter
hi def link m4Comment     Comment
hi def link m4Function    Function
hi def link m4Keyword     Keyword
hi def link m4Special     Special
hi def link m4Statement   Statement
hi def link m4Preproc     PreProc
hi def link m4Type        Type
hi def link m4Variable    Special
hi def link m4Constants   Constant
hi def link m4Builtin     Statement

let b:current_syntax = "m4"

if main_syntax == 'm4'
  unlet main_syntax
endif

" vim: ts=4
