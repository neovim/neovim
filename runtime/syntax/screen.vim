" Vim syntax file
" Language:             screen(1) configuration file
" Maintainer:           Aliaksei Budavei <0x000c70 AT gmail DOT com>
" Previous Maintainers: Dmitri Vereshchagin <dmitri.vereshchagin@gmail.com>
"                       Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2026 Jun 29

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn match   screenEscape    '\\.' contains=screenOctalNumber

syn keyword screenTodo      contained TODO FIXME XXX NOTE

syn region  screenComment   display oneline start='#' end='$'
                          \ contains=screenTodo,@Spell

syn region  screenString    display oneline start=+"+ skip=+\\"+ end=+"+
                          \ contains=screenVariable,screenSpecials,screenEscape

syn region  screenLiteral   display oneline start=+'+ skip=+\\'+ end=+'+

syn match   screenVariable  display '$\%(\h\w*\|{\h\w*}\)'

syn keyword screenBoolean   on off

syn match   screenDecimalNumber display '\<\d\+\>'
syn match   screenOctalNumber display '\<0\o\+\>'

" FIXME: Undocumented escape characters (winmsg.h): "g" (see commit
" 945ad5414), "N" (49f592e21), "p" (6ead6f557), "T" (60893c465).
syn region  screenSpecials  contained start=+%{+ end=+}+
syn match   screenSpecials  contained '%[%aAdeEfFghHlmNPsStTuxXyY?:]'
syn match   screenSpecials  contained '%\d*[n`=<>]' contains=screenSpecialsQualifier
syn match   screenSpecials  contained '%0\?[cC]' contains=screenSpecialsQualifier
syn match   screenSpecials  contained '%L\?[DMW]' contains=screenSpecialsQualifier
syn match   screenSpecials  contained '%-\?O' contains=screenSpecialsQualifier
syn match   screenSpecials  contained '%+\?p' contains=screenSpecialsQualifier
syn match   screenSpecials  contained '%[-+]\?L\?[w=<>]' contains=screenSpecialsQualifier
syn match   screenSpecialsQualifier contained '\d\+'
syn match   screenSpecialsQualifier contained '[-+L]'

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
                          \ bell
                          \ bell_msg
                          \ bind
                          \ bindkey
                          \ blanker
                          \ blankerprg
                          \ break
                          \ breaktype
                          \ bufferfile
                          \ bumpleft
                          \ bumpright
                          \ c1
                          \ caption
                          \ chacl
                          \ charset
                          \ chdir
                          \ cjkwidth
                          \ clear
                          \ collapse
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
                          \ defdynamictitle
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
                          \ defmousetrack
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
                          \ dynamictitle
                          \ echo
                          \ encoding
                          \ escape
                          \ eval
                          \ exec
                          \ fit
                          \ flow
                          \ focus
                          \ focusminsize
                          \ gr
                          \ group
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
                          \ mousetrack
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
                          \ rendition
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
                          \ sort
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
                          \ unbindall
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
                          \ zombie_timeout

syn keyword screenVersion5Commands
                          \ auth
                          \ multiinput
                          \ status
                          \ truecolor

" Braille navigation commands from a superset program Dotscreen (see some
" descriptions in doc/README.DOTSCREEN).
syn keyword dotscreenCommands
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

syn keyword screenDeprecatedCommands
                          \ debug
                          \ maxwin
                          \ nethack
                          \ password
                          \ time

hi def link screenEscape    Special
hi def link screenComment   Comment
hi def link screenTodo      Todo
hi def link screenString    String
hi def link screenLiteral   String
hi def link screenVariable  Identifier
hi def link screenBoolean   Boolean
hi def link screenNumbers   Number
hi def link screenDecimalNumber screenNumbers
hi def link screenOctalNumber screenNumbers
hi def link screenSpecials  Special
hi def link screenCommands  Keyword
hi def link screenSpecialsQualifier Underlined
hi def link screenVersion5Commands screenCommands
hi def link dotscreenCommands screenCommands

let b:current_syntax = "screen"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: sw=2 et
