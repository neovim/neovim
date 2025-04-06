" Vim syntax file
" Language:	Java Properties resource file (*.properties[_*])
" Maintainer:	Simon Baldwin <simonb@sco.com>
" Last change:	26th Mar 2000

" =============================================================================

" Optional and tuning variables:

" jproperties_lines
" -----------------
"   Set a value for the sync block that we use to find long continuation lines
"   in properties; the value is already large - if you have larger continuation
"   sets you may need to increase it further - if not, and you find editing is
"   slow, reduce the value of jproperties_lines.
if !exists("jproperties_lines")
	let jproperties_lines = 256
endif

" jproperties_strict_syntax
" -------------------------
"   Most properties files assign values with "id=value" or "id:value".  But,
"   strictly, the Java properties parser also allows "id value", "id", and
"   even more bizarrely "=value", ":value", " value", and so on.  These latter
"   ones, however, are rarely used, if ever, and handling them in the high-
"   lighting can obscure errors in the more normal forms.  So, in practice
"   we take special efforts to pick out only "id=value" and "id:value" forms
"   by default.  If you want strict compliance, set jproperties_strict_syntax
"   to non-zero (and good luck).
if !exists("jproperties_strict_syntax")
	let jproperties_strict_syntax = 0
endif

" jproperties_show_messages
" -------------------------
"   If this properties file contains messages for use with MessageFormat,
"   setting a non-zero value will highlight them.  Messages are of the form
"   "{...}".  Highlighting doesn't go to the pains of picking apart what is
"   in the format itself - just the basics for now.
if !exists("jproperties_show_messages")
	let jproperties_show_messages = 0
endif

" =============================================================================

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" switch case sensitivity off
syn case ignore

" set the block
exec "syn sync lines=" . jproperties_lines

" switch between 'normal' and 'strict' syntax
if jproperties_strict_syntax != 0

	" an assignment is pretty much any non-empty line at this point,
	" trying to not think about continuation lines
	syn match   jpropertiesAssignment	"^\s*[^[:space:]]\+.*$" contains=jpropertiesIdentifier

	" an identifier is anything not a space character, pretty much; it's
	" followed by = or :, or space or tab.  Or end-of-line.
	syn match   jpropertiesIdentifier	"[^=:[:space:]]*" contained nextgroup=jpropertiesDelimiter

	" treat the delimiter specially to get colours right
	syn match   jpropertiesDelimiter	"\s*[=:[:space:]]\s*" contained nextgroup=jpropertiesString

	" catch the bizarre case of no identifier; a special case of delimiter
	syn match   jpropertiesEmptyIdentifier	"^\s*[=:]\s*" nextgroup=jpropertiesString
else

	" here an assignment is id=value or id:value, and we conveniently
	" ignore continuation lines for the present
	syn match   jpropertiesAssignment	"^\s*[^=:[:space:]]\+\s*[=:].*$" contains=jpropertiesIdentifier

	" an identifier is anything not a space character, pretty much; it's
	" always followed by = or :, and we find it in an assignment
	syn match   jpropertiesIdentifier	"[^=:[:space:]]\+" contained nextgroup=jpropertiesDelimiter

	" treat the delimiter specially to get colours right; this time the
	" delimiter must contain = or :
	syn match   jpropertiesDelimiter	"\s*[=:]\s*" contained nextgroup=jpropertiesString
endif

" a definition is all up to the last non-\-terminated line; strictly, Java
" properties tend to ignore leading whitespace on all lines of a multi-line
" definition, but we don't look for that here (because it's a major hassle)
syn region  jpropertiesString		start="" skip="\\$" end="$" contained contains=jpropertiesSpecialChar,jpropertiesError,jpropertiesSpecial

" {...} is a Java Message formatter - add a minimal recognition of these
" if required
if jproperties_show_messages != 0
	syn match   jpropertiesSpecial		"{[^}]*}\{-1,\}" contained
	syn match   jpropertiesSpecial		"'{" contained
	syn match   jpropertiesSpecial		"''" contained
endif

" \uABCD are unicode special characters
syn match   jpropertiesSpecialChar	"\\u\x\{1,4}" contained

" ...and \u not followed by a hex digit is an error, though the properties
" file parser won't issue an error on it, just set something wacky like zero
syn match   jpropertiesError		"\\u\X\{1,4}" contained
syn match   jpropertiesError		"\\u$"me=e-1 contained

" other things of note are the \t,r,n,\, and the \ preceding line end
syn match   jpropertiesSpecial		"\\[trn\\]" contained
syn match   jpropertiesSpecial		"\\\s" contained
syn match   jpropertiesSpecial		"\\$" contained

" comments begin with # or !, and persist to end of line; put here since
" they may have been caught by patterns above us
syn match   jpropertiesComment		"^\s*[#!].*$" contains=jpropertiesTODO
syn keyword jpropertiesTodo		TODO FIXME XXX contained

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link jpropertiesComment	Comment
hi def link jpropertiesTodo		Todo
hi def link jpropertiesIdentifier	Identifier
hi def link jpropertiesString	String
hi def link jpropertiesExtendString	String
hi def link jpropertiesCharacter	Character
hi def link jpropertiesSpecial	Special
hi def link jpropertiesSpecialChar	SpecialChar
hi def link jpropertiesError	Error


let b:current_syntax = "jproperties"

" vim:ts=8
