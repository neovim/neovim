" Vim syntax file
" Language:	WinBatch/Webbatch (*.wbt, *.web)
" Maintainer:	dominique@mggen.com
" URL:		http://www.mggen.com/vim/syntax/winbatch.zip
" Last change:	2001 May 10

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn case ignore

syn keyword winbatchCtl	if then else endif break end return exit next
syn keyword winbatchCtl while for gosub goto switch select to case
syn keyword winbatchCtl endselect endwhile endselect endswitch

" String
syn region  winbatchVar		start=+%+  end=+%+
" %var% in strings
syn region  winbatchString	start=+"+  end=+"+ contains=winbatchVar

syn match winbatchComment	";.*$"
syn match winbatchLabel		"^\ *:[0-9a-zA-Z_\-]\+\>"

" constant (bezgin by @)
syn match winbatchConstant	"@[0_9a-zA-Z_\-]\+"

" number
syn match winbatchNumber	"\<[0-9]\+\(u\=l\=\|lu\|f\)\>"

syn keyword winbatchImplicit aboveicons acc_attrib acc_chng_nt acc_control acc_create
syn keyword winbatchImplicit acc_delete acc_full_95 acc_full_nt acc_list acc_pfull_nt
syn keyword winbatchImplicit acc_pmang_nt acc_print_nt acc_read acc_read_95 acc_read_nt
syn keyword winbatchImplicit acc_write amc arrange ascending attr_a attr_a attr_ci attr_ci
syn keyword winbatchImplicit attr_dc attr_dc attr_di attr_di attr_dm attr_dm attr_h attr_h
syn keyword winbatchImplicit attr_ic attr_ic attr_p attr_p attr_ri attr_ri attr_ro attr_ro
syn keyword winbatchImplicit attr_sh attr_sh attr_sy attr_sy attr_t attr_t attr_x attr_x
syn keyword winbatchImplicit avogadro backscan boltzmann cancel capslock check columns
syn keyword winbatchImplicit commonformat cr crlf ctrl default default deg2rad descending
syn keyword winbatchImplicit disable drive electric enable eulers false faraday float8
syn keyword winbatchImplicit fwdscan gftsec globalgroup gmtsec goldenratio gravitation hidden
syn keyword winbatchImplicit icon lbutton lclick ldblclick lf lightmps lightmtps localgroup
syn keyword winbatchImplicit magfield major mbokcancel mbutton mbyesno mclick mdblclick minor
syn keyword winbatchImplicit msformat multiple ncsaformat no none none noresize normal
syn keyword winbatchImplicit notify nowait numlock off on open parsec parseonly pi
syn keyword winbatchImplicit planckergs planckjoules printer rad2deg rbutton rclick rdblclick
syn keyword winbatchImplicit regclasses regcurrent regmachine regroot regusers rows save
syn keyword winbatchImplicit scrolllock server shift single sorted stack string tab tile
syn keyword winbatchImplicit true uncheck unsorted wait wholesection word1 word2 word4 yes
syn keyword winbatchImplicit zoomed about abs acos addextender appexist appwaitclose asin
syn keyword winbatchImplicit askfilename askfiletext askitemlist askline askpassword askyesno
syn keyword winbatchImplicit atan average beep binaryalloc binarycopy binaryeodget binaryeodset
syn keyword winbatchImplicit binaryfree binaryhashrec binaryincr binaryincr2 binaryincr4
syn keyword winbatchImplicit binaryincrflt binaryindex binaryindexnc binaryoletype binarypeek
syn keyword winbatchImplicit binarypeek2 binarypeek4 binarypeekflt binarypeekstr binarypoke
syn keyword winbatchImplicit binarypoke2 binarypoke4 binarypokeflt binarypokestr binaryread
syn keyword winbatchImplicit binarysort binarystrcnt binarywrite boxbuttondraw boxbuttonkill
syn keyword winbatchImplicit boxbuttonstat boxbuttonwait boxcaption boxcolor
syn keyword winbatchImplicit boxdataclear boxdatatag
syn keyword winbatchImplicit boxdestroy boxdrawcircle boxdrawline boxdrawrect boxdrawtext
syn keyword winbatchImplicit boxesup boxmapmode boxnew boxopen boxpen boxshut boxtext boxtextcolor
syn keyword winbatchImplicit boxtextfont boxtitle boxupdates break buttonnames by call
syn keyword winbatchImplicit callext ceiling char2num clipappend clipget clipput
syn keyword winbatchImplicit continue cos cosh datetime
syn keyword winbatchImplicit ddeexecute ddeinitiate ddepoke dderequest ddeterminate
syn keyword winbatchImplicit ddetimeout debug debugdata decimals delay dialog
syn keyword winbatchImplicit dialogbox dirattrget dirattrset dirchange direxist
syn keyword winbatchImplicit dirget dirhome diritemize dirmake dirremove dirrename
syn keyword winbatchImplicit dirwindows diskexist diskfree diskinfo diskscan disksize
syn keyword winbatchImplicit diskvolinfo display dllcall dllfree dllhinst dllhwnd dllload
syn keyword winbatchImplicit dosboxcursorx dosboxcursory dosboxgetall dosboxgetdata
syn keyword winbatchImplicit dosboxheight dosboxscrmode dosboxversion dosboxwidth dosversion
syn keyword winbatchImplicit drop edosgetinfo edosgetvar edoslistvars edospathadd edospathchk
syn keyword winbatchImplicit edospathdel edossetvar
syn keyword winbatchImplicit endsession envgetinfo envgetvar environment
syn keyword winbatchImplicit environset envitemize envlistvars envpathadd envpathchk
syn keyword winbatchImplicit envpathdel envsetvar errormode exclusive execute exetypeinfo
syn keyword winbatchImplicit exp fabs fileappend fileattrget fileattrset fileclose
syn keyword winbatchImplicit filecompare filecopy filedelete fileexist fileextension filefullname
syn keyword winbatchImplicit fileitemize filelocate filemapname filemove filenameeval1
syn keyword winbatchImplicit filenameeval2 filenamelong filenameshort fileopen filepath
syn keyword winbatchImplicit fileread filerename fileroot filesize filetimecode filetimeget
syn keyword winbatchImplicit filetimeset filetimetouch fileverinfo filewrite fileymdhms
syn keyword winbatchImplicit findwindow floor getexacttime gettickcount
syn keyword winbatchImplicit iconarrange iconreplace ignoreinput inidelete inideletepvt
syn keyword winbatchImplicit iniitemize iniitemizepvt iniread inireadpvt iniwrite iniwritepvt
syn keyword winbatchImplicit installfile int intcontrol isdefined isfloat isint iskeydown
syn keyword winbatchImplicit islicensed isnumber itemcount itemextract iteminsert itemlocate
syn keyword winbatchImplicit itemremove itemselect itemsort keytoggleget keytoggleset
syn keyword winbatchImplicit lasterror log10 logdisk loge max message min mod mouseclick
syn keyword winbatchImplicit mouseclickbtn mousedrag mouseinfo mousemove msgtextget n3attach
syn keyword winbatchImplicit n3captureend n3captureprt n3chgpassword n3detach n3dirattrget
syn keyword winbatchImplicit n3dirattrset n3drivepath n3drivepath2 n3drivestatus n3fileattrget
syn keyword winbatchImplicit n3fileattrset n3getloginid n3getmapped n3getnetaddr n3getuser
syn keyword winbatchImplicit n3getuserid n3logout n3map n3mapdelete n3mapdir n3maproot n3memberdel
syn keyword winbatchImplicit n3memberget n3memberset n3msgsend n3msgsendall n3serverinfo
syn keyword winbatchImplicit n3serverlist n3setsrchdrv n3usergroups n3version n4attach
syn keyword winbatchImplicit n4captureend n4captureprt n4chgpassword n4detach n4dirattrget
syn keyword winbatchImplicit n4dirattrset n4drivepath n4drivestatus n4fileattrget n4fileattrset
syn keyword winbatchImplicit n4getloginid n4getmapped n4getnetaddr n4getuser n4getuserid
syn keyword winbatchImplicit n4login n4logout n4map n4mapdelete n4mapdir n4maproot n4memberdel
syn keyword winbatchImplicit n4memberget n4memberset n4msgsend n4msgsendall n4serverinfo
syn keyword winbatchImplicit n4serverlist n4setsrchdrv n4usergroups n4version netadddrive
syn keyword winbatchImplicit netaddprinter netcancelcon netdirdialog netgetcon netgetuser
syn keyword winbatchImplicit netinfo netresources netversion num2char objectclose
syn keyword winbatchImplicit objectopen parsedata pause playmedia playmidi playwaveform
syn keyword winbatchImplicit print random regapp regclosekey regconnect regcreatekey
syn keyword winbatchImplicit regdeletekey regdelvalue regentrytype regloadhive regopenkey
syn keyword winbatchImplicit regquerybin regquerydword regqueryex regqueryexpsz regqueryitem
syn keyword winbatchImplicit regquerykey regquerymulsz regqueryvalue regsetbin
syn keyword winbatchImplicit regsetdword regsetex regsetexpsz regsetmulsz regsetvalue
syn keyword winbatchImplicit regunloadhive reload reload rtstatus run runenviron
syn keyword winbatchImplicit runexit runhide runhidewait runicon runiconwait runshell runwait
syn keyword winbatchImplicit runzoom runzoomwait sendkey sendkeyschild sendkeysto
syn keyword winbatchImplicit sendmenusto shellexecute shortcutedit shortcutextra shortcutinfo
syn keyword winbatchImplicit shortcutmake sin sinh snapshot sounds sqrt
syn keyword winbatchImplicit srchfree srchinit srchnext strcat strcharcount strcmp
syn keyword winbatchImplicit strfill strfix strfixchars stricmp strindex strlen
syn keyword winbatchImplicit strlower strreplace strscan strsub strtrim strupper
syn keyword winbatchImplicit tan tanh tcpaddr2host tcpftpchdir tcpftpclose tcpftpget
syn keyword winbatchImplicit tcpftplist tcpftpmode tcpftpopen tcpftpput tcphost2addr tcphttpget
syn keyword winbatchImplicit tcphttppost tcpparmget tcpparmset tcpping tcpsmtp terminate
syn keyword winbatchImplicit textbox textboxsort textoutbufdel textoutbuffer textoutdebug
syn keyword winbatchImplicit textoutfree textoutinfo textoutreset textouttrack textouttrackb
syn keyword winbatchImplicit textouttrackp textoutwait textselect timeadd timedate
syn keyword winbatchImplicit timedelay timediffdays timediffsecs timejulianday timejultoymd
syn keyword winbatchImplicit timesubtract timewait timeymdhms version versiondll
syn keyword winbatchImplicit w3addcon w3cancelcon w3dirbrowse w3getcaps w3getcon w3netdialog
syn keyword winbatchImplicit w3netgetuser w3prtbrowse w3version w95accessadd w95accessdel
syn keyword winbatchImplicit w95adddrive w95addprinter w95cancelcon w95dirdialog w95getcon
syn keyword winbatchImplicit w95getuser w95resources w95shareadd w95sharedel w95shareset
syn keyword winbatchImplicit w95version waitforkey wallpaper webbaseconv webcloselog
syn keyword winbatchImplicit webcmddata webcondata webcounter webdatdata webdumperror webhashcode
syn keyword winbatchImplicit webislocal weblogline webopenlog webout weboutfile webparamdata
syn keyword winbatchImplicit webparamnames websettimeout webverifycard winactivate
syn keyword winbatchImplicit winactivchild winarrange winclose winclosenot winconfig winexename
syn keyword winbatchImplicit winexist winparset winparget winexistchild wingetactive
syn keyword winbatchImplicit winhelp winhide winiconize winidget winisdos winitemchild
syn keyword winbatchImplicit winitemize winitemnameid winmetrics winname winparmget
syn keyword winbatchImplicit winparmset winplace winplaceget winplaceset
syn keyword winbatchImplicit winposition winresources winshow winstate winsysinfo
syn keyword winbatchImplicit wintitle winversion winwaitchild winwaitclose winwaitexist
syn keyword winbatchImplicit winzoom wnaddcon wncancelcon wncmptrinfo wndialog
syn keyword winbatchImplicit wndlgbrowse wndlgcon wndlgcon2 wndlgcon3
syn keyword winbatchImplicit wndlgcon4 wndlgdiscon wndlgnoshare wndlgshare wngetcaps
syn keyword winbatchImplicit wngetcon wngetuser wnnetnames wnrestore wnservers wnsharecnt
syn keyword winbatchImplicit wnsharename wnsharepath wnshares wntaccessadd wntaccessdel
syn keyword winbatchImplicit wntaccessget wntadddrive wntaddprinter wntcancelcon wntdirdialog
syn keyword winbatchImplicit wntgetcon wntgetuser wntlistgroups wntmemberdel wntmemberget
syn keyword winbatchImplicit wntmembergrps wntmemberlist wntmemberset wntresources wntshareadd
syn keyword winbatchImplicit wntsharedel wntshareset wntversion wnversion wnwrkgroups wwenvunload
syn keyword winbatchImplicit xbaseconvert xcursorset xdisklabelget xdriveready xextenderinfo
syn keyword winbatchImplicit xgetchildhwnd xgetelapsed xhex xmemcompact xmessagebox
syn keyword winbatchImplicit xsendmessage xverifyccard yield

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_winbatch_syntax_inits")
  if version < 508
    let did_winbatch_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink winbatchLabel		PreProc
  HiLink winbatchCtl		Operator
  HiLink winbatchStatement	Statement
  HiLink winbatchTodo		Todo
  HiLink winbatchString		String
  HiLink winbatchVar		Type
  HiLink winbatchComment	Comment
  HiLink winbatchImplicit	Special
  HiLink winbatchNumber		Number
  HiLink winbatchConstant	StorageClass

  delcommand HiLink
endif

let b:current_syntax = "winbatch"

" vim: ts=8
