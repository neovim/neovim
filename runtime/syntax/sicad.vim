" Vim syntax file
" Language:     SiCAD (procedure language)
" Maintainer:   Zsolt Branyiczky <zbranyiczky@lmark.mgx.hu>
" Last Change:  2003 May 11
" URL:		http://lmark.mgx.hu:81/download/vim/sicad.vim

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" use SQL highlighting after 'sql' command
syn include @SQL syntax/sql.vim
unlet b:current_syntax

" spaces are used in (auto)indents since sicad hates tabulator characters
setlocal expandtab

" ignore case
syn case ignore

" most important commands - not listed by ausku
syn keyword sicadStatement define
syn keyword sicadStatement dialog
syn keyword sicadStatement do
syn keyword sicadStatement dop contained
syn keyword sicadStatement end
syn keyword sicadStatement enddo
syn keyword sicadStatement endp
syn keyword sicadStatement erroff
syn keyword sicadStatement erron
syn keyword sicadStatement exitp
syn keyword sicadGoto      goto contained
syn keyword sicadStatement hh
syn keyword sicadStatement if
syn keyword sicadStatement in
syn keyword sicadStatement msgsup
syn keyword sicadStatement out
syn keyword sicadStatement padd
syn keyword sicadStatement parbeg
syn keyword sicadStatement parend
syn keyword sicadStatement pdoc
syn keyword sicadStatement pprot
syn keyword sicadStatement procd
syn keyword sicadStatement procn
syn keyword sicadStatement psav
syn keyword sicadStatement psel
syn keyword sicadStatement psymb
syn keyword sicadStatement ptrace
syn keyword sicadStatement ptstat
syn keyword sicadStatement set
syn keyword sicadStatement sql contained
syn keyword sicadStatement step
syn keyword sicadStatement sys
syn keyword sicadStatement ww

" functions
syn match sicadStatement "\<atan("me=e-1
syn match sicadStatement "\<atan2("me=e-1
syn match sicadStatement "\<cos("me=e-1
syn match sicadStatement "\<dist("me=e-1
syn match sicadStatement "\<exp("me=e-1
syn match sicadStatement "\<log("me=e-1
syn match sicadStatement "\<log10("me=e-1
syn match sicadStatement "\<sin("me=e-1
syn match sicadStatement "\<sqrt("me=e-1
syn match sicadStatement "\<tanh("me=e-1
syn match sicadStatement "\<x("me=e-1
syn match sicadStatement "\<y("me=e-1
syn match sicadStatement "\<v("me=e-1
syn match sicadStatement "\<x%g\=p[0-9]\{1,2}\>"me=s+1
syn match sicadStatement "\<y%g\=p[0-9]\{1,2}\>"me=s+1

" logical operators
syn match sicadOperator "\.and\."
syn match sicadOperator "\.ne\."
syn match sicadOperator "\.not\."
syn match sicadOperator "\.eq\."
syn match sicadOperator "\.ge\."
syn match sicadOperator "\.gt\."
syn match sicadOperator "\.le\."
syn match sicadOperator "\.lt\."
syn match sicadOperator "\.or\."
syn match sicadOperator "\.eqv\."
syn match sicadOperator "\.neqv\."

" variable name
syn match sicadIdentifier "%g\=[irpt][0-9]\{1,2}\>"
syn match sicadIdentifier "%g\=l[0-9]\>"
syn match sicadIdentifier "%g\=[irptl]("me=e-1
syn match sicadIdentifier "%error\>"
syn match sicadIdentifier "%nsel\>"
syn match sicadIdentifier "%nvar\>"
syn match sicadIdentifier "%scl\>"
syn match sicadIdentifier "%wd\>"
syn match sicadIdentifier "\$[irt][0-9]\{1,2}\>" contained

" label
syn match sicadLabel1 "^ *\.[a-z][a-z0-9]\{0,7} \+[^ ]"me=e-1
syn match sicadLabel1 "^ *\.[a-z][a-z0-9]\{0,7}\*"me=e-1
syn match sicadLabel2 "\<goto \.\=[a-z][a-z0-9]\{0,7}\>" contains=sicadGoto
syn match sicadLabel2 "\<goto\.[a-z][a-z0-9]\{0,7}\>" contains=sicadGoto

" boolean
syn match sicadBoolean "\.[ft]\."
" integer without sign
syn match sicadNumber "\<[0-9]\+\>"
" floating point number, with dot, optional exponent
syn match sicadFloat "\<[0-9]\+\.[0-9]*\(e[-+]\=[0-9]\+\)\=\>"
" floating point number, starting with a dot, optional exponent
syn match sicadFloat "\.[0-9]\+\(e[-+]\=[0-9]\+\)\=\>"
" floating point number, without dot, with exponent
syn match sicadFloat "\<[0-9]\+e[-+]\=[0-9]\+\>"

