" Vim syntax file
" Language:    Hamster Scripting Language
" Maintainer:  David Fishburn <fishburn@ianywhere.com>
" Last Change: Sun Oct 24 2004 7:11:50 PM
" Version:     2.0.6.0

" Description: Hamster Classic
" Hamster is a local server for news and mail. It's a windows-32-bit-program.
" It allows the use of multiple news- and mailserver and combines them to one
" mail- and newsserver for the news/mail-client. It load faster than a normal
" newsreader because many threads can run simultaneous. It contains scorefile
" for news and mail, a built-in script language, the GUI allows translation to
" other languages, it can be used in a network and that's not all features...
"
" quit when a syntax file was already loaded
if exists("b:current_syntax")
    finish
endif

syn case ignore

syn keyword hamsterSpecial abs
syn keyword hamsterSpecial artaddheader
syn keyword hamsterSpecial artalloc
syn keyword hamsterSpecial artdelheader
syn keyword hamsterSpecial artfree
syn keyword hamsterSpecial artgetbody
syn keyword hamsterSpecial artgetheader
syn keyword hamsterSpecial artgetheaders
syn keyword hamsterSpecial artgettext
syn keyword hamsterSpecial artheaderexists
syn keyword hamsterSpecial artload
syn keyword hamsterSpecial artsave
syn keyword hamsterSpecial artsetbody
syn keyword hamsterSpecial artsetheader
syn keyword hamsterSpecial artsetheaders
syn keyword hamsterSpecial artsettext
syn keyword hamsterSpecial assert
syn keyword hamsterSpecial atadd
syn keyword hamsterSpecial atclear
syn keyword hamsterSpecial atcount
syn keyword hamsterSpecial ateverymins
syn keyword hamsterSpecial atexecute
syn keyword hamsterSpecial atfrom
syn keyword hamsterSpecial atondays
syn keyword hamsterSpecial atsubfunction
syn keyword hamsterSpecial atuntil
syn keyword hamsterSpecial beep
syn keyword hamsterSpecial break
syn keyword hamsterSpecial chr
syn keyword hamsterSpecial clearxcounter
syn keyword hamsterSpecial clipread
syn keyword hamsterSpecial clipwrite
syn keyword hamsterSpecial const
syn keyword hamsterSpecial constenum
syn keyword hamsterSpecial continue
syn keyword hamsterSpecial copy
syn keyword hamsterSpecial debug
syn keyword hamsterSpecial dec
syn keyword hamsterSpecial decodebase64
syn keyword hamsterSpecial decodeqp
syn keyword hamsterSpecial decodetime
syn keyword hamsterSpecial decxcounter
syn keyword hamsterSpecial delete
syn keyword hamsterSpecial deletehostsentry
syn keyword hamsterSpecial digest
syn keyword hamsterSpecial dirchange
syn keyword hamsterSpecial dircurrent
syn keyword hamsterSpecial direxists
syn keyword hamsterSpecial dirmake
syn keyword hamsterSpecial dirremove
syn keyword hamsterSpecial dirsystem
syn keyword hamsterSpecial dirwindows
syn keyword hamsterSpecial diskfreekb
syn keyword hamsterSpecial dllcall
syn keyword hamsterSpecial dllfree
syn keyword hamsterSpecial dlllasterror
syn keyword hamsterSpecial dllload
syn keyword hamsterSpecial dump
syn keyword hamsterSpecial encodetime
syn keyword hamsterSpecial entercontext
syn keyword hamsterSpecial errcatch
syn keyword hamsterSpecial errline
syn keyword hamsterSpecial errlineno
syn keyword hamsterSpecial errmodule
syn keyword hamsterSpecial errmsg
syn keyword hamsterSpecial errnum
syn keyword hamsterSpecial error
syn keyword hamsterSpecial errsender
syn keyword hamsterSpecial eval
syn keyword hamsterSpecial eventclose
syn keyword hamsterSpecial eventcreate
syn keyword hamsterSpecial eventmultiplewait
syn keyword hamsterSpecial eventpulse
syn keyword hamsterSpecial eventreset
syn keyword hamsterSpecial eventset
syn keyword hamsterSpecial eventwait
syn keyword hamsterSpecial execute
syn keyword hamsterSpecial false
syn keyword hamsterSpecial filecopy
syn keyword hamsterSpecial filedelete
syn keyword hamsterSpecial fileexists
syn keyword hamsterSpecial filemove
syn keyword hamsterSpecial filerename
syn keyword hamsterSpecial filesize
syn keyword hamsterSpecial filetime
syn keyword hamsterSpecial getenv
syn keyword hamsterSpecial getprocessidentifier
syn keyword hamsterSpecial getuptimedays
syn keyword hamsterSpecial getuptimehours
syn keyword hamsterSpecial getuptimemins
syn keyword hamsterSpecial getuptimesecs
syn keyword hamsterSpecial gosub
syn keyword hamsterSpecial goto
syn keyword hamsterSpecial hex
syn keyword hamsterSpecial icase
syn keyword hamsterSpecial iif
syn keyword hamsterSpecial inc
syn keyword hamsterSpecial incxcounter
syn keyword hamsterSpecial inidelete
syn keyword hamsterSpecial inierasesection
syn keyword hamsterSpecial iniread
syn keyword hamsterSpecial iniwrite
syn keyword hamsterSpecial inputbox
syn keyword hamsterSpecial inputpw
syn keyword hamsterSpecial int
syn keyword hamsterSpecial isint
syn keyword hamsterSpecial isstr
syn keyword hamsterSpecial leavecontext
syn keyword hamsterSpecial len
syn keyword hamsterSpecial listadd
syn keyword hamsterSpecial listalloc
syn keyword hamsterSpecial listappend
syn keyword hamsterSpecial listbox
syn keyword hamsterSpecial listclear
syn keyword hamsterSpecial listcount
syn keyword hamsterSpecial listdelete
syn keyword hamsterSpecial listdirs
syn keyword hamsterSpecial listexists
syn keyword hamsterSpecial listfiles
syn keyword hamsterSpecial listfiles
syn keyword hamsterSpecial listfree
syn keyword hamsterSpecial listget
syn keyword hamsterSpecial listgetkey
syn keyword hamsterSpecial listgettag
syn keyword hamsterSpecial listgettext
syn keyword hamsterSpecial listindexof
syn keyword hamsterSpecial listinsert
syn keyword hamsterSpecial listload
syn keyword hamsterSpecial listrasentries
syn keyword hamsterSpecial listsave
syn keyword hamsterSpecial listset
syn keyword hamsterSpecial listsetkey
syn keyword hamsterSpecial listsettag
syn keyword hamsterSpecial listsettext
syn keyword hamsterSpecial listsort
syn keyword hamsterSpecial localhostaddr
syn keyword hamsterSpecial localhostname
syn keyword hamsterSpecial lookuphostaddr
syn keyword hamsterSpecial lookuphostname
syn keyword hamsterSpecial lowercase
syn keyword hamsterSpecial memalloc
syn keyword hamsterSpecial memforget
syn keyword hamsterSpecial memfree
syn keyword hamsterSpecial memgetint
syn keyword hamsterSpecial memgetstr
syn keyword hamsterSpecial memsetint
syn keyword hamsterSpecial memsetstr
syn keyword hamsterSpecial memsize
syn keyword hamsterSpecial memvarptr
syn keyword hamsterSpecial msgbox
syn keyword hamsterSpecial ord
syn keyword hamsterSpecial paramcount
syn keyword hamsterSpecial paramstr
syn keyword hamsterSpecial popupbox
syn keyword hamsterSpecial pos
syn keyword hamsterSpecial print
syn keyword hamsterSpecial quit
syn keyword hamsterSpecial random
syn keyword hamsterSpecial randomize
syn keyword hamsterSpecial rasdial
syn keyword hamsterSpecial rasgetconnection
syn keyword hamsterSpecial rasgetip
syn keyword hamsterSpecial rashangup
syn keyword hamsterSpecial rasisconnected
syn keyword hamsterSpecial re_extract
syn keyword hamsterSpecial re_match
syn keyword hamsterSpecial re_parse
syn keyword hamsterSpecial re_split
syn keyword hamsterSpecial replace
syn keyword hamsterSpecial return
syn keyword hamsterSpecial runscript
syn keyword hamsterSpecial scriptpriority
syn keyword hamsterSpecial set
syn keyword hamsterSpecial sethostsentry_byaddr
syn keyword hamsterSpecial sethostsentry_byname
syn keyword hamsterSpecial setxcounter
syn keyword hamsterSpecial sgn
syn keyword hamsterSpecial shell
syn keyword hamsterSpecial sleep
syn keyword hamsterSpecial stopthread
syn keyword hamsterSpecial str
syn keyword hamsterSpecial syserrormessage
syn keyword hamsterSpecial testmailfilterline
syn keyword hamsterSpecial testnewsfilterline
syn keyword hamsterSpecial ticks
syn keyword hamsterSpecial time
syn keyword hamsterSpecial timegmt
syn keyword hamsterSpecial trace
syn keyword hamsterSpecial trim
syn keyword hamsterSpecial true
syn keyword hamsterSpecial uppercase
syn keyword hamsterSpecial utf7toucs16
syn keyword hamsterSpecial utf8toucs32
syn keyword hamsterSpecial var
syn keyword hamsterSpecial varset
syn keyword hamsterSpecial warning
syn keyword hamsterSpecial xcounter

