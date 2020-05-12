" Vim syntax file
" Language:	sed
" Maintainer:	Haakon Riiser <hakonrk@fys.uio.no>
" URL:		http://folk.uio.no/hakonrk/vim/syntax/sed.vim
" Last Change:	2010 May 29

" quit when a syntax file was already loaded
if exists("b:current_syntax")
    finish
endif

syn match sedError	"\S"

syn match sedWhitespace "\s\+" contained
syn match sedSemicolon	";"
syn match sedAddress	"[[:digit:]$]"
syn match sedAddress	"\d\+\~\d\+"
syn region sedAddress   matchgroup=Special start="[{,;]\s*/\(\\/\)\="lc=1 skip="[^\\]\(\\\\\)*\\/" end="/I\=" contains=sedTab,sedRegexpMeta
syn region sedAddress   matchgroup=Special start="^\s*/\(\\/\)\=" skip="[^\\]\(\\\\\)*\\/" end="/I\=" contains=sedTab,sedRegexpMeta
syn match sedComment	"^\s*#.*$"
syn match sedFunction	"[dDgGhHlnNpPqQx=]\s*\($\|;\)" contains=sedSemicolon,sedWhitespace
syn match sedLabel	":[^;]*"
syn match sedLineCont	"^\(\\\\\)*\\$" contained
syn match sedLineCont	"[^\\]\(\\\\\)*\\$"ms=e contained
syn match sedSpecial	"[{},!]"
if exists("highlight_sedtabs")
    syn match sedTab	"\t" contained
endif

" Append/Change/Insert
syn region sedACI	matchgroup=sedFunction start="[aci]\\$" matchgroup=NONE end="^.*$" contains=sedLineCont,sedTab

syn region sedBranch	matchgroup=sedFunction start="[bt]" matchgroup=sedSemicolon end=";\|$" contains=sedWhitespace
syn region sedRW	matchgroup=sedFunction start="[rw]" matchgroup=sedSemicolon end=";\|$" contains=sedWhitespace

" Substitution/transform with various delimiters
syn region sedFlagwrite	    matchgroup=sedFlag start="w" matchgroup=sedSemicolon end=";\|$" contains=sedWhitespace contained
syn match sedFlag	    "[[:digit:]gpI]*w\=" contains=sedFlagwrite contained
syn match sedRegexpMeta	    "[.*^$]" contained
syn match sedRegexpMeta	    "\\." contains=sedTab contained
syn match sedRegexpMeta	    "\[.\{-}\]" contains=sedTab contained
syn match sedRegexpMeta	    "\\{\d\*,\d*\\}" contained
syn match sedRegexpMeta	    "\\(.\{-}\\)" contains=sedTab contained
syn match sedReplaceMeta    "&\|\\\($\|.\)" contains=sedTab contained

" Metacharacters: $ * . \ ^ [ ~
" @ is used as delimiter and treated on its own below
let __at = char2nr("@")
let __sed_i = char2nr(" ") " ASCII: 32, EBCDIC: 64
if has("ebcdic")
    let __sed_last = 255
else
    let __sed_last = 126
endif
let __sed_metacharacters = '$*.\^[~'
while __sed_i <= __sed_last
    let __sed_delimiter = escape(nr2char(__sed_i), __sed_metacharacters)
	if __sed_i != __at
	    exe 'syn region sedAddress matchgroup=Special start=@\\'.__sed_delimiter.'\(\\'.__sed_delimiter.'\)\=@ skip=@[^\\]\(\\\\\)*\\'.__sed_delimiter.'@ end=@'.__sed_delimiter.'I\=@ contains=sedTab'
	    exe 'syn region sedRegexp'.__sed_i  'matchgroup=Special start=@'.__sed_delimiter.'\(\\\\\|\\'.__sed_delimiter.'\)*@ skip=@[^\\'.__sed_delimiter.']\(\\\\\)*\\'.__sed_delimiter.'@ end=@'.__sed_delimiter.'@me=e-1 contains=sedTab,sedRegexpMeta keepend contained nextgroup=sedReplacement'.__sed_i
	    exe 'syn region sedReplacement'.__sed_i 'matchgroup=Special start=@'.__sed_delimiter.'\(\\\\\|\\'.__sed_delimiter.'\)*@ skip=@[^\\'.__sed_delimiter.']\(\\\\\)*\\'.__sed_delimiter.'@ end=@'.__sed_delimiter.'@ contains=sedTab,sedReplaceMeta keepend contained nextgroup=sedFlag'
	endif
    let __sed_i = __sed_i + 1
endwhile
syn region sedAddress matchgroup=Special start=+\\@\(\\@\)\=+ skip=+[^\\]\(\\\\\)*\\@+ end=+@I\=+ contains=sedTab,sedRegexpMeta
syn region sedRegexp64 matchgroup=Special start=+@\(\\\\\|\\@\)*+ skip=+[^\\@]\(\\\\\)*\\@+ end=+@+me=e-1 contains=sedTab,sedRegexpMeta keepend contained nextgroup=sedReplacement64
syn region sedReplacement64 matchgroup=Special start=+@\(\\\\\|\\@\)*+ skip=+[^\\@]\(\\\\\)*\\@+ end=+@+ contains=sedTab,sedReplaceMeta keepend contained nextgroup=sedFlag

" Since the syntax for the substituion command is very similar to the
" syntax for the transform command, I use the same pattern matching
" for both commands.  There is one problem -- the transform command
" (y) does not allow any flags.  To save memory, I ignore this problem.
syn match sedST	"[sy]" nextgroup=sedRegexp\d\+


hi def link sedAddress		Macro
hi def link sedACI		NONE
hi def link sedBranch		Label
hi def link sedComment		Comment
hi def link sedDelete		Function
hi def link sedError		Error
hi def link sedFlag		Type
hi def link sedFlagwrite		Constant
hi def link sedFunction		Function
hi def link sedLabel		Label
hi def link sedLineCont		Special
hi def link sedPutHoldspc	Function
hi def link sedReplaceMeta	Special
hi def link sedRegexpMeta	Special
hi def link sedRW		Constant
hi def link sedSemicolon		Special
hi def link sedST		Function
hi def link sedSpecial		Special
hi def link sedWhitespace	NONE
if exists("highlight_sedtabs")
hi def link sedTab		Todo
endif
let __sed_i = char2nr(" ") " ASCII: 32, EBCDIC: 64
while __sed_i <= __sed_last
exe "hi def link sedRegexp".__sed_i		"Macro"
exe "hi def link sedReplacement".__sed_i	"NONE"
let __sed_i = __sed_i + 1
endwhile


unlet __sed_i __sed_last __sed_delimiter __sed_metacharacters

let b:current_syntax = "sed"

" vim: sts=4 sw=4 ts=8
