" Vim syntax file
" Language:	4Dos batch file
" Maintainer:	John Leo Spetz <jls11@po.cwru.edu>
" Last Change:	2001 May 09

"//Issues to resolve:
"//- Boolean operators surrounded by period are recognized but the
"//  periods are not highlighted.  The only way to do that would
"//  be separate synmatches for each possibility otherwise a more
"//  general \.\i\+\. will highlight anything delimited by dots.
"//- After unary operators like "defined" can assume token type.
"//  Should there be more of these?

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn case ignore

syn keyword btmStatement	call off
syn keyword btmConditional	if iff endiff then else elseiff not errorlevel
syn keyword btmConditional	gt lt eq ne ge le
syn match btmConditional transparent    "\.\i\+\." contains=btmDotBoolOp
syn keyword btmDotBoolOp contained      and or xor
syn match btmConditional	"=="
syn match btmConditional	"!="
syn keyword btmConditional	defined errorlevel exist isalias
syn keyword btmConditional	isdir direxist isinternal islabel
syn keyword btmRepeat		for in do enddo

syn keyword btmTodo contained	TODO

" String
syn cluster btmVars contains=btmVariable,btmArgument,btmBIFMatch
syn region  btmString	start=+"+  end=+"+ contains=@btmVars
syn match btmNumber     "\<\d\+\>"

"syn match  btmIdentifier	"\<\h\w*\>"

" If you don't like tabs
"syn match btmShowTab "\t"
"syn match btmShowTabc "\t"
"syn match  btmComment		"^\ *rem.*$" contains=btmTodo,btmShowTabc

" Some people use this as a comment line
" In fact this is a Label
"syn match btmComment		"^\ *:\ \+.*$" contains=btmTodo

syn match btmComment		"^\ *rem.*$" contains=btmTodo
syn match btmComment		"^\ *::.*$" contains=btmTodo

syn match btmLabelMark		"^\ *:[0-9a-zA-Z_\-]\+\>"
syn match btmLabelMark		"goto [0-9a-zA-Z_\-]\+\>"lc=5
syn match btmLabelMark		"gosub [0-9a-zA-Z_\-]\+\>"lc=6

" syn match btmCmdDivider ">[>&][>&]\="
syn match btmCmdDivider ">[>&]*"
syn match btmCmdDivider ">>&>"
syn match btmCmdDivider "|&\="
syn match btmCmdDivider "%+"
syn match btmCmdDivider "\^"

syn region btmEcho start="echo" skip="echo" matchgroup=btmCmdDivider end="%+" end="$" end="|&\=" end="\^" end=">[>&]*" contains=@btmEchos oneline
syn cluster btmEchos contains=@btmVars,btmEchoCommand,btmEchoParam
syn keyword btmEchoCommand contained	echo echoerr echos echoserr
syn keyword btmEchoParam contained	on off

" this is also a valid Label. I don't use it.
"syn match btmLabelMark		"^\ *:\ \+[0-9a-zA-Z_\-]\+\>"

" //Environment variable can be expanded using notation %var in 4DOS
syn match btmVariable		"%[0-9a-z_\-]\+" contains=@btmSpecialVars
" //Environment variable can be expanded using notation %var%
syn match btmVariable		"%[0-9a-z_\-]*%" contains=@btmSpecialVars
" //The following are special variable in 4DOS
syn match btmVariable		"%[=#]" contains=@btmSpecialVars
syn match btmVariable		"%??\=" contains=@btmSpecialVars
" //Environment variable can be expanded using notation %[var] in 4DOS
syn match btmVariable		"%\[[0-9a-z_\-]*\]"
" //After some keywords next word should be an environment variable
syn match btmVariable		"defined\s\i\+"lc=8
syn match btmVariable		"set\s\i\+"lc=4
" //Parameters to batchfiles take the format %<digit>
syn match btmArgument		"%\d\>"
" //4DOS allows format %<digit>& meaning batchfile parameters digit and up
syn match btmArgument		"%\d\>&"
" //Variable used by FOR loops sometimes use %%<letter> in batchfiles
syn match btmArgument		"%%\a\>"

" //Show 4DOS built-in functions specially
syn match btmBIFMatch "%@\w\+\["he=e-1 contains=btmBuiltInFunc
syn keyword btmBuiltInFunc contained	alias ascii attrib cdrom
syn keyword btmBuiltInFunc contained	char clip comma convert
syn keyword btmBuiltInFunc contained	date day dec descript
syn keyword btmBuiltInFunc contained	device diskfree disktotal
syn keyword btmBuiltInFunc contained	diskused dosmem dow dowi
syn keyword btmBuiltInFunc contained	doy ems eval exec execstr
syn keyword btmBuiltInFunc contained	expand ext extended
syn keyword btmBuiltInFunc contained	fileage fileclose filedate
syn keyword btmBuiltInFunc contained	filename fileopen fileread
syn keyword btmBuiltInFunc contained	files fileseek fileseekl
syn keyword btmBuiltInFunc contained	filesize filetime filewrite
syn keyword btmBuiltInFunc contained	filewriteb findclose
syn keyword btmBuiltInFunc contained	findfirst findnext format
syn keyword btmBuiltInFunc contained	full if inc index insert
syn keyword btmBuiltInFunc contained	instr int label left len
syn keyword btmBuiltInFunc contained	lfn line lines lower lpt
syn keyword btmBuiltInFunc contained	makeage makedate maketime
syn keyword btmBuiltInFunc contained	master month name numeric
syn keyword btmBuiltInFunc contained	path random readscr ready
syn keyword btmBuiltInFunc contained	remote removable repeat
syn keyword btmBuiltInFunc contained	replace right search
syn keyword btmBuiltInFunc contained	select sfn strip substr
syn keyword btmBuiltInFunc contained	time timer trim truename
syn keyword btmBuiltInFunc contained	unique upper wild word
syn keyword btmBuiltInFunc contained	words xms year

