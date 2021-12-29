" Vim syntax file
" Language:	Rich Text Format
"		"*.rtf" files
"
" The Rich Text Format (RTF) Specification is a method of encoding formatted
" text and graphics for easy transfer between applications.
" .hlp (windows help files) use compiled rtf files
" rtf documentation at http://night.primate.wisc.edu/software/RTF/
"
" Maintainer:	Dominique Stéphan (dominique@mggen.com)
" URL: http://www.mggen.com/vim/syntax/rtf.zip
" Last change:	2001 Mai 02

" TODO: render underline, italic, bold

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" case on (all controls must be lower case)
syn case match

" Control Words
syn match rtfControlWord	"\\[a-z]\+[\-]\=[0-9]*"

" New Control Words (not in the 1987 specifications)
syn match rtfNewControlWord	"\\\*\\[a-z]\+[\-]\=[0-9]*"

" Control Symbol : any \ plus a non alpha symbol, *, \, { and } and '
syn match rtfControlSymbol	"\\[^a-zA-Z\*\{\}\\']"

" { } and \ are special characters, to use them
" we add a backslash \
syn match rtfCharacter		"\\\\"
syn match rtfCharacter		"\\{"
syn match rtfCharacter		"\\}"
" Escaped characters (for 8 bytes characters upper than 127)
syn match rtfCharacter		"\\'[A-Za-z0-9][A-Za-z0-9]"
" Unicode
syn match rtfUnicodeCharacter	"\\u[0-9][0-9]*"

" Color values, we will put this value in Red, Green or Blue
syn match rtfRed		"\\red[0-9][0-9]*"
syn match rtfGreen		"\\green[0-9][0-9]*"
syn match rtfBlue		"\\blue[0-9][0-9]*"

" Some stuff for help files
syn match rtfFootNote "[#$K+]{\\footnote.*}" contains=rtfControlWord,rtfNewControlWord

" Define the default highlighting.
" Only when an item doesn't have highlighting yet


hi def link rtfControlWord		Statement
hi def link rtfNewControlWord	Special
hi def link rtfControlSymbol	Constant
hi def link rtfCharacter		Character
hi def link rtfUnicodeCharacter	SpecialChar
hi def link rtfFootNote		Comment

" Define colors for the syntax file
hi rtfRed	      term=underline cterm=underline ctermfg=DarkRed gui=underline guifg=DarkRed
hi rtfGreen	      term=underline cterm=underline ctermfg=DarkGreen gui=underline guifg=DarkGreen
hi rtfBlue	      term=underline cterm=underline ctermfg=DarkBlue gui=underline guifg=DarkBlue

hi def link rtfRed	rtfRed
hi def link rtfGreen	rtfGreen
hi def link rtfBlue	rtfBlue



let b:current_syntax = "rtf"

" vim:ts=8
