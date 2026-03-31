" Vim syntax file
" Language:             terminfo(5) definition
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn match terminfoKeywords      '[,=#|]'

syn keyword terminfoTodo        contained TODO FIXME XXX NOTE

syn region  terminfoComment     display oneline start='^#' end='$'
                                \ contains=terminfoTodo,@Spell

syn match   terminfoNumbers     '\<[0-9]\+\>'

syn match   terminfoSpecialChar '\\\(\o\{3}\|[Eenlrtbfs^\,:0]\)'
syn match   terminfoSpecialChar '\^\a'

syn match   terminfoDelay       '$<[0-9]\+>'

syn keyword terminfoBooleans    bw am bce ccc xhp xhpa cpix crxw xt xenl eo gn
                                \ hc chts km daisy hs hls in lpix da db mir
                                \ msgr nxon xsb npc ndscr nrrmc os mc5i xcpa
                                \ sam eslok hz ul xon

syn keyword terminfoNumerics    cols it lh lw lines lm xmc ma colors pairs wnum
                                \ ncv nlab pb vt wsl bitwin bitype bufsz btns
                                \ spinh spinv maddr mjump mcs npins orc orhi
                                \ orl orvi cps widcs

syn keyword terminfoStrings     acsc cbt bel cr cpi lpi chr cvr csr rmp tbc mgc
                                \ clear el1 el ed hpa cmdch cwin cup cud1 home
                                \ civis cub1 mrcup cnorm cuf1 ll cuu1 cvvis
                                \ defc dch1 dl1 dial dsl dclk hd enacs smacs
                                \ smam blink bold smcup smdc dim swidm sdrfq
                                \ smir sitm slm smicm snlq snrmq prot rev
                                \ invis sshm smso ssubm ssupm smul sum smxon
                                \ ech rmacs rmam sgr0 rmcup rmdc rwidm rmir
                                \ ritm rlm rmicm rshm rmso rsubm rsupm rmul
                                \ rum rmxon pause hook flash ff fsl wingo hup
                                \ is1 is2 is3 if iprog initc initp ich1 il1 ip
                                \ ka1 ka3 kb2 kbs kbeg kcbt kc1 kc3 kcan ktbc
                                \ kclr kclo kcmd kcpy kcrt kctab kdch1 kdl1
                                \ kcud1 krmir kend kent kel ked kext kfnd khlp
                                \ khome kich1 kil1 kcub1 kll kmrk kmsg kmov
                                \ knxt knp kopn kopt kpp kprv kprt krdo kref
                                \ krfr krpl krst kres kcuf1 ksav kBEG kCAN
                                \ kCMD kCPY kCRT kDC kDL kslt kEND kEOL kEXT
                                \ kind kFND kHLP kHOM kIC kLFT kMSG kMOV kNXT
                                \ kOPT kPRV kPRT kri kRDO kRPL kRIT kRES kSAV
                                \ kSPD khts kUND kspd kund kcuu1 rmkx smkx
                                \ lf0 lf1 lf10 lf2 lf3 lf4 lf5 lf6 lf7 lf8 lf9
                                \ fln rmln smln rmm smm mhpa mcud1 mcub1 mcuf1
                                \ mvpa mcuu1 nel porder oc op pad dch dl cud
                                \ mcud ich indn il cub mcub cuf mcuf rin cuu
                                \ mccu pfkey pfloc pfx pln mc0 mc5p mc4 mc5
                                \ pulse qdial rmclk rep rfi rs1 rs2 rs3 rf rc
                                \ vpa sc ind ri scs sgr setbsmgb smgbp sclk
                                \ scp setb setf smgl smglp smgr smgrp hts smgt
                                \ smgtp wind sbim scsd rbim rcsd subcs supcs
                                \ ht docr tsl tone uc hu u0 u1 u2 u3 u4 u5 u6
                                \ u7 u8 u9 wait xoffc xonc zerom scesa bicr
                                \ binel birep csnm csin colornm defbi devt
                                \ dispc endbi smpch smsc rmpch rmsc getm kmous
                                \ minfo pctrm pfxl reqmp scesc s0ds s1ds s2ds
                                \ s3ds setab setaf setcolor smglr slines smgtb
                                \ ehhlm elhlm erhlm ethlm evhlm sgr1 slengthsL
syn match terminfoStrings       display '\<kf\([0-9]\|[0-5][0-9]\|6[0-3]\)\>'

syn match terminfoParameters    '%[%dcspl+*/mAO&|^=<>!~i?te;-]'
syn match terminfoParameters    "%\('[A-Z]'\|{[0-9]\{1,2}}\|p[1-9]\|P[a-z]\|g[A-Z]\)"

hi def link terminfoComment     Comment
hi def link terminfoTodo        Todo
hi def link terminfoNumbers     Number
hi def link terminfoSpecialChar SpecialChar
hi def link terminfoDelay       Special
hi def link terminfoBooleans    Type
hi def link terminfoNumerics    Type
hi def link terminfoStrings     Type
hi def link terminfoParameters  Keyword
hi def link terminfoKeywords    Keyword

let b:current_syntax = "terminfo"

let &cpo = s:cpo_save
unlet s:cpo_save
