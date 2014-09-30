" Vim syntax file
" Language:	Cheetah template engine
" Maintainer:	Max Ischenko <mfi@ukr.net>
" Last Change: 2003-05-11
"
" Missing features:
"  match invalid syntax, like bad variable ref. or unmatched closing tag
"  PSP-style tags: <% .. %> (obsoleted feature)
"  doc-strings and header comments (rarely used feature)

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
	syntax clear
elseif exists("b:current_syntax")
	finish
endif

syntax case match

syn keyword cheetahKeyword contained if else unless elif for in not
syn keyword cheetahKeyword contained while repeat break continue pass end
syn keyword cheetahKeyword contained set del attr def global include raw echo
syn keyword cheetahKeyword contained import from extends implements
syn keyword cheetahKeyword contained assert raise try catch finally
syn keyword cheetahKeyword contained errorCatcher breakpoint silent cache filter
syn match   cheetahKeyword contained "\<compiler-settings\>"

" Matches cached placeholders
syn match   cheetahPlaceHolder "$\(\*[0-9.]\+[wdhms]\?\*\|\*\)\?\h\w*\(\.\h\w*\)*" display
syn match   cheetahPlaceHolder "$\(\*[0-9.]\+[wdhms]\?\*\|\*\)\?{\h\w*\(\.\h\w*\)*}" display
syn match   cheetahDirective "^\s*#[^#].*$"  contains=cheetahPlaceHolder,cheetahKeyword,cheetahComment display

syn match   cheetahContinuation "\\$"
syn match   cheetahComment "##.*$" display
syn region  cheetahMultiLineComment start="#\*" end="\*#"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_cheetah_syn_inits")
	if version < 508
		let did_cheetah_syn_inits = 1
		command -nargs=+ HiLink hi link <args>
	else
		command -nargs=+ HiLink hi def link <args>
	endif

	HiLink cheetahPlaceHolder Identifier
	HiLink cheetahDirective PreCondit
	HiLink cheetahKeyword Define
	HiLink cheetahContinuation Special
	HiLink cheetahComment Comment
	HiLink cheetahMultiLineComment Comment

	delcommand HiLink
endif

let b:current_syntax = "cheetah"

