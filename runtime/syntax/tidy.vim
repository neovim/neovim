" Vim syntax file
" Language:	HMTL Tidy configuration file (/etc/tidyrc ~/.tidyrc)
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2013 June 01

if exists("b:current_syntax")
  finish
endif

setlocal iskeyword=@,48-57,-

syn match	tidyComment	"^\s*//.*$" contains=tidyTodo
syn match	tidyComment	"^\s*#.*$"  contains=tidyTodo
syn keyword	tidyTodo	TODO NOTE FIXME XXX contained

syn match	tidyAssignment	"^[a-z0-9-]\+:\s*.*$" contains=tidyOption,@tidyValue,tidyDelimiter
syn match	tidyDelimiter	":" contained

syn match	tidyNewTagAssignment	"^new-\l\+-tags:\s*.*$" contains=tidyNewTagOption,tidyNewTagDelimiter,tidyNewTagValue,tidyDelimiter
syn match	tidyNewTagDelimiter	"," contained
syn match	tidyNewTagValue		"\<\w\+\>" contained

syn case ignore
syn keyword	tidyBoolean t[rue] f[alse] y[es] n[o] contained
syn case match
syn match	tidyDoctype "\<\%(omit\|auto\|strict\|loose\|transitional\|user\)\>" contained
" NOTE: use match rather than keyword here so that tidyEncoding 'raw' does not
"       always have precedence over tidyOption 'raw'
syn match	tidyEncoding	"\<\%(ascii\|latin0\|latin1\|raw\|utf8\|iso2022\|mac\|utf16le\|utf16be\|utf16\|win1252\|ibm858\|big5\|shiftjis\)\>" contained
syn match	tidyNewline	"\<\%(LF\|CRLF\|CR\)\>"
syn match	tidyNumber	"\<\d\+\>" contained
syn match	tidyRepeat	"\<\%(keep-first\|keep-last\)\>" contained
syn region	tidyString	start=+"+ skip=+\\\\\|\\"+ end=+"+ contained oneline
syn region	tidyString	start=+'+ skip=+\\\\\|\\'+ end=+'+ contained oneline
syn cluster	tidyValue	contains=tidyBoolean,tidyDoctype,tidyEncoding,tidyNewline,tidyNumber,tidyRepeat,tidyString

syn match tidyOption "^accessibility-check"		contained
syn match tidyOption "^add-xml-decl"			contained
syn match tidyOption "^add-xml-pi"			contained
syn match tidyOption "^add-xml-space"			contained
syn match tidyOption "^alt-text"			contained
syn match tidyOption "^anchor-as-name"			contained
syn match tidyOption "^ascii-chars"			contained
syn match tidyOption "^assume-xml-procins"		contained
syn match tidyOption "^bare"				contained
syn match tidyOption "^break-before-br"			contained
syn match tidyOption "^char-encoding"			contained
syn match tidyOption "^clean"				contained
syn match tidyOption "^css-prefix"			contained
syn match tidyOption "^decorate-inferred-ul"		contained
syn match tidyOption "^doctype"				contained
syn match tidyOption "^doctype-mode"			contained
syn match tidyOption "^drop-empty-paras"		contained
syn match tidyOption "^drop-font-tags"			contained
syn match tidyOption "^drop-proprietary-attributes"	contained
syn match tidyOption "^enclose-block-text"		contained
syn match tidyOption "^enclose-text"			contained
syn match tidyOption "^error-file"			contained
syn match tidyOption "^escape-cdata"			contained
syn match tidyOption "^fix-backslash"			contained
syn match tidyOption "^fix-bad-comments"		contained
syn match tidyOption "^fix-uri"				contained
syn match tidyOption "^force-output"			contained
syn match tidyOption "^gnu-emacs"			contained
syn match tidyOption "^gnu-emacs-file"			contained
syn match tidyOption "^hide-comments"			contained
syn match tidyOption "^hide-endtags"			contained
syn match tidyOption "^indent"				contained
syn match tidyOption "^indent-attributes"		contained
syn match tidyOption "^indent-cdata"			contained
syn match tidyOption "^indent-spaces"			contained
syn match tidyOption "^input-encoding"			contained
syn match tidyOption "^input-xml"			contained
syn match tidyOption "^join-classes"			contained
syn match tidyOption "^join-styles"			contained
syn match tidyOption "^keep-time"			contained
syn match tidyOption "^language"			contained
syn match tidyOption "^literal-attributes"		contained
syn match tidyOption "^logical-emphasis"		contained
syn match tidyOption "^lower-literals"			contained
syn match tidyOption "^markup"				contained
syn match tidyOption "^merge-divs"			contained
syn match tidyOption "^merge-spans"			contained
syn match tidyOption "^ncr"				contained
syn match tidyOption "^newline"				contained
syn match tidyOption "^numeric-entities"		contained
syn match tidyOption "^output-bom"			contained
syn match tidyOption "^output-encoding"			contained
syn match tidyOption "^output-file"			contained
syn match tidyOption "^output-html"			contained
syn match tidyOption "^output-xhtml"			contained
syn match tidyOption "^output-xml"			contained
syn match tidyOption "^preserve-entities"		contained
syn match tidyOption "^punctuation-wrap"		contained
syn match tidyOption "^quiet"				contained
syn match tidyOption "^quote-ampersand"			contained
syn match tidyOption "^quote-marks"			contained
syn match tidyOption "^quote-nbsp"			contained
syn match tidyOption "^raw"				contained
syn match tidyOption "^repeated-attributes"		contained
syn match tidyOption "^replace-color"			contained
syn match tidyOption "^show-body-only"			contained
syn match tidyOption "^show-errors"			contained
syn match tidyOption "^show-warnings"			contained
syn match tidyOption "^slide-style"			contained
syn match tidyOption "^sort-attributes"			contained
syn match tidyOption "^split"				contained
syn match tidyOption "^tab-size"			contained
syn match tidyOption "^tidy-mark"			contained
syn match tidyOption "^uppercase-attributes"		contained
syn match tidyOption "^uppercase-tags"			contained
syn match tidyOption "^word-2000"			contained
syn match tidyOption "^wrap"				contained
syn match tidyOption "^wrap-asp"			contained
syn match tidyOption "^wrap-attributes"			contained
syn match tidyOption "^wrap-jste"			contained
syn match tidyOption "^wrap-php"			contained
syn match tidyOption "^wrap-script-literals"		contained
syn match tidyOption "^wrap-sections"			contained
syn match tidyOption "^write-back"			contained
syn match tidyOption "^vertical-space"			contained

syn match tidyNewTagOption "^new-blocklevel-tags"	contained
syn match tidyNewTagOption "^new-empty-tags"		contained
syn match tidyNewTagOption "^new-inline-tags"		contained
syn match tidyNewTagOption "^new-pre-tags"		contained

hi def link tidyBoolean		Boolean
hi def link tidyComment		Comment
hi def link tidyDelimiter	Special
hi def link tidyDoctype		Constant
hi def link tidyEncoding	Constant
hi def link tidyNewline		Constant
hi def link tidyNewTagDelimiter	Special
hi def link tidyNewTagOption	Identifier
hi def link tidyNewTagValue	Constant
hi def link tidyNumber		Number
hi def link tidyOption		Identifier
hi def link tidyRepeat		Constant
hi def link tidyString		String
hi def link tidyTodo		Todo

let b:current_syntax = "tidy"

" vim: ts=8
