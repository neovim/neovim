" Vim syntax file
" Language:		sed
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Haakon Riiser <hakonrk@fys.uio.no>
" Contributor:		Jack Haden-Enneking
" Last Change:		2022 Oct 15

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn keyword sedTodo	contained TODO FIXME XXX

syn match sedError	"\S"

syn match sedWhitespace "\s\+" contained
syn match sedSemicolon	";"
syn match sedAddress	"[[:digit:]$]"
syn match sedAddress	"\d\+\~\d\+"
syn region sedAddress	matchgroup=Special start="[{,;]\s*/\%(\\/\)\="lc=1 skip="[^\\]\%(\\\\\)*\\/" end="/I\=" contains=sedTab,sedRegexpMeta
syn region sedAddress	matchgroup=Special start="^\s*/\%(\\/\)\=" skip="[^\\]\%(\\\\\)*\\/" end="/I\=" contains=sedTab,sedRegexpMeta
syn match sedFunction	"[dDgGhHlnNpPqQx=]\s*\%($\|;\)" contains=sedSemicolon,sedWhitespace
if exists("g:sed_dialect") && g:sed_dialect ==? "bsd"
  syn match sedComment	"^\s*#.*$" contains=sedTodo
else
  syn match sedFunction	"[dDgGhHlnNpPqQx=]\s*\ze#" contains=sedSemicolon,sedWhitespace
  syn match sedComment	"#.*$" contains=sedTodo
endif
syn match sedLabel	":[^;]*"
syn match sedLineCont	"^\%(\\\\\)*\\$" contained
syn match sedLineCont	"[^\\]\%(\\\\\)*\\$"ms=e contained
syn match sedSpecial	"[{},!]"

" continue to silently support the old name
let s:highlight_tabs = v:false
if exists("g:highlight_sedtabs") || get(g:, "sed_highlight_tabs", 0)
  let s:highlight_tabs = v:true
  syn match sedTab	"\t" contained
endif

" Append/Change/Insert
syn region sedACI	matchgroup=sedFunction start="[aci]\\$" matchgroup=NONE end="^.*$" contains=sedLineCont,sedTab

syn region sedBranch	matchgroup=sedFunction start="[bt]" matchgroup=sedSemicolon end=";\|$" contains=sedWhitespace
syn region sedRW	matchgroup=sedFunction start="[rw]" matchgroup=sedSemicolon end=";\|$" contains=sedWhitespace

" Substitution/transform with various delimiters
syn region sedFlagWrite	    matchgroup=sedFlag start="w" matchgroup=sedSemicolon end=";\|$" contains=sedWhitespace contained
syn match sedFlag	    "[[:digit:]gpI]*w\=" contains=sedFlagWrite contained
syn match sedRegexpMeta	    "[.*^$]" contained
syn match sedRegexpMeta	    "\\." contains=sedTab contained
syn match sedRegexpMeta	    "\[.\{-}\]" contains=sedTab contained
syn match sedRegexpMeta	    "\\{\d\*,\d*\\}" contained
syn match sedRegexpMeta	    "\\%(.\{-}\\)" contains=sedTab contained
syn match sedReplaceMeta    "&\|\\\%($\|.\)" contains=sedTab contained

" Metacharacters: $ * . \ ^ [ ~
" @ is used as delimiter and treated on its own below
let s:at = char2nr("@")
let s:i = char2nr(" ") " ASCII: 32, EBCDIC: 64
if has("ebcdic")
  let s:last = 255
else
  let s:last = 126
endif
let s:metacharacters = '$*.\^[~'
while s:i <= s:last
  let s:delimiter = escape(nr2char(s:i), s:metacharacters)
  if s:i != s:at
    exe 'syn region sedAddress matchgroup=Special start=@\\'.s:delimiter.'\%(\\'.s:delimiter.'\)\=@ skip=@[^\\]\%(\\\\\)*\\'.s:delimiter.'@ end=@'.s:delimiter.'[IM]\=@ contains=sedTab'
    exe 'syn region sedRegexp'.s:i  'matchgroup=Special start=@'.s:delimiter.'\%(\\\\\|\\'.s:delimiter.'\)*@ skip=@[^\\'.s:delimiter.']\%(\\\\\)*\\'.s:delimiter.'@ end=@'.s:delimiter.'@me=e-1 contains=sedTab,sedRegexpMeta keepend contained nextgroup=sedReplacement'.s:i
    exe 'syn region sedReplacement'.s:i 'matchgroup=Special start=@'.s:delimiter.'\%(\\\\\|\\'.s:delimiter.'\)*@ skip=@[^\\'.s:delimiter.']\%(\\\\\)*\\'.s:delimiter.'@ end=@'.s:delimiter.'@ contains=sedTab,sedReplaceMeta keepend contained nextgroup=@sedFlags'
  endif
  let s:i = s:i + 1
endwhile
syn region sedAddress matchgroup=Special start=+\\@\%(\\@\)\=+ skip=+[^\\]\%(\\\\\)*\\@+ end=+@I\=+ contains=sedTab,sedRegexpMeta
syn region sedRegexp64 matchgroup=Special start=+@\%(\\\\\|\\@\)*+ skip=+[^\\@]\%(\\\\\)*\\@+ end=+@+me=e-1 contains=sedTab,sedRegexpMeta keepend contained nextgroup=sedReplacement64
syn region sedReplacement64 matchgroup=Special start=+@\%(\\\\\|\\@\)*+ skip=+[^\\@]\%(\\\\\)*\\@+ end=+@+ contains=sedTab,sedReplaceMeta keepend contained nextgroup=sedFlag

" Since the syntax for the substitution command is very similar to the
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
hi def link sedFlagWrite	Constant
hi def link sedFunction		Function
hi def link sedLabel		Label
hi def link sedLineCont		Special
hi def link sedPutHoldspc	Function
hi def link sedReplaceMeta	Special
hi def link sedRegexpMeta	Special
hi def link sedRW		Constant
hi def link sedSemicolon	Special
hi def link sedST		Function
hi def link sedSpecial		Special
hi def link sedTodo		Todo
hi def link sedWhitespace	NONE
if s:highlight_tabs
  hi def link sedTab		Todo
endif
let s:i = char2nr(" ") " ASCII: 32, EBCDIC: 64
while s:i <= s:last
  exe "hi def link sedRegexp".s:i	"Macro"
  exe "hi def link sedReplacement".s:i	"NONE"
  let s:i = s:i + 1
endwhile

unlet s:i s:last s:delimiter s:metacharacters s:at
unlet s:highlight_tabs

let b:current_syntax = "sed"

" vim: nowrap sw=2 sts=2 ts=8 noet:
