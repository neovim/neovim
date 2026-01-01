" Vim syntax file
" Language:	ATLAS
" Maintainer:	Inaki Saez <jisaez@sfe.indra.es>
" Last Change:	2001 May 09

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn case ignore

syn keyword atlasStatement	begin terminate
syn keyword atlasStatement	fill calculate compare
syn keyword atlasStatement	setup connect close open disconnect reset
syn keyword atlasStatement	initiate read fetch
syn keyword atlasStatement	apply measure verify remove
syn keyword atlasStatement	perform leave finish output delay
syn keyword atlasStatement	prepare execute
syn keyword atlasStatement	do
syn match atlasStatement	"\<go[	 ]\+to\>"
syn match atlasStatement	"\<wait[	 ]\+for\>"

syn keyword atlasInclude	include
syn keyword atlasDefine		define require declare identify

"syn keyword atlasReserved	true false go nogo hi lo via
syn keyword atlasReserved	true false

syn keyword atlasStorageClass	external global

syn keyword atlasConditional	if then else end
syn keyword atlasRepeat		while for thru

" Flags BEF and statement number
syn match atlasSpecial		"^[BE ][ 0-9]\{,6}\>"

" Number formats
syn match atlasHexNumber	"\<X'[0-9A-F]\+'"
syn match atlasOctalNumber	"\<O'[0-7]\+'"
syn match atlasBinNumber	"\<B'[01]\+'"
syn match atlasNumber		"\<\d\+\>"
"Floating point number part only
syn match atlasDecimalNumber	"\.\d\+\([eE][-+]\=\d\)\=\>"

syn region atlasFormatString	start=+((+	end=+\())\)\|\()[	 ]*\$\)+me=e-1
syn region atlasString		start=+\<C'+	end=+'+   oneline

syn region atlasComment		start=+^C+	end=+\$+
syn region atlasComment2	start=+\$.\++ms=s+1	end=+$+ oneline

syn match  atlasIdentifier	"'[A-Za-z0-9 ._-]\+'"

"Synchronization with Statement terminator $
syn sync match atlasTerminator	grouphere atlasComment "^C"
syn sync match atlasTerminator	groupthere NONE "\$"
syn sync maxlines=100


" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link atlasConditional	Conditional
hi def link atlasRepeat		Repeat
hi def link atlasStatement	Statement
hi def link atlasNumber		Number
hi def link atlasHexNumber	Number
hi def link atlasOctalNumber	Number
hi def link atlasBinNumber	Number
hi def link atlasDecimalNumber	Float
hi def link atlasFormatString	String
hi def link atlasString		String
hi def link atlasComment		Comment
hi def link atlasComment2		Comment
hi def link atlasInclude		Include
hi def link atlasDefine		Macro
hi def link atlasReserved		PreCondit
hi def link atlasStorageClass	StorageClass
hi def link atlasIdentifier	NONE
hi def link atlasSpecial		Special


let b:current_syntax = "atlas"

" vim: ts=8
