" Vim syntax file
" Language:	Century Term Command Script
" Maintainer:	Sean M. McKee <mckee@misslink.net>
" Last Change:	2002 Apr 13
" Version Info: @(#)cterm.vim	1.7	97/12/15 09:23:14

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn case ignore

"FUNCTIONS
syn keyword ctermFunction	abort addcr addlf answer at attr batch baud
syn keyword ctermFunction	break call capture cd cdelay charset cls color
syn keyword ctermFunction	combase config commect copy cread
syn keyword ctermFunction	creadint devprefix dialer dialog dimint
syn keyword ctermFunction	dimlog dimstr display dtimeout dwait edit
syn keyword ctermFunction	editor emulate erase escloop fcreate
syn keyword ctermFunction	fflush fillchar flags flush fopen fread
syn keyword ctermFunction	freadln fseek fwrite fwriteln get hangup
syn keyword ctermFunction	help hiwait htime ignore init itime
syn keyword ctermFunction	keyboard lchar ldelay learn lockfile
syn keyword ctermFunction	locktime log login logout lowait
syn keyword ctermFunction	lsend ltime memlist menu mkdir mode
syn keyword ctermFunction	modem netdialog netport noerror pages parity
syn keyword ctermFunction	pause portlist printer protocol quit rcv
syn keyword ctermFunction	read readint readn redial release
syn keyword ctermFunction	remote rename restart retries return
syn keyword ctermFunction	rmdir rtime run runx scrollback send
syn keyword ctermFunction	session set setcap setcolor setkey
syn keyword ctermFunction	setsym setvar startserver status
syn keyword ctermFunction	stime stopbits stopserver tdelay
syn keyword ctermFunction	terminal time trans type usend version
syn keyword ctermFunction	vi vidblink vidcard vidout vidunder wait
syn keyword ctermFunction	wildsize wclose wopen wordlen wru wruchar
syn keyword ctermFunction	xfer xmit xprot
syn match ctermFunction		"?"
"syn keyword ctermFunction	comment remark

"END FUNCTIONS
"INTEGER FUNCTIONS
syn keyword ctermIntFunction	asc atod eval filedate filemode filesize ftell
syn keyword ctermIntFunction	len termbits opsys pos sum time val mdmstat
"END INTEGER FUNCTIONS

"STRING FUNCTIONS
syn keyword ctermStrFunction	cdate ctime chr chrdy chrin comin getenv
syn keyword ctermStrFunction	gethomedir left midstr right str tolower
syn keyword ctermStrFunction	toupper uniq comst exists feof hascolor

"END STRING FUNCTIONS

"PREDEFINED TERM VARIABLES R/W
syn keyword ctermPreVarRW	f _escloop _filename _kermiteol _obufsiz
syn keyword ctermPreVarRW	_port _rcvsync _cbaud _reval _turnchar
syn keyword ctermPreVarRW	_txblksiz _txwindow _vmin _vtime _cparity
syn keyword ctermPreVarRW	_cnumber false t true _cwordlen _cstopbits
syn keyword ctermPreVarRW	_cmode _cemulate _cxprot _clogin _clogout
syn keyword ctermPreVarRW	_cstartsrv _cstopsrv _ccmdfile _cwru
syn keyword ctermPreVarRW	_cprotocol _captfile _cremark _combufsiz
syn keyword ctermPreVarRW	logfile
"END PREDEFINED TERM VARIABLES R/W

"PREDEFINED TERM VARIABLES R/O
syn keyword ctermPreVarRO	_1 _2 _3 _4 _5 _6 _7 _8 _9 _cursess
syn keyword ctermPreVarRO	_lockfile _baud _errno _retval _sernum
syn keyword ctermPreVarRO	_timeout _row _col _version
"END PREDEFINED TERM VARIABLES R/O

syn keyword ctermOperator not mod eq ne gt le lt ge xor and or shr not shl

