" MUSHcode syntax file
" Maintainer: Rick Bird <nveid@nveid.com>
" Based on vim Syntax file by: Bek Oberin <gossamer@tertius.net.au>
" Last Updated: Fri Nov 04 20:28:15 2005
"
" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif


" regular mush functions

syntax keyword mushFunction contained @@ abs accent accname acos add after align
syntax keyword mushFunction contained allof alphamax alphamin and andflags
syntax keyword mushFunction contained andlflags andlpowers andpowers ansi aposs art
syntax keyword mushFunction contained asin atan atan2 atrlock attrcnt band baseconv
syntax keyword mushFunction contained beep before blank2tilde bnand bnot bor bound
syntax keyword mushFunction contained brackets break bxor cand cansee capstr case
syntax keyword mushFunction contained caseall cat ceil center checkpass children
syntax keyword mushFunction contained chr clone cmds cnetpost comp con config conn
syntax keyword mushFunction contained controls convsecs convtime convutcsecs cor
syntax keyword mushFunction contained cos create ctime ctu dec decrypt default
syntax keyword mushFunction contained delete die dig digest dist2d dist3d div
syntax keyword mushFunction contained division divscope doing downdiv dynhelp e
syntax keyword mushFunction contained edefault edit element elements elist elock
syntax keyword mushFunction contained emit empire empower encrypt endtag entrances
syntax keyword mushFunction contained eq escape etimefmt eval exit exp extract fdiv
syntax keyword mushFunction contained filter filterbool findable first firstof
syntax keyword mushFunction contained flags flip floor floordiv fmod fold
syntax keyword mushFunction contained folderstats followers following foreach
syntax keyword mushFunction contained fraction fullname functions get get_eval grab
syntax keyword mushFunction contained graball grep grepi gt gte hasattr hasattrp
syntax keyword mushFunction contained hasattrpval hasattrval hasdivpower hasflag
syntax keyword mushFunction contained haspower haspowergroup hastype height hidden
syntax keyword mushFunction contained home host hostname html idle idlesecs
syntax keyword mushFunction contained idle_average idle_times idle_total if ifelse
syntax keyword mushFunction contained ilev iname inc index indiv indivall insert
syntax keyword mushFunction contained inum ipaddr isdaylight isdbref isint isnum
syntax keyword mushFunction contained isword itemize items iter itext last lattr
syntax keyword mushFunction contained lcon lcstr ldelete ldivisions left lemit
syntax keyword mushFunction contained level lexits lflags link list lit ljust lmath
syntax keyword mushFunction contained ln lnum loc localize locate lock loctree log
syntax keyword mushFunction contained lparent lplayers lports lpos lsearch lsearchr
syntax keyword mushFunction contained lstats lt lte lthings lvcon lvexits lvplayers
syntax keyword mushFunction contained lvthings lwho mail maildstats mailfrom
syntax keyword mushFunction contained mailfstats mailstats mailstatus mailsubject
syntax keyword mushFunction contained mailtime map match matchall max mean median
syntax keyword mushFunction contained member merge mid min mix mod modulo modulus
syntax keyword mushFunction contained money mtime mudname mul munge mwho name nand
syntax keyword mushFunction contained nattr ncon nearby neq nexits next nor not
syntax keyword mushFunction contained nplayers nsemit nslemit nsoemit nspemit
syntax keyword mushFunction contained nsremit nszemit nthings null num nvcon
syntax keyword mushFunction contained nvexits nvplayers nvthings obj objeval objid
syntax keyword mushFunction contained objmem oemit ooref open or ord orflags
syntax keyword mushFunction contained orlflags orlpowers orpowers owner parent
syntax keyword mushFunction contained parse pcreate pemit pi pickrand playermem
syntax keyword mushFunction contained pmatch poll ports pos poss power powergroups
syntax keyword mushFunction contained powers powover program prompt pueblo quitprog
syntax keyword mushFunction contained quota r rand randword recv regedit regeditall
syntax keyword mushFunction contained regeditalli regediti regmatch regmatchi
syntax keyword mushFunction contained regrab regraball regraballi regrabi regrep
syntax keyword mushFunction contained regrepi remainder remit remove repeat replace
syntax keyword mushFunction contained rest restarts restarttime reswitch
syntax keyword mushFunction contained reswitchall reswitchalli reswitchi reverse
syntax keyword mushFunction contained revwords right rjust rloc rnum room root
syntax keyword mushFunction contained round s scan scramble search secs secure sent
syntax keyword mushFunction contained set setdiff setinter setq setr setunion sha0
syntax keyword mushFunction contained shl shr shuffle sign signal sin sort sortby
syntax keyword mushFunction contained soundex soundlike soundslike space spellnum
syntax keyword mushFunction contained splice sql sqlescape sqrt squish ssl
syntax keyword mushFunction contained starttime stats stddev step strcat strinsert
syntax keyword mushFunction contained stripaccents stripansi strlen strmatch
syntax keyword mushFunction contained strreplace sub subj switch switchall t table
syntax keyword mushFunction contained tag tagwrap tan tel terminfo textfile
syntax keyword mushFunction contained tilde2blank time timefmt timestring tr
syntax keyword mushFunction contained trigger trim trimpenn trimtiny trunc type u
syntax keyword mushFunction contained ucstr udefault ufun uldefault ulocal updiv
syntax keyword mushFunction contained utctime v vadd val valid vcross vdim vdot
syntax keyword mushFunction contained version visible vmag vmax vmin vmul vsub
syntax keyword mushFunction contained vtattr vtcount vtcreate vtdestroy vtlcon
syntax keyword mushFunction contained vtloc vtlocate vtmaster vtname vtref vttel
syntax keyword mushFunction contained vunit wait where width wipe wordpos words
syntax keyword mushFunction contained wrap xcon xexits xget xor xplayers xthings
syntax keyword mushFunction contained xvcon xvexits xvplayers xvthings zemit zfun
syntax keyword mushFunction contained zmwho zone zwho

