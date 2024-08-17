" Vim syntax file
" Language:	MS-DOS/Windows batch file (with NT command extensions)
" Maintainer:	Mike Williams <mrmrdubya@gmail.com>
" Filenames:    *.bat
" Last Change:	3rd February 2024
" 2024 Aug 14 by Vim Project: improve syntax (#15453)
"
" Options Flags:
" dosbatch_cmdextversion	- 1 = Windows NT, 2 = Windows 2000 [default]
" dosbatch_colons_comment       - any value to allow :: comments in code blocks
"

" quit when a syntax file was already loaded
if exists("b:current_syntax")
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
syn match dosbatchCmd		"(\s*'[^']*'"lc=1 contains=dosbatchString,dosbatchVariable,dosBatchArgument,@dosbatchNumber,dosbatchImplicit,dosbatchStatement,dosbatchConditional,dosbatchRepeat,dosbatchOperator,dosbatchIfOperator

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
syn match dosbatchRemComment	"^rem\($\|\s.*$\)"lc=3 contains=dosbatchTodo,dosbatchSpecialChar,@dosbatchNumber,dosbatchVariable,dosbatchArgument,@Spell
syn match dosbatchRemComment	"^@rem\($\|\s.*$\)"lc=4 contains=dosbatchTodo,@dosbatchNumber,dosbatchVariable,dosbatchArgument,@Spell
syn match dosbatchRemComment	"\srem\($\|\s.*$\)"lc=4 contains=dosbatchTodo,dosbatchSpecialChar,@dosbatchNumber,dosbatchVariable,dosbatchArgument,@Spell
syn match dosbatchRemComment	"\s@rem\($\|\s.*$\)"lc=5 contains=dosbatchTodo,@dosbatchNumber,dosbatchVariable,dosbatchArgument,@Spell
syn match dosbatchColonComment	"\s*:\s*:.*$" contains=dosbatchTodo,dosbatchSpecialChar,@dosbatchNumber,dosbatchVariable,dosbatchArgument,@Spell

" Commands code blocks
syn cluster dosbatchCodeBlockComment contains=dosbatchRemComment
if exists("dosbatch_colons_comment")
  syn cluster dosbatchCodeBlockComment add=dosbatchColonComment
else
  syn match dosbatchColonCommentErr contained "\s*:\s*:.*$"
endif
syn match dosbatchColonCommentErr contained "\s*:\s*:[^)]*\(\(\n\s*\)\?)\)\@="
syn region dosbatchCodeBlock	transparent start=+(+ end=+)+ contains=dosbatchString,dosbatchVariable,dosBatchArgument,@dosbatchNumber,dosbatchImplicit,dosbatchStatement,dosbatchConditional,dosbatchRepeat,dosbatchOperator,dosbatchIfOperator,@dosbatchCodeBlockComment,dosbatchColonCommentErr,dosbatchCodeBlock
syn match dosbatchCodeBlockErr	")"

syn sync match dosbatchSyncCodeBlock grouphere NONE "^)\s*$"

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
" Only when an item doesn't have highlighting yet

hi def link dosbatchTodo	Todo
hi def link dosbatchError	Error
hi def link dosbatchCodeBlockErr dosbatchError
hi def link dosbatchColonCommentErr dosbatchError

hi def link dosbatchStatement	Statement
hi def link dosbatchCommands	dosbatchStatement
hi def link dosbatchLabel	Label
hi def link dosbatchConditional	Conditional
hi def link dosbatchRepeat	Repeat

hi def link dosbatchOperator	Operator
hi def link dosbatchEchoOperator dosbatchOperator
hi def link dosbatchIfOperator	dosbatchOperator

hi def link dosbatchArgument	Identifier
hi def link dosbatchIdentifier	Identifier
hi def link dosbatchVariable	dosbatchIdentifier

hi def link dosbatchSpecialChar	SpecialChar
hi def link dosbatchString	String
hi def link dosbatchNumber	Number
hi def link dosbatchInteger	dosbatchNumber
hi def link dosbatchHex		dosbatchNumber
hi def link dosbatchBinary	dosbatchNumber
hi def link dosbatchOctal	dosbatchNumber

hi def link dosbatchComment	Comment
hi def link dosbatchRemComment	dosbatchComment
hi def link dosbatchColonComment dosbatchComment

hi def link dosbatchImplicit	Function

hi def link dosbatchSwitch	Special

hi def link dosbatchCmd		PreProc


let b:current_syntax = "dosbatch"

" vim: ts=8
