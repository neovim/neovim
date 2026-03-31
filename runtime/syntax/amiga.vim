" Vim syntax file
" Language:     AmigaDOS
" Maintainer:   Ola Söder <rolfkopman@gmail.com>
" First Author: Charles E. Campbell
" Last Change:  2026 Mar 25
" Version:      11

if exists("b:current_syntax")
    finish
endif

syn case ignore

" Directives
syn match amiDirective "^\.\(key\|k\)\>.*$" contains=amiTemplate
syn match amiDirective "^\.\(bra\|ket\|dot\|dollar\|dol\|def\|default\)\>.*$"

" Template arguments
syn match amiTemplate contained "/[AKSNMF]\>"

" Strings
syn region amiString start=+"+ end=+"+ oneline contains=amiEscape,amiVar,amiSubst,@Spell

" Escape sequences
syn match amiEscape contained "\*[nNeE"*]"

" Numbers
syn match amiNumber "\<\d\+\>"

" Variables
syn match amiVar "\$[a-zA-Z_][a-zA-Z0-9_]*"
syn match amiVar "\$\$"

" Parameters
syn region amiSubst start="<\a" end=">" oneline contains=amiVar
syn match amiSubst "<\$\$>"

" Devices / assigns / paths
syn match amiPath "\<[a-zA-Z][a-zA-Z0-9]*:[^ \t]*"

" Redirection
syn match amiOperator ">>"
syn match amiOperator "[<>|]"

" Control flow
syn region amiIfBlock matchgroup=amiConditional start="\<IF\>" matchgroup=amiConditional end="\<ENDIF\>" contains=ALLBUT,amiIfError
syn keyword amiIfError ELSE ENDIF
syn keyword amiElse contained ELSE
syn keyword amiConditional SKIP ENDSKIP
syn keyword amiLabel LAB
syn keyword amiRepeat FOREACH

" Conditions
syn keyword amiCondition contained NOT WARN ERROR FAIL EQ GT GE VAL EXISTS

" Echo
syn region amiEcho matchgroup=amiCommand start="\<echo\>" end="$" oneline contains=amiComment,amiVar,amiSubst,amiBacktick,amiEscape