syn cluster btmSpecialVars contains=btmBuiltInVar,btmSpecialVar

" //Show specialized variables specially
" syn match btmSpecialVar contained	"+"
syn match btmSpecialVar contained	"="
syn match btmSpecialVar contained	"#"
syn match btmSpecialVar contained	"??\="
syn keyword btmSpecialVar contained	cmdline colordir comspec
syn keyword btmSpecialVar contained	copycmd dircmd temp temp4dos
syn keyword btmSpecialVar contained	filecompletion path prompt

" //Show 4DOS built-in variables specially specially
syn keyword btmBuiltInVar contained	_4ver _alias _ansi
syn keyword btmBuiltInVar contained	_apbatt _aplife _apmac _batch
syn keyword btmBuiltInVar contained	_batchline _batchname _bg
syn keyword btmBuiltInVar contained	_boot _ci _cmdproc _co
syn keyword btmBuiltInVar contained	_codepage _column _columns
syn keyword btmBuiltInVar contained	_country _cpu _cwd _cwds _cwp
syn keyword btmBuiltInVar contained	_cwps _date _day _disk _dname
syn keyword btmBuiltInVar contained	_dos _dosver _dow _dowi _doy
syn keyword btmBuiltInVar contained	_dpmi _dv _env _fg _hlogfile
syn keyword btmBuiltInVar contained	_hour _kbhit _kstack _lastdisk
syn keyword btmBuiltInVar contained	_logfile _minute _monitor
syn keyword btmBuiltInVar contained	_month _mouse _ndp _row _rows
syn keyword btmBuiltInVar contained	_second _shell _swapping
syn keyword btmBuiltInVar contained	_syserr _time _transient
syn keyword btmBuiltInVar contained	_video _win _wintitle _year

" //Commands in 4DOS and/or DOS
syn match btmCommand	"\s?"
syn match btmCommand	"^?"
syn keyword btmCommand	alias append assign attrib
syn keyword btmCommand	backup beep break cancel case
syn keyword btmCommand	cd cdd cdpath chcp chdir
syn keyword btmCommand	chkdsk cls color comp copy
syn keyword btmCommand	ctty date debug default defrag
syn keyword btmCommand	del delay describe dir
syn keyword btmCommand	dirhistory dirs diskcomp
syn keyword btmCommand	diskcopy doskey dosshell
syn keyword btmCommand	drawbox drawhline drawvline
"syn keyword btmCommand	echo echoerr echos echoserr
syn keyword btmCommand	edit edlin emm386 endlocal
syn keyword btmCommand	endswitch erase eset except
syn keyword btmCommand	exe2bin exit expand fastopen
syn keyword btmCommand	fc fdisk ffind find format
syn keyword btmCommand	free global gosub goto
syn keyword btmCommand	graftabl graphics help history
syn keyword btmCommand	inkey input join keyb keybd
syn keyword btmCommand	keystack label lh list loadbtm
syn keyword btmCommand	loadhigh lock log md mem
syn keyword btmCommand	memory mirror mkdir mode more
syn keyword btmCommand	move nlsfunc on option path
syn keyword btmCommand	pause popd print prompt pushd
syn keyword btmCommand	quit rd reboot recover ren
syn keyword btmCommand	rename replace restore return
syn keyword btmCommand	rmdir scandisk screen scrput
syn keyword btmCommand	select set setdos setlocal
syn keyword btmCommand	setver share shift sort subst
syn keyword btmCommand	swapping switch sys tee text
syn keyword btmCommand	time timer touch tree truename
syn keyword btmCommand	type unalias undelete unformat
syn keyword btmCommand	unlock unset ver verify vol
syn keyword btmCommand	vscrput y

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link btmLabel		Special
hi def link btmLabelMark		Special
hi def link btmCmdDivider		Special
hi def link btmConditional		btmStatement
hi def link btmDotBoolOp		btmStatement
hi def link btmRepeat		btmStatement
hi def link btmEchoCommand	btmStatement
hi def link btmEchoParam		btmStatement
hi def link btmStatement		Statement
hi def link btmTodo		Todo
hi def link btmString		String
hi def link btmNumber		Number
hi def link btmComment		Comment
hi def link btmArgument		Identifier
hi def link btmVariable		Identifier
hi def link btmEcho		String
hi def link btmBIFMatch		btmStatement
hi def link btmBuiltInFunc		btmStatement
hi def link btmBuiltInVar		btmStatement
hi def link btmSpecialVar		btmStatement
hi def link btmCommand		btmStatement

"optional highlighting
"hi def link btmShowTab		Error
"hi def link btmShowTabc		Error
"hi def link btmIdentifier		Identifier


let b:current_syntax = "btm"

" vim: ts=8