" common functions
syn keyword hamsterFunction addlog
syn keyword hamsterFunction decodemimeheaderstring
syn keyword hamsterFunction decodetolocalcharset
syn keyword hamsterFunction gettasksactive
syn keyword hamsterFunction gettasksrun
syn keyword hamsterFunction gettaskswait
syn keyword hamsterFunction hamaddgroup
syn keyword hamsterFunction hamaddlog
syn keyword hamsterFunction hamaddpull
syn keyword hamsterFunction hamartcount
syn keyword hamsterFunction hamartdeletemid
syn keyword hamsterFunction hamartdeletemidingroup
syn keyword hamsterFunction hamartdeletenringroup
syn keyword hamsterFunction hamartimport
syn keyword hamsterFunction hamartlocatemid
syn keyword hamsterFunction hamartlocatemidingroup
syn keyword hamsterFunction hamartnomax
syn keyword hamsterFunction hamartnomin
syn keyword hamsterFunction hamarttext
syn keyword hamsterFunction hamarttextexport
syn keyword hamsterFunction hamchangepassword
syn keyword hamsterFunction hamcheckpurge
syn keyword hamsterFunction hamdelgroup
syn keyword hamsterFunction hamdelpull
syn keyword hamsterFunction hamdialogaddpull
syn keyword hamsterFunction hamdialogeditdirs
syn keyword hamsterFunction hamdialogmailkillfilelog
syn keyword hamsterFunction hamdialognewskillfilelog
syn keyword hamsterFunction hamdialogscripts
syn keyword hamsterFunction hamenvelopefrom
syn keyword hamsterFunction hamexepath
syn keyword hamsterFunction hamfetchmail
syn keyword hamsterFunction hamflush
syn keyword hamsterFunction hamgetstatus
syn keyword hamsterFunction hamgroupclose
syn keyword hamsterFunction hamgroupcount
syn keyword hamsterFunction hamgroupindex
syn keyword hamsterFunction hamgroupname
syn keyword hamsterFunction hamgroupnamebyhandle
syn keyword hamsterFunction hamgroupopen
syn keyword hamsterFunction hamgroupspath
syn keyword hamsterFunction hamhscpath
syn keyword hamsterFunction hamhsmpath
syn keyword hamsterFunction hamimapserver
syn keyword hamsterFunction hamisidle
syn keyword hamsterFunction hamlogspath
syn keyword hamsterFunction hammailexchange
syn keyword hamsterFunction hammailpath
syn keyword hamsterFunction hammailsoutpath
syn keyword hamsterFunction hammainfqdn
syn keyword hamsterFunction hammainwindow
syn keyword hamsterFunction hammessage
syn keyword hamsterFunction hammidfqdn
syn keyword hamsterFunction hamnewmail
syn keyword hamsterFunction hamnewserrpath
syn keyword hamsterFunction hamnewsjobsadd
syn keyword hamsterFunction hamnewsjobscheckactive
syn keyword hamsterFunction hamnewsjobsclear
syn keyword hamsterFunction hamnewsjobsdelete
syn keyword hamsterFunction hamnewsjobsfeed
syn keyword hamsterFunction hamnewsjobsgetcounter
syn keyword hamsterFunction hamnewsjobsgetparam
syn keyword hamsterFunction hamnewsjobsgetpriority
syn keyword hamsterFunction hamnewsjobsgetserver
syn keyword hamsterFunction hamnewsjobsgettype
syn keyword hamsterFunction hamnewsjobspost
syn keyword hamsterFunction hamnewsjobspostdef
syn keyword hamsterFunction hamnewsjobspull
syn keyword hamsterFunction hamnewsjobspulldef
syn keyword hamsterFunction hamnewsjobssetpriority
syn keyword hamsterFunction hamnewsjobsstart
syn keyword hamsterFunction hamnewsoutpath
syn keyword hamsterFunction hamnewspost
syn keyword hamsterFunction hamnewspull
syn keyword hamsterFunction hamnntpserver
syn keyword hamsterFunction hampassreload
syn keyword hamsterFunction hampath
syn keyword hamsterFunction hampop3server
syn keyword hamsterFunction hampostmaster
syn keyword hamsterFunction hampurge
syn keyword hamsterFunction hamrasdial
syn keyword hamsterFunction hamrashangup
syn keyword hamsterFunction hamrcpath
syn keyword hamsterFunction hamrebuildgloballists
syn keyword hamsterFunction hamrebuildhistory
syn keyword hamsterFunction hamrecoserver
syn keyword hamsterFunction hamreloadconfig
syn keyword hamsterFunction hamreloadipaccess
syn keyword hamsterFunction hamresetcounters
syn keyword hamsterFunction hamrotatelog
syn keyword hamsterFunction hamscorelist
syn keyword hamsterFunction hamscoretest
syn keyword hamsterFunction hamsendmail
syn keyword hamsterFunction hamsendmailauth
syn keyword hamsterFunction hamserverpath
syn keyword hamsterFunction hamsetlogin
syn keyword hamsterFunction hamshutdown
syn keyword hamsterFunction hamsmtpserver
syn keyword hamsterFunction hamstopalltasks
syn keyword hamsterFunction hamthreadcount
syn keyword hamsterFunction hamtrayicon
syn keyword hamsterFunction hamusenetacc
syn keyword hamsterFunction hamversion
syn keyword hamsterFunction hamwaitidle
syn keyword hamsterFunction raslasterror
syn keyword hamsterFunction rfctimezone
syn keyword hamsterFunction settasklimiter

syn keyword hamsterStatement if
syn keyword hamsterStatement else
syn keyword hamsterStatement elseif
syn keyword hamsterStatement endif
syn keyword hamsterStatement do
syn keyword hamsterStatement loop
syn keyword hamsterStatement while
syn keyword hamsterStatement endwhile
syn keyword hamsterStatement repeat
syn keyword hamsterStatement until
syn keyword hamsterStatement for
syn keyword hamsterStatement endfor
syn keyword hamsterStatement sub
syn keyword hamsterStatement endsub
syn keyword hamsterStatement label


" Strings and characters:
syn region hamsterString	start=+"+    end=+"+ contains=@Spell
syn region hamsterString	start=+'+    end=+'+ contains=@Spell

" Numbers:
syn match hamsterNumber		"-\=\<\d*\.\=[0-9_]\>"

" Comments:
syn region hamsterHashComment	start=/#/ end=/$/ contains=@Spell
syn cluster hamsterComment	contains=hamsterHashComment
syn sync ccomment hamsterHashComment

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link hamsterHashComment	Comment
hi def link hamsterSpecial	Special
hi def link hamsterStatement	Statement
hi def link hamsterString	String
hi def link hamsterFunction	Function


let b:current_syntax = "hamster"

" vim:sw=4
