" Vim syntax file
" Language:	ATLAS
" Maintainer:	Inaki Saez <jisaez@sfe.indra.es>
" Last Change:	2001 May 09

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
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
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_atlas_syntax_inits")
  if version < 508
    let did_atlas_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink atlasConditional	Conditional
  HiLink atlasRepeat		Repeat
  HiLink atlasStatement	Statement
  HiLink atlasNumber		Number
  HiLink atlasHexNumber	Number
  HiLink atlasOctalNumber	Number
  HiLink atlasBinNumber	Number
  HiLink atlasDecimalNumber	Float
  HiLink atlasFormatString	String
  HiLink atlasString		String
  HiLink atlasComment		Comment
  HiLink atlasComment2		Comment
  HiLink atlasInclude		Include
  HiLink atlasDefine		Macro
  HiLink atlasReserved		PreCondit
  HiLink atlasStorageClass	StorageClass
  HiLink atlasIdentifier	NONE
  HiLink atlasSpecial		Special

  delcommand HiLink
endif

let b:current_syntax = "atlas"

" vim: ts=8