" only highligh functions when they have an in-bracket immediately after
syntax match mushFunctionBrackets  "\i*(" contains=mushFunction
"
" regular mush commands
syntax keyword mushAtCommandList contained @ALLHALT @ALLQUOTA @ASSERT @ATRCHOWN @ATRLOCK @ATTRIBUTE @BOOT 
syntax keyword mushAtCommandList contained @BREAK @CEMIT @CHANNEL @CHAT @CHOWN @CHOWNALL @CHZONE @CHZONEALL 
syntax keyword mushAtCommandList contained @CLOCK @CLONE @COBJ @COMMAND @CONFIG @CPATTR @CREATE @CRPLOG @DBCK
syntax keyword mushAtCommandList contained @DECOMPILE @DESTROY @DIG @DISABLE @DIVISION @DOING @DOLIST @DRAIN 
syntax keyword mushAtCommandList contained @DUMP @EDIT @ELOCK @EMIT @EMPOWER @ENABLE @ENTRANCES @EUNLOCK @FIND 
syntax keyword mushAtCommandList contained @FIRSTEXIT @FLAG @FORCE @FUNCTION @EDIT @GREP @HALT @HIDE @HOOK @KICK 
syntax keyword mushAtCommandList contained @LEMIT @LEVEL @LINK @LIST @LISTMOTD @LOCK @LOG @LOGWIPE @LSET @MAIL @MALIAS 
syntax keyword mushAtCommandList contained @MAP @MOTD @MVATTR @NAME @NEWPASSWORD @NOTIFY @NSCEMIT @NSEMIT @NSLEMIT 
syntax keyword mushAtCommandList contained @NSOEMIT @NSPEMIT @NSPEMIT @NSREMIT @NSZEMIT @NUKE @OEMIT @OPEN @PARENT @PASSWORD
syntax keyword mushAtCommandList contained @PCREATE @PEMIT @POLL @POOR @POWERLEVEL @PROGRAM @PROMPT @PS @PURGE @QUOTA 
syntax keyword mushAtCommandList contained @READCACHE @RECYCLE @REJECTMOTD @REMIT @RESTART @SCAN @SEARCH @SELECT @SET 
syntax keyword mushAtCommandList contained @SHUTDOWN @SITELOCK @SNOOP @SQL @SQUOTA @STATS @SWITCH @SWEEP @SWITCH @TELEPORT 
syntax keyword mushAtCommandList contained @TRIGGER @ULOCK @UNDESTROY @UNLINK @UNLOCK @UNRECYCLE @UPTIME @UUNLOCK @VERB 
syntax keyword mushAtCommandList contained @VERSION @WAIT @WALL @WARNINGS @WCHECK @WHEREIS @WIPE @ZCLONE @ZEMIT
syntax match mushCommand  "@\i\I*" contains=mushAtCommandList


syntax keyword mushCommand AHELP ANEWS ATTRIB_SET BRIEF BRIEF BUY CHANGES DESERT
syntax keyword mushCommand DISMISS DROP EMPTY ENTER EXAMINE FOLLOW GET GIVE GOTO 
syntax keyword mushCommand HELP HUH_COMMAND INVENTORY INVENTORY LOOK LEAVE LOOK
syntax keyword mushCommand GOTO NEWS PAGE PAGE POSE RULES SAY SCORE SEMIPOSE 
syntax keyword mushCommand SPECIALNEWS TAKE TEACH THINK UNFOLLOW USE WHISPER WHISPER
syntax keyword mushCommand WARN_ON_MISSING WHISPER WITH

syntax match mushSpecial     "\*\|!\|=\|-\|\\\|+"
syntax match mushSpecial2 contained     "\*"

syn region    mushString         start=+L\="+ skip=+\\\\\|\\"+ end=+"+ contains=mushSpecial,mushSpecial2,@Spell


syntax match mushIdentifier   "&[^ ]\+"

syntax match mushVariable   "%r\|%t\|%cr\|%[A-Za-z0-9]\+\|%#\|##\|here"

" numbers
syntax match mushNumber	+[0-9]\++