" without this extraString definition a ' ;  ' could stop the comment
syn region sicadString_ transparent start=+'+ end=+'+ oneline contained
" string
syn region sicadString start=+'+ end=+'+ oneline

" comments - nasty ones in sicad

" - ' *  blabla' or ' *  blabla;'
syn region sicadComment start="^ *\*" skip='\\ *$' end=";"me=e-1 end="$" contains=sicadString_
" - ' .LABEL03 *  blabla' or ' .LABEL03 *  blabla;'
syn region sicadComment start="^ *\.[a-z][a-z0-9]\{0,7} *\*" skip='\\ *$' end=";"me=e-1 end="$" contains=sicadLabel1,sicadString_
" - '; * blabla' or '; * blabla;'
syn region sicadComment start="; *\*"ms=s+1 skip='\\ *$' end=";"me=e-1 end="$" contains=sicadString_
" - comments between docbeg and docend
syn region sicadComment matchgroup=sicadStatement start="\<docbeg\>" end="\<docend\>"

" catch \ at the end of line
syn match sicadLineCont "\\ *$"

" parameters in dop block - for the time being it is not used
"syn match sicadParameter " [a-z][a-z0-9]*[=:]"me=e-1 contained
" dop block - for the time being it is not used
syn region sicadDopBlock transparent matchgroup=sicadStatement start='\<dop\>' skip='\\ *$' end=';'me=e-1 end='$' contains=ALL

" sql block - new highlighting mode is used (see syn include)
syn region sicadSqlBlock transparent matchgroup=sicadStatement start='\<sql\>' skip='\\ *$' end=';'me=e-1 end='$' contains=@SQL,sicadIdentifier,sicadLineCont

" synchronizing
syn sync clear  " clear sync used in sql.vim
syn sync match sicadSyncComment groupthere NONE "\<docend\>"
syn sync match sicadSyncComment grouphere sicadComment "\<docbeg\>"
" next line must be examined too
syn sync linecont "\\ *$"

" catch error caused by tabulator key
syn match sicadError "\t"
" catch errors caused by wrong parenthesis
"syn region sicadParen transparent start='(' end=')' contains=ALLBUT,sicadParenError
syn region sicadParen transparent start='(' skip='\\ *$' end=')' end='$' contains=ALLBUT,sicadParenError
syn match sicadParenError ')'
"syn region sicadApostrophe transparent start=+'+ end=+'+ contains=ALLBUT,sicadApostropheError
"syn match sicadApostropheError +'+
" not closed apostrophe
"syn region sicadError start=+'+ end=+$+ contains=ALLBUT,sicadApostropheError
"syn match sicadApostropheError +'[^']*$+me=s+1 contained