"SYMBOLS
syn match   CtermSymbols	 "|"
"syn keyword ctermOperators + - * / % = != > < >= <= & | ^ ! << >>
"END SYMBOLS

"STATEMENT
syn keyword ctermStatement	off
syn keyword ctermStatement	disk overwrite append spool none
syn keyword ctermStatement	echo view wrap
"END STATEMENT

"TYPE
"syn keyword ctermType
"END TYPE

"USERLIB FUNCTIONS
"syn keyword ctermLibFunc
"END USERLIB FUNCTIONS

"LABEL
syn keyword ctermLabel    case default
"END LABEL

"CONDITIONAL
syn keyword ctermConditional on endon
syn keyword ctermConditional proc endproc
syn keyword ctermConditional for in do endfor
syn keyword ctermConditional if else elseif endif iferror
syn keyword ctermConditional switch endswitch
syn keyword ctermConditional repeat until
"END CONDITIONAL

"REPEAT
syn keyword ctermRepeat    while
"END REPEAT

" Function arguments (eg $1 $2 $3)
syn match  ctermFuncArg	"\$[1-9]"

syn keyword ctermTodo contained TODO

syn match  ctermNumber		"\<\d\+\(u\=l\=\|lu\|f\)\>"
"floating point number, with dot, optional exponent
syn match  ctermNumber		"\<\d\+\.\d*\(e[-+]\=\d\+\)\=[fl]\=\>"
"floating point number, starting with a dot, optional exponent
syn match  ctermNumber		"\.\d\+\(e[-+]\=\d\+\)\=[fl]\=\>"
"floating point number, without dot, with exponent
syn match  ctermNumber		"\<\d\+e[-+]\=\d\+[fl]\=\>"
"hex number
syn match  ctermNumber		"0x[0-9a-f]\+\(u\=l\=\|lu\)\>"

syn match  ctermComment		"![^=].*$" contains=ctermTodo
syn match  ctermComment		"!$"
syn match  ctermComment		"\*.*$" contains=ctermTodo
syn region  ctermComment	start="comment" end="$" contains=ctermTodo
syn region  ctermComment	start="remark" end="$" contains=ctermTodo

syn region ctermVar		start="\$("  end=")"

" String and Character contstants
" Highlight special characters (those which have a backslash) differently
syn match   ctermSpecial		contained "\\\d\d\d\|\\."
syn match   ctermSpecial		contained "\^."
syn region  ctermString			start=+"+  skip=+\\\\\|\\"+  end=+"+  contains=ctermSpecial,ctermVar,ctermSymbols
syn match   ctermCharacter		"'[^\\]'"
syn match   ctermSpecialCharacter	"'\\.'"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_cterm_syntax_inits")
  if version < 508
    let did_cterm_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

	HiLink ctermStatement		Statement
	HiLink ctermFunction		Statement
	HiLink ctermStrFunction	Statement
	HiLink ctermIntFunction	Statement
	HiLink ctermLabel		Statement
	HiLink ctermConditional	Statement
	HiLink ctermRepeat		Statement
	HiLink ctermLibFunc		UserDefFunc
	HiLink ctermType		Type
	HiLink ctermFuncArg		PreCondit

	HiLink ctermPreVarRO		PreCondit
	HiLink ctermPreVarRW		PreConditBold
	HiLink ctermVar		Type

	HiLink ctermComment		Comment

	HiLink ctermCharacter		SpecialChar
	HiLink ctermSpecial		Special
	HiLink ctermSpecialCharacter	SpecialChar
	HiLink ctermSymbols		Special
	HiLink ctermString		String
	HiLink ctermTodo		Todo
	HiLink ctermOperator		Statement
	HiLink ctermNumber		Number

	" redefine the colors
	"hi PreConditBold	term=bold ctermfg=1 cterm=bold guifg=Purple gui=bold
	"hi Special	term=bold ctermfg=6 guifg=SlateBlue gui=underline

	delcommand HiLink
endif

let b:current_syntax = "cterm"

" vim: ts=8