" Commands
syn keyword amiCommand ADDAUDIOMODES
syn keyword amiCommand ADDBUFFERS
syn keyword amiCommand ADDDATATYPES
syn keyword amiCommand ADDMONITOR
syn keyword amiCommand ADDNETINTERFACE
syn keyword amiCommand ADDNETROUTE
syn keyword amiCommand ALIAS
syn keyword amiCommand APPLISTINFO
syn keyword amiCommand ARP
syn keyword amiCommand ASK
syn keyword amiCommand ASSIGN
syn keyword amiCommand AVAIL
syn keyword amiCommand BINDDRIVERS
syn keyword amiCommand BINDMONITOR
syn keyword amiCommand BREAK
syn keyword amiCommand BUILDMAPTABLE
syn keyword amiCommand CACHESTAT
syn keyword amiCommand CD
syn keyword amiCommand CHANGETASKPRI
syn keyword amiCommand CHARSETCONVERT
syn keyword amiCommand CLIP
syn keyword amiCommand CLOCK
syn keyword amiCommand CMD
syn keyword amiCommand CONCLIP
syn keyword amiCommand CONFIGURENETINTERFACE
syn keyword amiCommand COPY
syn keyword amiCommand COUNTLINES
syn keyword amiCommand CPU
syn keyword amiCommand CROSSDOS
syn keyword amiCommand CUT
syn keyword amiCommand DATE
syn keyword amiCommand DELETE
syn keyword amiCommand DELETENETROUTE
syn keyword amiCommand DIR
syn keyword amiCommand DISKCHANGE
syn keyword amiCommand DISKCOPY
syn keyword amiCommand DISKDOCTOR
syn keyword amiCommand DISMOUNT
syn keyword amiCommand ENDCLI
syn keyword amiCommand ENDSHELL
syn keyword amiCommand EVAL
syn keyword amiCommand EXECUTE
syn keyword amiCommand FAILAT
syn keyword amiCommand FAULT
syn keyword amiCommand FDTOOL
syn keyword amiCommand FILENOTE
syn keyword amiCommand FILESIZE
syn keyword amiCommand FORMAT
syn keyword amiCommand GET
syn keyword amiCommand GETENV
syn keyword amiCommand GETNETSTATUS
syn keyword amiCommand GROUP
syn keyword amiCommand HELP
syn keyword amiCommand HI
syn keyword amiCommand HISTORY
syn keyword amiCommand IHELP
syn keyword amiCommand INFO
syn keyword amiCommand INITPRINTER
syn keyword amiCommand INPUT
syn keyword amiCommand INSTALL
syn keyword amiCommand INTELLIFONT
syn keyword amiCommand IPMON
syn keyword amiCommand IPNAT
syn keyword amiCommand JOIN
syn keyword amiCommand KDEBUG
syn keyword amiCommand LAB
syn keyword amiCommand LIST
syn keyword amiCommand LOADMONDRVS
syn keyword amiCommand LOADRESOURCE
syn keyword amiCommand LOADWB
syn keyword amiCommand LOCALE
syn keyword amiCommand LOCK
syn keyword amiCommand MAKEDIR
syn keyword amiCommand MAKELINK
syn keyword amiCommand MEMSTAT
syn keyword amiCommand MORE
syn keyword amiCommand MOUNT
syn keyword amiCommand MOUNTINFO
syn keyword amiCommand MOVE
syn keyword amiCommand NETLOGVIEWER
syn keyword amiCommand NETSHUTDOWN
syn keyword amiCommand NEWCLI
syn keyword amiCommand NEWSHELL
syn keyword amiCommand OWNER
syn keyword amiCommand PATH
syn keyword amiCommand PATHPART
syn keyword amiCommand PIPE
syn keyword amiCommand POINTER
syn keyword amiCommand POOLSTAT
syn keyword amiCommand POPCD
syn keyword amiCommand PREPCARD
syn keyword amiCommand PROMPT
syn keyword amiCommand PROTECT
syn keyword amiCommand PUSHCD
syn keyword amiCommand QUIT
syn keyword amiCommand REBOOT
syn keyword amiCommand RELABEL
syn keyword amiCommand RELOADAPPLIST
syn keyword amiCommand REMOVENETINTERFACE
syn keyword amiCommand REMRAD
syn keyword amiCommand RENAME
syn keyword amiCommand REQUESTCHOICE
syn keyword amiCommand REQUESTFILE
syn keyword amiCommand REQUESTSTRING
syn keyword amiCommand RESIDENT
syn keyword amiCommand ROADSHOWCONTROL
syn keyword amiCommand RUN
syn keyword amiCommand RX
syn keyword amiCommand RXC
syn keyword amiCommand RXLIB
syn keyword amiCommand RXSET
syn keyword amiCommand SAY
syn keyword amiCommand SEARCH
syn keyword amiCommand SET
syn keyword amiCommand SETCLOCK
syn keyword amiCommand SETDATE
syn keyword amiCommand SETDOSDEBUG
syn keyword amiCommand SETENV
syn keyword amiCommand SETFONT
syn keyword amiCommand SETFONTCHARSET
syn keyword amiCommand SETKEYBOARD
syn keyword amiCommand SETMAP
syn keyword amiCommand SETPATCH
syn keyword amiCommand SHOW68LOADS
syn keyword amiCommand SHOWAPPLIST
syn keyword amiCommand SHOWNETSTATUS
syn keyword amiCommand SMARTCTL
syn keyword amiCommand SORT
syn keyword amiCommand SOUNDPLAYER
syn keyword amiCommand STACK
syn keyword amiCommand STATUS
syn keyword amiCommand SWAPCD
syn keyword amiCommand TYPE
syn keyword amiCommand UNALIAS
syn keyword amiCommand UNSET
syn keyword amiCommand UNSETENV
syn keyword amiCommand UPTIME
syn keyword amiCommand URLOPEN
syn keyword amiCommand VERSION
syn keyword amiCommand WAIT
syn keyword amiCommand WAITFORPORT
syn keyword amiCommand WBRUN
syn keyword amiCommand WBSTARTUPCTRL
syn keyword amiCommand WHICH
syn keyword amiCommand WHY

