" Vim syntax file
" Language:	HMTL Tidy configuration file (/etc/tidyrc ~/.tidyrc)
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2016 Apr 24

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn iskeyword @,48-57,-,_

syn case ignore
syn keyword	tidyBoolean	contained t[rue] f[alse] y[es] n[o] 1 0
syn keyword	tidyAutoBoolean	contained t[rue] f[alse] y[es] n[o] 1 0 auto
syn case match
syn keyword	tidyDoctype	contained html5 omit auto strict loose transitional user
syn keyword	tidyEncoding	contained raw ascii latin0 latin1 utf8 iso2022 mac win1252 ibm858 utf16le utf16be utf16 big5 shiftjis
syn keyword	tidyNewline	contained LF CRLF CR
syn match	tidyNumber	contained "\<\d\+\>"
syn keyword	tidyRepeat	contained keep-first keep-last
syn keyword	tidySorter	contained alpha none
syn region	tidyString	contained start=+"+ skip=+\\\\\|\\"+ end=+"+ oneline
syn region	tidyString	contained start=+'+ skip=+\\\\\|\\'+ end=+'+ oneline
syn match	tidyTags	contained "\<\w\+\(\s*,\s*\w\+\)*\>"

syn keyword tidyBooleanOption add-xml-decl add-xml-pi add-xml-space
	\ anchor-as-name ascii-chars assume-xml-procins bare break-before-br
	\ clean coerce-endtags decorate-inferred-ul drop-empty-paras
	\ drop-empty-elements drop-font-tags drop-proprietary-attributes
	\ enclose-block-text enclose-text escape-cdata escape-scripts
	\ fix-backslash fix-bad-comments fix-uri force-output gdoc gnu-emacs
	\ hide-comments hide-endtags indent-attributes indent-cdata
	\ indent-with-tabs input-xml join-classes join-styles keep-time
	\ language literal-attributes logical-emphasis lower-literals markup
	\ merge-emphasis ncr numeric-entities omit-optional-tags output-html
	\ output-xhtml output-xml preserve-entities punctuation-wrap quiet
	\ quote-ampersand quote-marks quote-nbsp raw replace-color show-info
	\ show-warnings skip-nested split strict-tags-attributes tidy-mark
	\ uppercase-attributes uppercase-tags word-2000 wrap-asp
	\ wrap-attributes wrap-jste wrap-php wrap-script-literals
	\ wrap-sections write-back
	\ contained nextgroup=tidyBooleanDelimiter

syn match tidyBooleanDelimiter ":" nextgroup=tidyBoolean contained skipwhite

syn keyword tidyAutoBooleanOption indent merge-divs merge-spans output-bom show-body-only vertical-space contained nextgroup=tidyAutoBooleanDelimiter
syn match tidyAutoBooleanDelimiter ":" nextgroup=tidyAutoBoolean contained skipwhite

syn keyword tidyCSSSelectorOption css-prefix contained nextgroup=tidyCSSSelectorDelimiter
syn match tidyCSSSelectorDelimiter ":" nextgroup=tidyCSSSelector contained skipwhite

syn keyword tidyDoctypeOption doctype contained nextgroup=tidyDoctypeDelimiter
syn match tidyDoctypeDelimiter ":" nextgroup=tidyDoctype contained skipwhite

syn keyword tidyEncodingOption char-encoding input-encoding output-encoding contained nextgroup=tidyEncodingDelimiter
syn match tidyEncodingDelimiter ":" nextgroup=tidyEncoding contained skipwhite

syn keyword tidyIntegerOption accessibility-check doctype-mode indent-spaces show-errors tab-size wrap contained nextgroup=tidyIntegerDelimiter
syn match tidyIntegerDelimiter ":" nextgroup=tidyNumber contained skipwhite

syn keyword tidyNameOption slide-style contained nextgroup=tidyNameDelimiter
syn match tidyNameDelimiter ":" nextgroup=tidyName contained skipwhite

syn keyword tidyNewlineOption newline contained nextgroup=tidyNewlineDelimiter
syn match tidyNewlineDelimiter ":" nextgroup=tidyNewline contained skipwhite

syn keyword tidyTagsOption new-blocklevel-tags new-empty-tags new-inline-tags new-pre-tags contained nextgroup=tidyTagsDelimiter
syn match tidyTagsDelimiter ":" nextgroup=tidyTags contained skipwhite

syn keyword tidyRepeatOption repeated-attributes contained nextgroup=tidyRepeatDelimiter
syn match tidyRepeatDelimiter ":" nextgroup=tidyRepeat contained skipwhite

syn keyword tidySorterOption sort-attributes contained nextgroup=tidySorterDelimiter
syn match tidySorterDelimiter ":" nextgroup=tidySorter contained skipwhite

syn keyword tidyStringOption alt-text error-file gnu-emacs-file output-file contained nextgroup=tidyStringDelimiter
syn match tidyStringDelimiter ":" nextgroup=tidyString contained skipwhite

syn cluster tidyOptions contains=tidy.*Option

syn match tidyStart "^" nextgroup=@tidyOptions

syn match	tidyComment	"^\s*//.*$" contains=tidyTodo
syn match	tidyComment	"^\s*#.*$"  contains=tidyTodo
syn keyword	tidyTodo	TODO NOTE FIXME XXX contained

hi def link tidyAutoBooleanOption	Identifier
hi def link tidyBooleanOption		Identifier
hi def link tidyCSSSelectorOption	Identifier
hi def link tidyDoctypeOption		Identifier
hi def link tidyEncodingOption		Identifier
hi def link tidyIntegerOption		Identifier
hi def link tidyNameOption		Identifier
hi def link tidyNewlineOption		Identifier
hi def link tidyTagsOption		Identifier
hi def link tidyRepeatOption		Identifier
hi def link tidySorterOption		Identifier
hi def link tidyStringOption		Identifier

hi def link tidyAutoBooleanDelimiter	Special
hi def link tidyBooleanDelimiter	Special
hi def link tidyCSSSelectorDelimiter	Special
hi def link tidyDoctypeDelimiter	Special
hi def link tidyEncodingDelimiter	Special
hi def link tidyIntegerDelimiter	Special
hi def link tidyNameDelimiter		Special
hi def link tidyNewlineDelimiter	Special
hi def link tidyTagsDelimiter		Special
hi def link tidyRepeatDelimiter		Special
hi def link tidySorterDelimiter		Special
hi def link tidyStringDelimiter		Special

hi def link tidyAutoBoolean		Boolean
hi def link tidyBoolean			Boolean
hi def link tidyDoctype			Constant
hi def link tidyEncoding		Constant
hi def link tidyNewline			Constant
hi def link tidyTags			Constant
hi def link tidyNumber			Number
hi def link tidyRepeat			Constant
hi def link tidySorter			Constant
hi def link tidyString			String

hi def link tidyComment			Comment
hi def link tidyTodo			Todo

let b:current_syntax = "tidy"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8
