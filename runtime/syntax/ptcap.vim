" Vim syntax file
" Language:	printcap/termcap database
" Maintainer:	Haakon Riiser <hakonrk@fys.uio.no>
" URL:		http://folk.uio.no/hakonrk/vim/syntax/ptcap.vim
" Last Change:	2001 May 15

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
    syn clear
elseif exists("b:current_syntax")
    finish
endif

" Since I only highlight based on the structure of the databases, not
" specific keywords, case sensitivity isn't required
syn case ignore

" Since everything that is not caught by the syntax patterns is assumed
" to be an error, we start parsing 20 lines up, unless something else
" is specified
if exists("ptcap_minlines")
    exe "syn sync lines=".ptcap_minlines
else
    syn sync lines=20
endif

" Highlight everything that isn't caught by the rules as errors,
" except blank lines
syn match ptcapError	    "^.*\S.*$"

syn match ptcapLeadBlank    "^\s\+" contained

" `:' and `|' are delimiters for fields and names, and should not be
" highlighted.	Hence, they are linked to `NONE'
syn match ptcapDelimiter    "[:|]" contained

" Escaped characters receive special highlighting
syn match ptcapEscapedChar  "\\." contained
syn match ptcapEscapedChar  "\^." contained
syn match ptcapEscapedChar  "\\\o\{3}" contained

" A backslash at the end of a line will suppress the newline
syn match ptcapLineCont	    "\\$" contained

" A number follows the same rules as an integer in C
syn match ptcapNumber	    "#\(+\|-\)\=\d\+"lc=1 contained
syn match ptcapNumberError  "#\d*[^[:digit:]:\\]"lc=1 contained
syn match ptcapNumber	    "#0x\x\{1,8}"lc=1 contained
syn match ptcapNumberError  "#0x\X"me=e-1,lc=1 contained
syn match ptcapNumberError  "#0x\x\{9}"lc=1 contained
syn match ptcapNumberError  "#0x\x*[^[:xdigit:]:\\]"lc=1 contained

" The `@' operator clears a flag (i.e., sets it to zero)
" The `#' operator assigns a following number to the flag
" The `=' operator assigns a string to the preceding flag
syn match ptcapOperator	    "[@#=]" contained

" Some terminal capabilites have special names like `#5' and `@1', and we
" need special rules to match these properly
syn match ptcapSpecialCap   "\W[#@]\d" contains=ptcapDelimiter contained

" If editing a termcap file, an entry in the database is terminated by
" a (non-escaped) newline.  Otherwise, it is terminated by a line which
" does not start with a colon (:)
if exists("b:ptcap_type") && b:ptcap_type[0] == 't'
    syn region ptcapEntry   start="^\s*[^[:space:]:]" end="[^\\]\(\\\\\)*$" end="^$" contains=ptcapNames,ptcapField,ptcapLeadBlank keepend
else
    syn region ptcapEntry   start="^\s*[^[:space:]:]"me=e-1 end="^\s*[^[:space:]:#]"me=e-1 contains=ptcapNames,ptcapField,ptcapLeadBlank,ptcapComment
endif
syn region ptcapNames	    start="^\s*[^[:space:]:]" skip="[^\\]\(\\\\\)*\\:" end=":"me=e-1 contains=ptcapDelimiter,ptcapEscapedChar,ptcapLineCont,ptcapLeadBlank,ptcapComment keepend contained
syn region ptcapField	    start=":" skip="[^\\]\(\\\\\)*\\$" end="[^\\]\(\\\\\)*:"me=e-1 end="$" contains=ptcapDelimiter,ptcapString,ptcapNumber,ptcapNumberError,ptcapOperator,ptcapLineCont,ptcapSpecialCap,ptcapLeadBlank,ptcapComment keepend contained
syn region ptcapString	    matchgroup=ptcapOperator start="=" skip="[^\\]\(\\\\\)*\\:" matchgroup=ptcapDelimiter end=":"me=e-1 matchgroup=NONE end="[^\\]\(\\\\\)*[^\\]$" end="^$" contains=ptcapEscapedChar,ptcapLineCont keepend contained
syn region ptcapComment	    start="^\s*#" end="$" contains=ptcapLeadBlank

if version >= 508 || !exists("did_ptcap_syntax_inits")
    if version < 508
	let did_ptcap_syntax_inits = 1
	command -nargs=+ HiLink hi link <args>
    else
	command -nargs=+ HiLink hi def link <args>
    endif

    HiLink ptcapComment		Comment
    HiLink ptcapDelimiter	Delimiter
    " The highlighting of "ptcapEntry" should always be overridden by
    " its contents, so I use Todo highlighting to indicate that there
    " is work to be done with the syntax file if you can see it :-)
    HiLink ptcapEntry		Todo
    HiLink ptcapError		Error
    HiLink ptcapEscapedChar	SpecialChar
    HiLink ptcapField		Type
    HiLink ptcapLeadBlank	NONE
    HiLink ptcapLineCont	Special
    HiLink ptcapNames		Label
    HiLink ptcapNumber		NONE
    HiLink ptcapNumberError	Error
    HiLink ptcapOperator	Operator
    HiLink ptcapSpecialCap	Type
    HiLink ptcapString		NONE

    delcommand HiLink
endif

let b:current_syntax = "ptcap"

" vim: sts=4 sw=4 ts=8
