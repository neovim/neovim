" Vim syntax file
" Language:	Tera Term Language (TTL)
"		Based on Tera Term Version 4.92
" Maintainer:	Ken Takata
" URL:		https://github.com/k-takata/vim-teraterm
" Last Change:	2016 Aug 17
" Filenames:	*.ttl
" License:	VIM License

if exists("b:current_syntax")
  finish
endif

let s:save_cpo = &cpo
set cpo&vim

syn case ignore

syn region ttlComment	start=";" end="$" contains=@Spell
syn region ttlComment	start="/\*" end="\*/" contains=@Spell
syn region ttlFirstComment	start="/\*" end="\*/" contained contains=@Spell
			\ nextgroup=ttlStatement,ttlFirstComment

syn match ttlCharacter	"#\%(\d\+\|\$\x\+\)\>"
syn match ttlNumber	"\%(\<\d\+\|\$\x\+\)\>"
syn match ttlString	"'[^']*'" contains=@Spell
syn match ttlString	'"[^"]*"' contains=@Spell
syn cluster ttlConstant contains=ttlCharacter,ttlNumber,ttlString

syn match ttlLabel	":\s*\w\{1,32}\>"

syn keyword ttlOperator	and or xor not

syn match ttlVar	"\<groupmatchstr\d\>"
syn match ttlVar	"\<param\d\>"
syn keyword ttlVar	inputstr matchstr paramcnt params result timeout mtimeout


syn match ttlLine nextgroup=ttlStatement "^"
syn match ttlStatement contained "\s*"
			\ nextgroup=ttlIf,ttlElseIf,ttlConditional,ttlRepeat,
			\ ttlFirstComment,ttlComment,ttlLabel,@ttlCommand

syn cluster ttlCommand contains=ttlControlCommand,ttlCommunicationCommand,
			\ ttlStringCommand,ttlFileCommand,ttlPasswordCommand,
			\ ttlMiscCommand


syn keyword ttlIf contained nextgroup=ttlIfExpression if
syn keyword ttlElseIf contained nextgroup=ttlElseIfExpression elseif

syn match ttlIfExpression contained "\s.*"
		\ contains=@ttlConstant,ttlVar,ttlOperator,ttlComment,ttlThen,
		\ @ttlCommand
syn match ttlElseIfExpression contained "\s.*"
		\ contains=@ttlConstant,ttlVar,ttlOperator,ttlComment,ttlThen

syn keyword ttlThen contained then
syn keyword ttlConditional contained else endif

syn keyword ttlRepeat contained for next until enduntil while endwhile
syn match ttlRepeat contained
			\ "\<\%(do\|loop\)\%(\s\+\%(while\|until\)\)\?\>"
syn keyword ttlControlCommand contained
			\ break call continue end execcmnd exit goto include
			\ mpause pause return


syn keyword ttlCommunicationCommand contained
			\ bplusrecv bplussend callmenu changedir clearscreen
			\ closett connect cygconnect disconnect dispstr
			\ enablekeyb flushrecv gethostname getmodemstatus
			\ gettitle kmtfinish kmtget kmtrecv kmtsend loadkeymap
			\ logautoclosemode logclose loginfo logopen logpause
			\ logrotate logstart logwrite quickvanrecv
			\ quickvansend recvln restoresetup scprecv scpsend
			\ send sendbreak sendbroadcast sendfile sendkcode
			\ sendln sendlnbroadcast sendmulticast setbaud
			\ setdebug setdtr setecho setmulticastname setrts
			\ setsync settitle showtt testlink unlink wait
			\ wait4all waitevent waitln waitn waitrecv waitregex
			\ xmodemrecv xmodemsend ymodemrecv ymodemsend
			\ zmodemrecv zmodemsend
syn keyword ttlStringCommand contained
			\ code2str expandenv int2str regexoption sprintf
			\ sprintf2 str2code str2int strcompare strconcat
			\ strcopy strinsert strjoin strlen strmatch strremove
			\ strreplace strscan strspecial strsplit strtrim
			\ tolower toupper
syn keyword ttlFileCommand contained
			\ basename dirname fileclose fileconcat filecopy
			\ filecreate filedelete filelock filemarkptr fileopen
			\ filereadln fileread filerename filesearch fileseek
			\ fileseekback filestat filestrseek filestrseek2
			\ filetruncate fileunlock filewrite filewriteln
			\ findfirst findnext findclose foldercreate
			\ folderdelete foldersearch getdir getfileattr makepath
			\ setdir setfileattr
syn keyword ttlPasswordCommand contained
			\ delpassword getpassword ispassword passwordbox
			\ setpassword
syn keyword ttlMiscCommand contained
			\ beep bringupbox checksum8 checksum8file checksum16
			\ checksum16file checksum32 checksum32file closesbox
			\ clipb2var crc16 crc16file crc32 crc32file exec
			\ dirnamebox filenamebox getdate getenv getipv4addr
			\ getipv6addr getspecialfolder gettime getttdir getver
			\ ifdefined inputbox intdim listbox messagebox random
			\ rotateleft rotateright setdate setdlgpos setenv
			\ setexitcode settime show statusbox strdim uptime
			\ var2clipb yesnobox


hi def link ttlCharacter Character
hi def link ttlNumber Number
hi def link ttlComment Comment
hi def link ttlFirstComment Comment
hi def link ttlString String
hi def link ttlLabel Label
hi def link ttlIf Conditional
hi def link ttlElseIf Conditional
hi def link ttlThen Conditional
hi def link ttlConditional Conditional
hi def link ttlRepeat Repeat
hi def link ttlControlCommand Keyword
hi def link ttlVar Identifier
hi def link ttlOperator Operator
hi def link ttlCommunicationCommand Keyword
hi def link ttlStringCommand Keyword
hi def link ttlFileCommand Keyword
hi def link ttlPasswordCommand Keyword
hi def link ttlMiscCommand Keyword

let b:current_syntax = "teraterm"

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: ts=8 sw=2 sts=2
