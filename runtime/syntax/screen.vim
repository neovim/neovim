" Vim syntax file
" Language:         screen(1) configuration file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2010-01-03

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn match   screenEscape    '\\.'

syn keyword screenTodo      contained TODO FIXME XXX NOTE

syn region  screenComment   display oneline start='#' end='$'
                          \ contains=screenTodo,@Spell

syn region  screenString    display oneline start=+"+ skip=+\\"+ end=+"+
                          \ contains=screenVariable,screenSpecial

syn region  screenLiteral   display oneline start=+'+ skip=+\\'+ end=+'+

syn match   screenVariable  contained display '$\%(\h\w*\|{\h\w*}\)'

syn keyword screenBoolean   on off

syn match   screenNumbers   display '\<\d\+\>'

syn match   screenSpecials  contained
                          \ '%\%([%aAdDhlmMstuwWyY?:{]\|[0-9]*n\|0?cC\)'

syn keyword screenCommands
                          \ acladd
                          \ aclchg
                          \ acldel
                          \ aclgrp
                          \ aclumask
                          \ activity
                          \ addacl
                          \ allpartial
                          \ altscreen
                          \ at
                          \ attrcolor
                          \ autodetach
                          \ autonuke
                          \ backtick
                          \ bce
                          \ bd_bc_down
                          \ bd_bc_left
                          \ bd_bc_right
                          \ bd_bc_up
                          \ bd_bell
                          \ bd_braille_table
                          \ bd_eightdot
                          \ bd_info
                          \ bd_link
                          \ bd_lower_left
                          \ bd_lower_right
                          \ bd_ncrc
                          \ bd_port
                          \ bd_scroll
                          \ bd_skip
                          \ bd_start_braille
                          \ bd_type
                          \ bd_upper_left
                          \ bd_upper_right
                          \ bd_width
                          \ bell
                          \ bell_msg
                          \ bind
                          \ bindkey
                          \ blanker
                          \ blankerprg
                          \ break
                          \ breaktype
                          \ bufferfile
                          \ c1
                          \ caption
                          \ chacl
                          \ charset
                          \ chdir
                          \ clear
                          \ colon
                          \ command
                          \ compacthist
                          \ console
                          \ copy
                          \ crlf
                          \ debug
                          \ defautonuke
                          \ defbce
                          \ defbreaktype
                          \ defc1
                          \ defcharset
                          \ defencoding
                          \ defescape
                          \ defflow
                          \ defgr
                          \ defhstatus
                          \ defkanji
                          \ deflog
                          \ deflogin
                          \ defmode
                          \ defmonitor
                          \ defnonblock
                          \ defobuflimit
                          \ defscrollback
                          \ defshell
                          \ defsilence
                          \ defslowpaste
                          \ defutf8
                          \ defwrap
                          \ defwritelock
                          \ detach
                          \ digraph
                          \ dinfo
                          \ displays
                          \ dumptermcap
                          \ echo
                          \ encoding
                          \ escape
                          \ eval
                          \ exec
                          \ fit
                          \ flow
                          \ focus
                          \ gr
                          \ hardcopy
                          \ hardcopy_append
                          \ hardcopydir
                          \ hardstatus
                          \ height
                          \ help
                          \ history
                          \ hstatus
                          \ idle
                          \ ignorecase
                          \ info
                          \ kanji
                          \ kill
                          \ lastmsg
                          \ layout
                          \ license
                          \ lockscreen
                          \ log
                          \ logfile
                          \ login
                          \ logtstamp
                          \ mapdefault
                          \ mapnotnext
                          \ maptimeout
                          \ markkeys
                          \ maxwin
                          \ meta
                          \ monitor
                          \ msgminwait
                          \ msgwait
                          \ multiuser
                          \ nethack
                          \ next
                          \ nonblock
                          \ number
                          \ obuflimit
                          \ only
                          \ other
                          \ partial
                          \ password
                          \ paste
                          \ pastefont
                          \ pow_break
                          \ pow_detach
                          \ pow_detach_msg
                          \ prev
                          \ printcmd
                          \ process
                          \ quit
                          \ readbuf
                          \ readreg
                          \ redisplay
                          \ register
                          \ remove
                          \ removebuf
                          \ reset
                          \ resize
                          \ screen
                          \ scrollback
                          \ select
                          \ sessionname
                          \ setenv
                          \ setsid
                          \ shell
                          \ shelltitle
                          \ silence
                          \ silencewait
                          \ sleep
                          \ slowpaste
                          \ sorendition
                          \ source
                          \ split
                          \ startup_message
                          \ stuff
                          \ su
                          \ suspend
                          \ term
                          \ termcap
                          \ termcapinfo
                          \ terminfo
                          \ time
                          \ title
                          \ umask
                          \ unsetenv
                          \ utf8
                          \ vbell
                          \ vbell_msg
                          \ vbellwait
                          \ verbose
                          \ version
                          \ wall
                          \ width
                          \ windowlist
                          \ windows
                          \ wrap
                          \ writebuf
                          \ writelock
                          \ xoff
                          \ xon
                          \ zmodem
                          \ zombie

hi def link screenEscape    Special
hi def link screenComment   Comment
hi def link screenTodo      Todo
hi def link screenString    String
hi def link screenLiteral   String
hi def link screenVariable  Identifier
hi def link screenBoolean   Boolean
hi def link screenNumbers   Number
hi def link screenSpecials  Special
hi def link screenCommands  Keyword

let b:current_syntax = "screen"

let &cpo = s:cpo_save
unlet s:cpo_save