" Options
syn keyword amiOption ADD
syn keyword amiOption ALL
syn keyword amiOption APPEND
syn keyword amiOption BACK
syn keyword amiOption BODY
syn keyword amiOption BUF
syn keyword amiOption BUFFER
syn keyword amiOption CASE
syn keyword amiOption CHARSET
syn keyword amiOption CHECK
syn keyword amiOption CLEAR
syn keyword amiOption CLONE
syn keyword amiOption COPYLINKS
syn keyword amiOption DATES
syn keyword amiOption DEBUG
syn keyword amiOption DEVICE
syn keyword amiOption DIRS
syn keyword amiOption DRIVE
syn keyword amiOption FILE
syn keyword amiOption FILES
syn keyword amiOption FOLLOWLINKS
syn keyword amiOption FORCE
syn keyword amiOption FROM
syn keyword amiOption FULL
syn keyword amiOption HARD
syn keyword amiOption INTERACTIVE
syn keyword amiOption LFORMAT
syn keyword amiOption LOAD
syn keyword amiOption LOCK
syn keyword amiOption MULTI
syn keyword amiOption NAME
syn keyword amiOption NEGATIVE
syn keyword amiOption NOHEAD
syn keyword amiOption NONUM
syn keyword amiOption NOREPLACE
syn keyword amiOption NOREQ
syn keyword amiOption NUMERIC
syn keyword amiOption OFF
syn keyword amiOption ON
syn keyword amiOption PATTERN
syn keyword amiOption POSITIVE
syn keyword amiOption PREPEND
syn keyword amiOption PUBSCREEN
syn keyword amiOption QUICK
syn keyword amiOption QUIET
syn keyword amiOption REMOVE
syn keyword amiOption REPLACE
syn keyword amiOption RESET
syn keyword amiOption SAVE
syn keyword amiOption SHOW
syn keyword amiOption SINCE
syn keyword amiOption SOFT
syn keyword amiOption SORT
syn keyword amiOption SUB
syn keyword amiOption TIMEOUT
syn keyword amiOption TITLE
syn keyword amiOption TO
syn keyword amiOption UNLOCK
syn keyword amiOption UPTO
syn keyword amiOption VERBOSE
syn keyword amiOption WITH

" Comments
syn match amiComment ";.*$" contains=amiTodo,@Spell
syn match amiComment "^\.\s.*$" contains=amiTodo,@Spell
syn match amiComment "^\.$"

" Miscellaneous
syn keyword amiTodo contained TODO FIXME XXX NOTE
syn region amiBacktick start="`" end="`" oneline

" Define the default highlighting.
if !exists("skip_amiga_syntax_inits")
    hi def link amiBacktick Special
    hi def link amiCommand Statement
    hi def link amiComment Comment
    hi def link amiCondition Special
    hi def link amiConditional Conditional
    hi def link amiDirective PreProc
    hi def link amiEcho String
    hi def link amiElse Conditional
    hi def link amiEscape SpecialChar
    hi def link amiIfError Error
    hi def link amiLabel Label
    hi def link amiNumber Number
    hi def link amiOperator Operator
    hi def link amiOption Identifier
    hi def link amiPath Type
    hi def link amiRepeat Repeat
    hi def link amiString String
    hi def link amiSubst Special
    hi def link amiTemplate Type
    hi def link amiTodo Todo
    hi def link amiVar Special
endif

let b:current_syntax = "amiga"