" SICAD keywords
syn keyword sicadStatement abst add addsim adrin aib
syn keyword sicadStatement aibzsn aidump aifgeo aisbrk alknam
syn keyword sicadStatement alknr alksav alksel alktrc alopen
syn keyword sicadStatement ansbo aractiv ararea arareao ararsfs
syn keyword sicadStatement arbuffer archeck arcomv arcont arconv
syn keyword sicadStatement arcopy arcopyo arcorr arcreate arerror
syn keyword sicadStatement areval arflfm arflop arfrast argbkey
syn keyword sicadStatement argenf argraph argrapho arinters arkompfl
syn keyword sicadStatement arlasso arlcopy arlgraph arline arlining
syn keyword sicadStatement arlisly armakea armemo arnext aroverl
syn keyword sicadStatement arovers arparkmd arpars arrefp arselect
syn keyword sicadStatement arset arstruct arunify arupdate arvector
syn keyword sicadStatement arveinfl arvflfl arvoroni ausku basis
syn keyword sicadStatement basisaus basisdar basisnr bebos befl
syn keyword sicadStatement befla befli befls beo beorta
syn keyword sicadStatement beortn bep bepan bepap bepola
syn keyword sicadStatement bepoln bepsn bepsp ber berili
syn keyword sicadStatement berk bewz bkl bli bma
syn keyword sicadStatement bmakt bmakts bmbm bmerk bmerw
syn keyword sicadStatement bmerws bminit bmk bmorth bmos
syn keyword sicadStatement bmoss bmpar bmsl bmsum bmsums
syn keyword sicadStatement bmver bmvero bmw bo bta
syn keyword sicadStatement buffer bvl bw bza bzap
syn keyword sicadStatement bzd bzgera bzorth cat catel
syn keyword sicadStatement cdbdiff ce cgmparam close closesim
syn keyword sicadStatement comgener comp comp conclose conclose coninfo
syn keyword sicadStatement conopen conread contour conwrite cop
syn keyword sicadStatement copar coparp coparp2 copel cr
syn keyword sicadStatement cs cstat cursor d da
syn keyword sicadStatement dal dasp dasps dataout dcol
syn keyword sicadStatement dd defsr del delel deskrdef
syn keyword sicadStatement df dfn dfns dfpos dfr
syn keyword sicadStatement dgd dgm dgp dgr dh
syn keyword sicadStatement diag diaus dir disbsd dkl
syn keyword sicadStatement dktx dkur dlgfix dlgfre dma
syn keyword sicadStatement dprio dr druse dsel dskinfo
syn keyword sicadStatement dsr dv dve eba ebd
syn keyword sicadStatement ebdmod ebs edbsdbin edbssnin edbsvtin
syn keyword sicadStatement edt egaus egdef egdefs eglist
syn keyword sicadStatement egloe egloenp egloes egxx eib
syn keyword sicadStatement ekur ekuradd elel elpos epg
syn keyword sicadStatement esau esauadd esek eta etap
syn keyword sicadStatement etav feparam ficonv filse fl
syn keyword sicadStatement fli flin flini flinit flins
syn keyword sicadStatement flkor fln flnli flop flout
syn keyword sicadStatement flowert flparam flraster flsy flsyd
syn keyword sicadStatement flsym flsyms flsymt fmtatt fmtdia
syn keyword sicadStatement fmtlib fpg gbadddb gbaim gbanrs
syn keyword sicadStatement gbatw gbau gbaudit gbclosp gbcredic
syn keyword sicadStatement gbcreem gbcreld gbcresdb gbcretd gbde
syn keyword sicadStatement gbdeldb gbdeldic gbdelem gbdelld gbdelref
syn keyword sicadStatement gbdeltd gbdisdb gbdisem gbdisld gbdistd
syn keyword sicadStatement gbebn gbemau gbepsv gbgetdet gbgetes
syn keyword sicadStatement gbgetmas gbgqel gbgqelr gbgqsa gbgrant
syn keyword sicadStatement gbimpdic gbler gblerb gblerf gbles
syn keyword sicadStatement gblocdic gbmgmg gbmntdb gbmoddb gbnam
syn keyword sicadStatement gbneu gbopenp gbpoly gbpos gbpruef
syn keyword sicadStatement gbpruefg gbps gbqgel gbqgsa gbrefdic
syn keyword sicadStatement gbreftab gbreldic gbresem gbrevoke gbsav
syn keyword sicadStatement gbsbef gbsddk gbsicu gbsrt gbss
syn keyword sicadStatement gbstat gbsysp gbszau gbubp gbueb
syn keyword sicadStatement gbunmdb gbuseem gbw gbweg gbwieh
syn keyword sicadStatement gbzt gelp gera getvar hgw
syn keyword sicadStatement hpg hr0 hra hrar icclchan
syn keyword sicadStatement iccrecon icdescon icfree icgetcon icgtresp
syn keyword sicadStatement icopchan icputcon icreacon icreqd icreqnw
syn keyword sicadStatement icreqw icrespd icresrve icwricon imsget
syn keyword sicadStatement imsgqel imsmget imsplot imsprint inchk
syn keyword sicadStatement inf infd inst kbml kbmls
syn keyword sicadStatement kbmm kbmms kbmt kbmtdps kbmts
syn keyword sicadStatement khboe khbol khdob khe khetap
syn keyword sicadStatement khfrw khktk khlang khld khmfrp
syn keyword sicadStatement khmks khms khpd khpfeil khpl
syn keyword sicadStatement khprofil khrand khsa khsabs khsaph
syn keyword sicadStatement khsd khsdl khse khskbz khsna
syn keyword sicadStatement khsnum khsob khspos khsvph khtrn
syn keyword sicadStatement khver khzpe khzpl kib kldat
syn keyword sicadStatement klleg klsch klsym klvert kmpg
syn keyword sicadStatement kmtlage kmtp kmtps kodef kodefp
syn keyword sicadStatement kodefs kok kokp kolae kom
syn keyword sicadStatement kontly kopar koparp kopg kosy
syn keyword sicadStatement kp kr krsek krtclose krtopen
syn keyword sicadStatement ktk lad lae laesel language
syn keyword sicadStatement lasso lbdes lcs ldesk ldesks
syn keyword sicadStatement le leak leattdes leba lebas
syn keyword sicadStatement lebaznp lebd lebm lebv lebvaus
syn keyword sicadStatement lebvlist lede ledel ledepo ledepol
syn keyword sicadStatement ledepos leder ledist ledm lee
syn keyword sicadStatement leeins lees lege lekr lekrend
syn keyword sicadStatement lekwa lekwas lel lelh lell
syn keyword sicadStatement lelp lem lena lend lenm
syn keyword sicadStatement lep lepe lepee lepko lepl
syn keyword sicadStatement lepmko lepmkop lepos leposm leqs
syn keyword sicadStatement leqsl leqssp leqsv leqsvov les
syn keyword sicadStatement lesch lesr less lestd let
syn keyword sicadStatement letaum letl lev levm levtm
syn keyword sicadStatement levtp levtr lew lewm lexx
syn keyword sicadStatement lfs li lining lldes lmode
syn keyword sicadStatement loedk loepkt lop lose loses
syn keyword sicadStatement lp lppg lppruef lr ls
syn keyword sicadStatement lsop lsta lstat ly lyaus
syn keyword sicadStatement lz lza lzae lzbz lze
syn keyword sicadStatement lznr lzo lzpos ma ma0
syn keyword sicadStatement ma1 mad map mapoly mcarp
syn keyword sicadStatement mccfr mccgr mcclr mccrf mcdf
syn keyword sicadStatement mcdma mcdr mcdrp mcdve mcebd
syn keyword sicadStatement mcgse mcinfo mcldrp md me
syn keyword sicadStatement mefd mefds minmax mipg ml
syn keyword sicadStatement mmcmdme mmdbf mmdellb mmdir mmdome
syn keyword sicadStatement mmfsb mminfolb mmlapp mmlbf mmlistlb
syn keyword sicadStatement mmloadcm mmmsg mmreadlb mmsetlb mmshowcm
syn keyword sicadStatement mmstatme mnp mpo mr mra
syn keyword sicadStatement ms msav msgout msgsnd msp
syn keyword sicadStatement mspf mtd nasel ncomp new
syn keyword sicadStatement nlist nlistlt nlistly nlistnp nlistpo
syn keyword sicadStatement np npa npdes npe npem
syn keyword sicadStatement npinfa npruef npsat npss npssa
syn keyword sicadStatement ntz oa oan odel odf
syn keyword sicadStatement odfx oj oja ojaddsk ojaed
syn keyword sicadStatement ojaeds ojaef ojaefs ojaen ojak
syn keyword sicadStatement ojaks ojakt ojakz ojalm ojatkis
syn keyword sicadStatement ojatt ojatw ojbsel ojcasel ojckon
syn keyword sicadStatement ojde ojdtl ojeb ojebd ojel
syn keyword sicadStatement ojelpas ojesb ojesbd ojex ojezge
syn keyword sicadStatement ojko ojlb ojloe ojlsb ojmerk
syn keyword sicadStatement ojmos ojnam ojpda ojpoly ojprae
syn keyword sicadStatement ojs ojsak ojsort ojstrukt ojsub
syn keyword sicadStatement ojtdef ojvek ojx old oldd
syn keyword sicadStatement op opa opa1 open opensim
syn keyword sicadStatement opnbsd orth osanz ot otp
syn keyword sicadStatement otrefp param paranf pas passw
syn keyword sicadStatement pcatchf pda pdadd pg pg0
syn keyword sicadStatement pgauf pgaufsel pgb pgko pgm
syn keyword sicadStatement pgr pgvs pily pkpg plot
syn keyword sicadStatement plotf plotfr pmap pmdata pmdi
syn keyword sicadStatement pmdp pmeb pmep pminfo pmlb
syn keyword sicadStatement pmli pmlp pmmod pnrver poa
syn keyword sicadStatement pos posa posaus post printfr
syn keyword sicadStatement protect prs prssy prsym ps
syn keyword sicadStatement psadd psclose psopen psparam psprw
syn keyword sicadStatement psres psstat psw pswr qualif
syn keyword sicadStatement rahmen raster rasterd rbbackup rbchang2
syn keyword sicadStatement rbchange rbcmd rbcoldst rbcolor rbcopy
syn keyword sicadStatement rbcut rbcut2 rbdbcl rbdbload rbdbop
syn keyword sicadStatement rbdbwin rbdefs rbedit rbfdel rbfill
syn keyword sicadStatement rbfill2 rbfload rbfload2 rbfnew rbfnew2
syn keyword sicadStatement rbfpar rbfree rbg rbgetcol rbgetdst
syn keyword sicadStatement rbinfo rbpaste rbpixel rbrstore rbsnap
syn keyword sicadStatement rbsta rbtile rbtrpix rbvtor rcol
syn keyword sicadStatement rd rdchange re reb rebmod
syn keyword sicadStatement refunc ren renel rk rkpos
syn keyword sicadStatement rohr rohrpos rpr rr rr0
syn keyword sicadStatement rra rrar rs samtosdb sav
syn keyword sicadStatement savd savesim savx scol scopy
syn keyword sicadStatement scopye sdbtosam sddk sdwr se
syn keyword sicadStatement selaus selpos seman semi sesch
syn keyword sicadStatement setscl setvar sfclntpf sfconn sffetchf
syn keyword sicadStatement sffpropi sfftypi sfqugeoc sfquwhcl sfself
syn keyword sicadStatement sfstat sftest sge sid sie
syn keyword sicadStatement sig sigp skk skks sn
syn keyword sicadStatement sn21 snpa snpar snparp snparps
syn keyword sicadStatement snpars snpas snpd snpi snpkor
syn keyword sicadStatement snpl snpm sob sob0 sobloe
syn keyword sicadStatement sobs sof sop split spr
syn keyword sicadStatement sqdadd sqdlad sqdold sqdsav
syn keyword sicadStatement sr sres srt sset stat
syn keyword sicadStatement stdtxt string strukt strupru suinfl
syn keyword sicadStatement suinflk suinfls supo supo1 sva
syn keyword sicadStatement svr sy sya syly sysout
syn keyword sicadStatement syu syux taa tabeg tabl
syn keyword sicadStatement tabm tam tanr tapg tapos
syn keyword sicadStatement tarkd tas tase tb tbadd
syn keyword sicadStatement tbd tbext tbget tbint tbout
syn keyword sicadStatement tbput tbsat tbsel tbstr tcaux
syn keyword sicadStatement tccable tcchkrep tccomm tccond tcdbg
syn keyword sicadStatement tcgbnr tcgrpos tcinit tclconv tcmodel
syn keyword sicadStatement tcnwe tcpairs tcpath tcrect tcrmdli
syn keyword sicadStatement tcscheme tcschmap tcse tcselc tcstar
syn keyword sicadStatement tcstrman tcsubnet tcsymbol tctable tcthrcab
syn keyword sicadStatement tctrans tctst tdb tdbdel tdbget
syn keyword sicadStatement tdblist tdbput tgmod titel tmoff
syn keyword sicadStatement tmon tp tpa tps tpta
syn keyword sicadStatement tra trans transkdo transopt transpro
syn keyword sicadStatement triangle trm trpg trrkd trs
syn keyword sicadStatement ts tsa tx txa txchk
syn keyword sicadStatement txcng txju txl txp txpv
syn keyword sicadStatement txtcmp txv txz uckon uiinfo
syn keyword sicadStatement uistatus umdk umdk1 umdka umge
syn keyword sicadStatement umges umr verbo verflli verif
syn keyword sicadStatement verly versinfo vfg vpactive vpcenter
syn keyword sicadStatement vpcreate vpdelete vpinfo vpmodify vpscroll
syn keyword sicadStatement vpsta wabsym wzmerk zdrhf zdrhfn
syn keyword sicadStatement zdrhfw zdrhfwn zefp zfl zflaus
syn keyword sicadStatement zka zlel zlels zortf zortfn
syn keyword sicadStatement zortfw zortfwn zortp zortpn zparb
syn keyword sicadStatement zparbn zparf zparfn zparfw zparfwn
syn keyword sicadStatement zparp zparpn zwinkp zwinkpn

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link sicadLabel PreProc
hi def link sicadLabel1 sicadLabel
hi def link sicadLabel2 sicadLabel
hi def link sicadConditional Conditional
hi def link sicadBoolean Boolean
hi def link sicadNumber Number
hi def link sicadFloat Float
hi def link sicadOperator Operator
hi def link sicadStatement Statement
hi def link sicadParameter sicadStatement
hi def link sicadGoto sicadStatement
hi def link sicadLineCont sicadStatement
hi def link sicadString String
hi def link sicadComment Comment
hi def link sicadSpecial Special
hi def link sicadIdentifier Type
"  hi def link sicadIdentifier Identifier
hi def link sicadError Error
hi def link sicadParenError sicadError
hi def link sicadApostropheError sicadError
hi def link sicadStringError sicadError
hi def link sicadCommentError sicadError
"  hi def link sqlStatement Special  " modified highlight group in sql.vim


let b:current_syntax = "sicad"

" vim: ts=8 sw=2
