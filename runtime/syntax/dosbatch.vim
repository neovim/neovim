" Vim syntax file
" Language:	MSDOS batch file (with NT command extensions)
" Maintainer:	Mike Williams <mrw@eandem.co.uk>
" Filenames:    *.bat
" Last Change:	6th September 2009
" Web Page:     http://www.eandem.co.uk/mrw/vim
"
" Options Flags:
" dosbatch_cmdextversion	- 1 = Windows NT, 2 = Windows 2000 [default]
"

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" Set default highlighting to Win2k
if !exists("dosbatch_cmdextversion")
  let dosbatch_cmdextversion = 2
endif

" DOS bat files are case insensitive but case preserving!
syn case ignore

syn keyword dosbatchTodo contained	TODO

" Dosbat keywords
syn keyword dosbatchStatement	goto call exit
syn keyword dosbatchConditional	if else
syn keyword dosbatchRepeat	for

" Some operators - first lot are case sensitive!
syn case match
syn keyword dosbatchOperator    EQU NEQ LSS LEQ GTR GEQ
syn case ignore
syn match dosbatchOperator      "\s[-+\*/%!~]\s"
syn match dosbatchOperator      "="
syn match dosbatchOperator      "[-+\*/%]="
syn match dosbatchOperator      "\s\(&\||\|^\|<<\|>>\)=\=\s"
syn match dosbatchIfOperator    "if\s\+\(\(not\)\=\s\+\)\=\(exist\|defined\|errorlevel\|cmdextversion\)\="lc=2

" String - using "'s is a convenience rather than a requirement outside of FOR
syn match dosbatchString	"\"[^"]*\"" contains=dosbatchVariable,dosBatchArgument,dosbatchSpecialChar,@dosbatchNumber,@Spell
syn match dosbatchString	"\<echo\([^)>|]\|\^\@<=[)>|]\)*"lc=4 contains=dosbatchVariable,dosbatchArgument,dosbatchSpecialChar,@dosbatchNumber,@Spell
syn match dosbatchEchoOperator  "\<echo\s\+\(on\|off\)\s*$"lc=4

" For embedded commands
syn match dosbatchCmd		"(\s*'[^']*'"lc=1 contains=dosbatchString,dosbatchVariable,dosBatchArgument,@dosbatchNumber,dosbatchImplicit,dosbatchStatement,dosbatchConditional,dosbatchRepeat,dosbatchOperator

" Numbers - surround with ws to not include in dir and filenames
syn match dosbatchInteger       "[[:space:]=(/:,!~-]\d\+"lc=1
syn match dosbatchHex		"[[:space:]=(/:,!~-]0x\x\+"lc=1
syn match dosbatchBinary	"[[:space:]=(/:,!~-]0b[01]\+"lc=1
syn match dosbatchOctal		"[[:space:]=(/:,!~-]0\o\+"lc=1
syn cluster dosbatchNumber      contains=dosbatchInteger,dosbatchHex,dosbatchBinary,dosbatchOctal

" Command line switches
syn match dosbatchSwitch	"/\(\a\+\|?\)"

" Various special escaped char formats
syn match dosbatchSpecialChar   "\^[&|()<>^]"
syn match dosbatchSpecialChar   "\$[a-hl-npqstv_$+]"
syn match dosbatchSpecialChar   "%%"

" Environment variables
syn match dosbatchIdentifier    contained "\s\h\w*\>"
syn match dosbatchVariable	"%\h\w*%"
syn match dosbatchVariable	"%\h\w*:\*\=[^=]*=[^%]*%"
syn match dosbatchVariable	"%\h\w*:\~[-]\=\d\+\(,[-]\=\d\+\)\=%" contains=dosbatchInteger
syn match dosbatchVariable	"!\h\w*!"
syn match dosbatchVariable	"!\h\w*:\*\=[^=]*=[^!]*!"
syn match dosbatchVariable	"!\h\w*:\~[-]\=\d\+\(,[-]\=\d\+\)\=!" contains=dosbatchInteger
syn match dosbatchSet		"\s\h\w*[+-]\==\{-1}" contains=dosbatchIdentifier,dosbatchOperator