" A comment line starts with a or # or " at the start of the line
" or an @@
syntax keyword mushTodo contained	TODO FIXME XXX
syntax cluster mushCommentGroup contains=mushTodo
syntax match	mushComment	"^\s*@@.*$"	contains=mushTodo
syntax match mushComment "^#[^define|^ifdef|^else|^pragma|^ifndef|^echo|^elif|^undef|^warning].*$" contains=mushTodo
syntax match mushComment "^#$" contains=mushTodo
syntax region mushComment        matchgroup=mushCommentStart start="/@@" end="@@/" contains=@mushCommentGroup,mushCommentStartError,mushCommentString,@Spell
syntax region mushCommentString  contained start=+L\=\\\@<!"+ skip=+\\\\\|\\"+ end=+"+ end=+@@/+me=s-1 contains=mushCommentSkip
syntax match  mushCommentSkip    contained "^\s*@@\($\|\s\+\)"


syntax match mushCommentStartError display "/@@"me=e-1 contained

" syntax match	mushComment	+^".*$+	contains=mushTodo
" Work on this one
" syntax match	mushComment	+^#.*$+	contains=mushTodo

syn region      mushPreCondit      start="^\s*\(%:\|#\)\s*\(if\|ifdef\|ifndef\|elif\)\>" skip="\\$" end="$" end="//"me=s-1 contains=mushComment
syn match       mushPreCondit      display "^\s*\(%:\|#\)\s*\(else\|endif\)\>"

syn cluster     mushPreProcGroup   contains=mushPreCondit,mushIncluded,mushInclude,mushDefine,mushSpecial,mushString,mushCommentSkip,mushCommentString,@mushCommentGroup,mushCommentStartError

syn region      mushIncluded       display contained start=+"+ skip=+\\\\\|\\"+ end=+"+
syn match       mushIncluded       display contained "<[^>]*>"
syn match       mushInclude        display "^\s*\(%:\|#\)\s*include\>\s*["<]" contains=mushIncluded
syn region	mushDefine		start="^\s*\(%:\|#\)\s*\(define\|undef\)\>" skip="\\$" end="$" end="//"me=s-1 contains=ALLBUT,@mushPreProcGroup,@Spell
syn region	mushPreProc	start="^\s*\(%:\|#\)\s*\(pragma\>\|line\>\|warning\>\|warn\>\|error\>\)" skip="\\$" end="$" keepend contains=ALLBUT,@mushPreProcGroup


syntax region	mushFuncBoundaries start="\[" end="\]" contains=mushFunction,mushFlag,mushAttributes,mushNumber,mushCommand,mushVariable,mushSpecial2

" FLAGS
syntax keyword mushFlag PLAYER ABODE BUILDER CHOWN_OK DARK FLOATING
syntax keyword mushFlag GOING HAVEN INHERIT JUMP_OK KEY LINK_OK MONITOR
syntax keyword mushFlag NOSPOOF OPAQUE QUIET STICKY TRACE UNFINDABLE VISUAL
syntax keyword mushFlag WIZARD PARENT_OK ZONE AUDIBLE CONNECTED DESTROY_OK
syntax keyword mushFlag ENTER_OK HALTED IMMORTAL LIGHT MYOPIC PUPPET TERSE
syntax keyword mushFlag ROBOT SAFE TRANSPARENT VERBOSE CONTROL_OK COMMANDS

syntax keyword mushAttribute aahear aclone aconnect adesc adfail adisconnect
syntax keyword mushAttribute adrop aefail aenter afail agfail ahear akill
syntax keyword mushAttribute aleave alfail alias amhear amove apay arfail
syntax keyword mushAttribute asucc atfail atport aufail ause away charges
syntax keyword mushAttribute cost desc dfail drop ealias efail enter fail
syntax keyword mushAttribute filter forwardlist gfail idesc idle infilter
syntax keyword mushAttribute inprefix kill lalias last lastsite leave lfail
syntax keyword mushAttribute listen move odesc odfail odrop oefail oenter
syntax keyword mushAttribute ofail ogfail okill oleave olfail omove opay
syntax keyword mushAttribute orfail osucc otfail otport oufail ouse oxenter
syntax keyword mushAttribute oxleave oxtport pay prefix reject rfail runout
syntax keyword mushAttribute semaphore sex startup succ tfail tport ufail
syntax keyword mushAttribute use va vb vc vd ve vf vg vh vi vj vk vl vm vn
syntax keyword mushAttribute vo vp vq vr vs vt vu vv vw vx vy vz



" The default methods for highlighting.  Can be overridden later
hi def link mushAttribute  Constant
hi def link mushCommand    Function
hi def link mushNumber     Number
hi def link mushSetting    PreProc
hi def link mushFunction   Statement
hi def link mushVariable   Identifier
hi def link mushSpecial    Special
hi def link mushTodo       Todo
hi def link mushFlag       Special
hi def link mushIdentifier Identifier
hi def link mushDefine     Macro
hi def link mushPreProc    PreProc
hi def link mushPreProcGroup PreProc 
hi def link mushPreCondit PreCondit
hi def link mushIncluded cString
hi def link mushInclude Include



" Comments
hi def link mushCommentStart mushComment
hi def link mushComment    Comment
hi def link mushCommentString mushString



let b:current_syntax = "mush"

" mush: ts=17