" Args to bat files and for loops, etc
syn match dosbatchArgument	"%\(\d\|\*\)"
syn match dosbatchArgument	"%[a-z]\>"
if dosbatch_cmdextversion == 1
  syn match dosbatchArgument	"%\~[fdpnxs]\+\(\($PATH:\)\=[a-z]\|\d\)\>"
else
  syn match dosbatchArgument	"%\~[fdpnxsatz]\+\(\($PATH:\)\=[a-z]\|\d\)\>"
endif

" Line labels
syn match dosbatchLabel		"^\s*:\s*\h\w*\>"
syn match dosbatchLabel		"\<\(goto\|call\)\s\+:\h\w*\>"lc=4
syn match dosbatchLabel		"\<goto\s\+\h\w*\>"lc=4
syn match dosbatchLabel		":\h\w*\>"

" Comments - usual rem but also two colons as first non-space is an idiom
syn match dosbatchComment	"^rem\($\|\s.*$\)"lc=3 contains=dosbatchTodo,dosbatchSpecialChar,@dosbatchNumber,dosbatchVariable,dosbatchArgument,@Spell
syn match dosbatchComment	"^@rem\($\|\s.*$\)"lc=4 contains=dosbatchTodo,@dosbatchNumber,dosbatchVariable,dosbatchArgument,@Spell
syn match dosbatchComment	"\srem\($\|\s.*$\)"lc=4 contains=dosbatchTodo,dosbatchSpecialChar,@dosbatchNumber,dosbatchVariable,dosbatchArgument,@Spell
syn match dosbatchComment	"\s@rem\($\|\s.*$\)"lc=5 contains=dosbatchTodo,@dosbatchNumber,dosbatchVariable,dosbatchArgument,@Spell
syn match dosbatchComment	"\s*:\s*:.*$" contains=dosbatchTodo,dosbatchSpecialChar,@dosbatchNumber,dosbatchVariable,dosbatchArgument,@Spell

" Comments in ()'s - still to handle spaces before rem
syn match dosbatchComment	"(rem\([^)]\|\^\@<=)\)*"lc=4 contains=dosbatchTodo,@dosbatchNumber,dosbatchVariable,dosbatchArgument,@Spell

syn keyword dosbatchImplicit    append assoc at attrib break cacls cd chcp chdir
syn keyword dosbatchImplicit    chkdsk chkntfs cls cmd color comp compact convert copy
syn keyword dosbatchImplicit    date del dir diskcomp diskcopy doskey echo endlocal
syn keyword dosbatchImplicit    erase fc find findstr format ftype
syn keyword dosbatchImplicit    graftabl help keyb label md mkdir mode more move
syn keyword dosbatchImplicit    path pause popd print prompt pushd rd recover rem
syn keyword dosbatchImplicit    ren rename replace restore rmdir set setlocal shift
syn keyword dosbatchImplicit    sort start subst time title tree type ver verify
syn keyword dosbatchImplicit    vol xcopy

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_dosbatch_syntax_inits")
  if version < 508
    let did_dosbatch_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink dosbatchTodo		Todo

  HiLink dosbatchStatement	Statement
  HiLink dosbatchCommands	dosbatchStatement
  HiLink dosbatchLabel		Label
  HiLink dosbatchConditional	Conditional
  HiLink dosbatchRepeat		Repeat

  HiLink dosbatchOperator       Operator
  HiLink dosbatchEchoOperator   dosbatchOperator
  HiLink dosbatchIfOperator     dosbatchOperator

  HiLink dosbatchArgument	Identifier
  HiLink dosbatchIdentifier     Identifier
  HiLink dosbatchVariable	dosbatchIdentifier

  HiLink dosbatchSpecialChar	SpecialChar
  HiLink dosbatchString		String
  HiLink dosbatchNumber		Number
  HiLink dosbatchInteger	dosbatchNumber
  HiLink dosbatchHex		dosbatchNumber
  HiLink dosbatchBinary		dosbatchNumber
  HiLink dosbatchOctal		dosbatchNumber

  HiLink dosbatchComment	Comment
  HiLink dosbatchImplicit	Function

  HiLink dosbatchSwitch		Special

  HiLink dosbatchCmd		PreProc

  delcommand HiLink
endif

let b:current_syntax = "dosbatch"

" vim: ts=8
