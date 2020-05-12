" Vim syntax file
" Language:		SKILL
" Maintainer:	Toby Schaffer <jtschaff@eos.ncsu.edu>
" Last Change:	2003 May 11
" Comments:		SKILL is a Lisp-like programming language for use in EDA
"				tools from Cadence Design Systems. It allows you to have
"				a programming environment within the Cadence environment
"				that gives you access to the complete tool set and design
"				database. This file also defines syntax highlighting for
"				certain Design Framework II interface functions.

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn keyword skillConstants			t nil unbound

" enumerate all the SKILL reserved words/functions
syn match skillFunction     "(abs\>"hs=s+1
syn match skillFunction     "\<abs("he=e-1
syn match skillFunction     "(a\=cos\>"hs=s+1
syn match skillFunction     "\<a\=cos("he=e-1
syn match skillFunction     "(add1\>"hs=s+1
syn match skillFunction     "\<add1("he=e-1
syn match skillFunction     "(addDefstructClass\>"hs=s+1
syn match skillFunction     "\<addDefstructClass("he=e-1
syn match skillFunction     "(alias\>"hs=s+1
syn match skillFunction     "\<alias("he=e-1
syn match skillFunction     "(alphalessp\>"hs=s+1
syn match skillFunction     "\<alphalessp("he=e-1
syn match skillFunction     "(alphaNumCmp\>"hs=s+1
syn match skillFunction     "\<alphaNumCmp("he=e-1
syn match skillFunction     "(append1\=\>"hs=s+1
syn match skillFunction     "\<append1\=("he=e-1
syn match skillFunction     "(apply\>"hs=s+1
syn match skillFunction     "\<apply("he=e-1
syn match skillFunction     "(arrayp\>"hs=s+1
syn match skillFunction     "\<arrayp("he=e-1
syn match skillFunction     "(arrayref\>"hs=s+1
syn match skillFunction     "\<arrayref("he=e-1
syn match skillFunction     "(a\=sin\>"hs=s+1
syn match skillFunction     "\<a\=sin("he=e-1
syn match skillFunction     "(assoc\>"hs=s+1
syn match skillFunction     "\<assoc("he=e-1
syn match skillFunction     "(ass[qv]\>"hs=s+1
syn match skillFunction     "\<ass[qv]("he=e-1
syn match skillFunction     "(a\=tan\>"hs=s+1
syn match skillFunction     "\<a\=tan("he=e-1
syn match skillFunction     "(ato[fim]\>"hs=s+1
syn match skillFunction     "\<ato[fim]("he=e-1
syn match skillFunction     "(bcdp\>"hs=s+1
syn match skillFunction     "\<bcdp("he=e-1
syn match skillKeywords     "(begin\>"hs=s+1
syn match skillKeywords     "\<begin("he=e-1
syn match skillFunction     "(booleanp\>"hs=s+1
syn match skillFunction     "\<booleanp("he=e-1
syn match skillFunction     "(boundp\>"hs=s+1
syn match skillFunction     "\<boundp("he=e-1
syn match skillFunction     "(buildString\>"hs=s+1
syn match skillFunction     "\<buildString("he=e-1
syn match skillFunction     "(c[ad]{1,3}r\>"hs=s+1
syn match skillFunction     "\<c[ad]{1,3}r("he=e-1
syn match skillConditional  "(caseq\=\>"hs=s+1
syn match skillConditional  "\<caseq\=("he=e-1
syn match skillFunction     "(ceiling\>"hs=s+1
syn match skillFunction     "\<ceiling("he=e-1
syn match skillFunction     "(changeWorkingDir\>"hs=s+1
syn match skillFunction     "\<changeWorkingDir("he=e-1
syn match skillFunction     "(charToInt\>"hs=s+1
syn match skillFunction     "\<charToInt("he=e-1
syn match skillFunction     "(clearExitProcs\>"hs=s+1
syn match skillFunction     "\<clearExitProcs("he=e-1
syn match skillFunction     "(close\>"hs=s+1
syn match skillFunction     "\<close("he=e-1
syn match skillFunction     "(compareTime\>"hs=s+1
syn match skillFunction     "\<compareTime("he=e-1
syn match skillFunction     "(compress\>"hs=s+1
syn match skillFunction     "\<compress("he=e-1
syn match skillFunction     "(concat\>"hs=s+1
syn match skillFunction     "\<concat("he=e-1
syn match skillConditional  "(cond\>"hs=s+1
syn match skillConditional  "\<cond("he=e-1
syn match skillFunction     "(cons\>"hs=s+1
syn match skillFunction     "\<cons("he=e-1
syn match skillFunction     "(copy\>"hs=s+1
syn match skillFunction     "\<copy("he=e-1
syn match skillFunction     "(copyDefstructDeep\>"hs=s+1
syn match skillFunction     "\<copyDefstructDeep("he=e-1
syn match skillFunction     "(createDir\>"hs=s+1
syn match skillFunction     "\<createDir("he=e-1
syn match skillFunction     "(csh\>"hs=s+1
syn match skillFunction     "\<csh("he=e-1
syn match skillKeywords     "(declare\>"hs=s+1
syn match skillKeywords     "\<declare("he=e-1
syn match skillKeywords     "(declare\(N\|SQN\)\=Lambda\>"hs=s+1
syn match skillKeywords     "\<declare\(N\|SQN\)\=Lambda("he=e-1
syn match skillKeywords     "(defmacro\>"hs=s+1
syn match skillKeywords     "\<defmacro("he=e-1
syn match skillKeywords     "(defprop\>"hs=s+1
syn match skillKeywords     "\<defprop("he=e-1
syn match skillKeywords     "(defstruct\>"hs=s+1
syn match skillKeywords     "\<defstruct("he=e-1
syn match skillFunction     "(defstructp\>"hs=s+1
syn match skillFunction     "\<defstructp("he=e-1
syn match skillKeywords     "(defun\>"hs=s+1
syn match skillKeywords     "\<defun("he=e-1
syn match skillKeywords     "(defUserInitProc\>"hs=s+1
syn match skillKeywords     "\<defUserInitProc("he=e-1
syn match skillKeywords     "(defvar\>"hs=s+1
syn match skillKeywords     "\<defvar("he=e-1
syn match skillFunction     "(delete\(Dir\|File\)\>"hs=s+1
syn match skillKeywords     "\<delete\(Dir\|File\)("he=e-1
syn match skillFunction     "(display\>"hs=s+1
syn match skillFunction     "\<display("he=e-1
syn match skillFunction     "(drain\>"hs=s+1
syn match skillFunction     "\<drain("he=e-1
syn match skillFunction     "(dtpr\>"hs=s+1
syn match skillFunction     "\<dtpr("he=e-1
syn match skillFunction     "(ed\(i\|l\|it\)\=\>"hs=s+1
syn match skillFunction     "\<ed\(i\|l\|it\)\=("he=e-1
syn match skillFunction     "(envobj\>"hs=s+1
syn match skillFunction     "\<envobj("he=e-1
syn match skillFunction     "(equal\>"hs=s+1
syn match skillFunction     "\<equal("he=e-1
syn match skillFunction     "(eqv\=\>"hs=s+1
syn match skillFunction     "\<eqv\=("he=e-1
syn match skillFunction     "(err\>"hs=s+1
syn match skillFunction     "\<err("he=e-1
syn match skillFunction     "(error\>"hs=s+1
syn match skillFunction     "\<error("he=e-1
syn match skillFunction     "(errset\>"hs=s+1
syn match skillFunction     "\<errset("he=e-1
syn match skillFunction     "(errsetstring\>"hs=s+1
syn match skillFunction     "\<errsetstring("he=e-1
syn match skillFunction     "(eval\>"hs=s+1
syn match skillFunction     "\<eval("he=e-1
syn match skillFunction     "(evalstring\>"hs=s+1
syn match skillFunction     "\<evalstring("he=e-1
syn match skillFunction     "(evenp\>"hs=s+1
syn match skillFunction     "\<evenp("he=e-1
syn match skillFunction     "(exists\>"hs=s+1
syn match skillFunction     "\<exists("he=e-1
syn match skillFunction     "(exit\>"hs=s+1
syn match skillFunction     "\<exit("he=e-1
syn match skillFunction     "(exp\>"hs=s+1
syn match skillFunction     "\<exp("he=e-1
syn match skillFunction     "(expandMacro\>"hs=s+1
syn match skillFunction     "\<expandMacro("he=e-1
syn match skillFunction     "(file\(Length\|Seek\|Tell\|TimeModified\)\>"hs=s+1
syn match skillFunction     "\<file\(Length\|Seek\|Tell\|TimeModified\)("he=e-1
syn match skillFunction     "(fixp\=\>"hs=s+1
syn match skillFunction     "\<fixp\=("he=e-1
syn match skillFunction     "(floatp\=\>"hs=s+1
syn match skillFunction     "\<floatp\=("he=e-1
syn match skillFunction     "(floor\>"hs=s+1
syn match skillFunction     "\<floor("he=e-1
syn match skillRepeat       "(for\(all\|each\)\=\>"hs=s+1
syn match skillRepeat       "\<for\(all\|each\)\=("he=e-1
syn match skillFunction     "([fs]\=printf\>"hs=s+1
syn match skillFunction     "\<[fs]\=printf("he=e-1
syn match skillFunction     "(f\=scanf\>"hs=s+1
syn match skillFunction     "\<f\=scanf("he=e-1
syn match skillFunction     "(funobj\>"hs=s+1
syn match skillFunction     "\<funobj("he=e-1
syn match skillFunction     "(gc\>"hs=s+1
syn match skillFunction     "\<gc("he=e-1
syn match skillFunction     "(gensym\>"hs=s+1
syn match skillFunction     "\<gensym("he=e-1
syn match skillFunction     "(get\(_pname\|_string\)\=\>"hs=s+1
syn match skillFunction     "\<get\(_pname\|_string\)\=("he=e-1
syn match skillFunction     "(getc\(har\)\=\>"hs=s+1
syn match skillFunction     "\<getc\(har\)\=("he=e-1
syn match skillFunction     "(getCurrentTime\>"hs=s+1
syn match skillFunction     "\<getCurrentTime("he=e-1
syn match skillFunction     "(getd\>"hs=s+1
syn match skillFunction     "\<getd("he=e-1
syn match skillFunction     "(getDirFiles\>"hs=s+1
syn match skillFunction     "\<getDirFiles("he=e-1
syn match skillFunction     "(getFnWriteProtect\>"hs=s+1
syn match skillFunction     "\<getFnWriteProtect("he=e-1
syn match skillFunction     "(getRunType\>"hs=s+1
syn match skillFunction     "\<getRunType("he=e-1
syn match skillFunction     "(getInstallPath\>"hs=s+1
syn match skillFunction     "\<getInstallPath("he=e-1
syn match skillFunction     "(getqq\=\>"hs=s+1
syn match skillFunction     "\<getqq\=("he=e-1
syn match skillFunction     "(gets\>"hs=s+1
syn match skillFunction     "\<gets("he=e-1
syn match skillFunction     "(getShellEnvVar\>"hs=s+1
syn match skillFunction     "\<getShellEnvVar("he=e-1
syn match skillFunction     "(getSkill\(Path\|Version\)\>"hs=s+1
syn match skillFunction     "\<getSkill\(Path\|Version\)("he=e-1
syn match skillFunction     "(getVarWriteProtect\>"hs=s+1
syn match skillFunction     "\<getVarWriteProtect("he=e-1
syn match skillFunction     "(getVersion\>"hs=s+1
syn match skillFunction     "\<getVersion("he=e-1
syn match skillFunction     "(getWarn\>"hs=s+1
syn match skillFunction     "\<getWarn("he=e-1
syn match skillFunction     "(getWorkingDir\>"hs=s+1
syn match skillFunction     "\<getWorkingDir("he=e-1
syn match skillRepeat       "(go\>"hs=s+1
syn match skillRepeat       "\<go("he=e-1
syn match skillConditional  "(if\>"hs=s+1
syn match skillConditional  "\<if("he=e-1
syn keyword skillConditional then else
syn match skillFunction     "(index\>"hs=s+1
syn match skillFunction     "\<index("he=e-1
syn match skillFunction     "(infile\>"hs=s+1
syn match skillFunction     "\<infile("he=e-1
syn match skillFunction     "(inportp\>"hs=s+1
syn match skillFunction     "\<inportp("he=e-1
syn match skillFunction     "(in\(Scheme\|Skill\)\>"hs=s+1
syn match skillFunction     "\<in\(Scheme\|Skill\)("he=e-1
syn match skillFunction     "(instring\>"hs=s+1
syn match skillFunction     "\<instring("he=e-1
syn match skillFunction     "(integerp\>"hs=s+1
syn match skillFunction     "\<integerp("he=e-1
syn match skillFunction     "(intToChar\>"hs=s+1
syn match skillFunction     "\<intToChar("he=e-1
syn match skillFunction     "(is\(Callable\|Dir\|Executable\|File\|FileEncrypted\|FileName\|Link\|Macro\|Writable\)\>"hs=s+1
syn match skillFunction     "\<is\(Callable\|Dir\|Executable\|File\|FileEncrypted\|FileName\|Link\|Macro\|Writable\)("he=e-1
syn match skillKeywords     "(n\=lambda\>"hs=s+1
syn match skillKeywords     "\<n\=lambda("he=e-1
syn match skillKeywords     "(last\>"hs=s+1
syn match skillKeywords     "\<last("he=e-1
syn match skillFunction     "(lconc\>"hs=s+1
syn match skillFunction     "\<lconc("he=e-1
syn match skillFunction     "(length\>"hs=s+1
syn match skillFunction     "\<length("he=e-1
syn match skillKeywords     "(let\>"hs=s+1
syn match skillKeywords     "\<let("he=e-1
syn match skillFunction     "(lineread\(string\)\=\>"hs=s+1
syn match skillFunction     "\<lineread\(string\)\=("he=e-1
syn match skillKeywords     "(list\>"hs=s+1
syn match skillKeywords     "\<list("he=e-1
syn match skillFunction     "(listp\>"hs=s+1
syn match skillFunction     "\<listp("he=e-1
syn match skillFunction     "(listToVector\>"hs=s+1
syn match skillFunction     "\<listToVector("he=e-1
syn match skillFunction     "(loadi\=\>"hs=s+1
syn match skillFunction     "\<loadi\=("he=e-1
syn match skillFunction     "(loadstring\>"hs=s+1
syn match skillFunction     "\<loadstring("he=e-1
syn match skillFunction     "(log\>"hs=s+1
syn match skillFunction     "\<log("he=e-1
syn match skillFunction     "(lowerCase\>"hs=s+1
syn match skillFunction     "\<lowerCase("he=e-1
syn match skillFunction     "(makeTable\>"hs=s+1
syn match skillFunction     "\<makeTable("he=e-1
syn match skillFunction     "(makeTempFileName\>"hs=s+1
syn match skillFunction     "\<makeTempFileName("he=e-1
syn match skillFunction     "(makeVector\>"hs=s+1
syn match skillFunction     "\<makeVector("he=e-1
syn match skillFunction     "(map\(c\|can\|car\|list\)\>"hs=s+1
syn match skillFunction     "\<map\(c\|can\|car\|list\)("he=e-1
syn match skillFunction     "(max\>"hs=s+1
syn match skillFunction     "\<max("he=e-1
syn match skillFunction     "(measureTime\>"hs=s+1
syn match skillFunction     "\<measureTime("he=e-1
syn match skillFunction     "(member\>"hs=s+1
syn match skillFunction     "\<member("he=e-1
syn match skillFunction     "(mem[qv]\>"hs=s+1
syn match skillFunction     "\<mem[qv]("he=e-1
syn match skillFunction     "(min\>"hs=s+1
syn match skillFunction     "\<min("he=e-1
syn match skillFunction     "(minusp\>"hs=s+1
syn match skillFunction     "\<minusp("he=e-1
syn match skillFunction     "(mod\(ulo\)\=\>"hs=s+1
syn match skillFunction     "\<mod\(ulo\)\=("he=e-1
syn match skillKeywords     "([mn]\=procedure\>"hs=s+1
syn match skillKeywords     "\<[mn]\=procedure("he=e-1
syn match skillFunction     "(ncon[cs]\>"hs=s+1
syn match skillFunction     "\<ncon[cs]("he=e-1
syn match skillFunction     "(needNCells\>"hs=s+1
syn match skillFunction     "\<needNCells("he=e-1
syn match skillFunction     "(negativep\>"hs=s+1
syn match skillFunction     "\<negativep("he=e-1
syn match skillFunction     "(neq\(ual\)\=\>"hs=s+1
syn match skillFunction     "\<neq\(ual\)\=("he=e-1
syn match skillFunction     "(newline\>"hs=s+1
syn match skillFunction     "\<newline("he=e-1
syn match skillFunction     "(nindex\>"hs=s+1
syn match skillFunction     "\<nindex("he=e-1
syn match skillFunction     "(not\>"hs=s+1
syn match skillFunction     "\<not("he=e-1
syn match skillFunction     "(nth\(cdr\|elem\)\=\>"hs=s+1
syn match skillFunction     "\<nth\(cdr\|elem\)\=("he=e-1
syn match skillFunction     "(null\>"hs=s+1
syn match skillFunction     "\<null("he=e-1
syn match skillFunction     "(numberp\>"hs=s+1
syn match skillFunction     "\<numberp("he=e-1
syn match skillFunction     "(numOpenFiles\>"hs=s+1
syn match skillFunction     "\<numOpenFiles("he=e-1
syn match skillFunction     "(oddp\>"hs=s+1
syn match skillFunction     "\<oddp("he=e-1
syn match skillFunction     "(onep\>"hs=s+1
syn match skillFunction     "\<onep("he=e-1
syn match skillFunction     "(otherp\>"hs=s+1
syn match skillFunction     "\<otherp("he=e-1
syn match skillFunction     "(outfile\>"hs=s+1
syn match skillFunction     "\<outfile("he=e-1
syn match skillFunction     "(outportp\>"hs=s+1
syn match skillFunction     "\<outportp("he=e-1
syn match skillFunction     "(pairp\>"hs=s+1
syn match skillFunction     "\<pairp("he=e-1
syn match skillFunction     "(parseString\>"hs=s+1
syn match skillFunction     "\<parseString("he=e-1
syn match skillFunction     "(plist\>"hs=s+1
syn match skillFunction     "\<plist("he=e-1
syn match skillFunction     "(plusp\>"hs=s+1
syn match skillFunction     "\<plusp("he=e-1
syn match skillFunction     "(portp\>"hs=s+1
syn match skillFunction     "\<portp("he=e-1
syn match skillFunction     "(p\=print\>"hs=s+1
syn match skillFunction     "\<p\=print("he=e-1
syn match skillFunction     "(prependInstallPath\>"hs=s+1
syn match skillFunction     "\<prependInstallPath("he=e-1
syn match skillFunction     "(printl\(ev\|n\)\>"hs=s+1
syn match skillFunction     "\<printl\(ev\|n\)("he=e-1
syn match skillFunction     "(procedurep\>"hs=s+1
syn match skillFunction     "\<procedurep("he=e-1
syn match skillKeywords     "(prog[12n]\=\>"hs=s+1
syn match skillKeywords     "\<prog[12n]\=("he=e-1
syn match skillFunction     "(putd\>"hs=s+1
syn match skillFunction     "\<putd("he=e-1
syn match skillFunction     "(putpropq\{,2}\>"hs=s+1
syn match skillFunction     "\<putpropq\{,2}("he=e-1
syn match skillFunction     "(random\>"hs=s+1
syn match skillFunction     "\<random("he=e-1
syn match skillFunction     "(read\>"hs=s+1
syn match skillFunction     "\<read("he=e-1
syn match skillFunction     "(readString\>"hs=s+1
syn match skillFunction     "\<readString("he=e-1
syn match skillFunction     "(readTable\>"hs=s+1
syn match skillFunction     "\<readTable("he=e-1
syn match skillFunction     "(realp\>"hs=s+1
syn match skillFunction     "\<realp("he=e-1
syn match skillFunction     "(regExit\(After\|Before\)\>"hs=s+1
syn match skillFunction     "\<regExit\(After\|Before\)("he=e-1
syn match skillFunction     "(remainder\>"hs=s+1
syn match skillFunction     "\<remainder("he=e-1
syn match skillFunction     "(remdq\=\>"hs=s+1
syn match skillFunction     "\<remdq\=("he=e-1
syn match skillFunction     "(remExitProc\>"hs=s+1
syn match skillFunction     "\<remExitProc("he=e-1
syn match skillFunction     "(remove\>"hs=s+1
syn match skillFunction     "\<remove("he=e-1
syn match skillFunction     "(remprop\>"hs=s+1
syn match skillFunction     "\<remprop("he=e-1
syn match skillFunction     "(remq\>"hs=s+1
syn match skillFunction     "\<remq("he=e-1
syn match skillKeywords     "(return\>"hs=s+1
syn match skillKeywords     "\<return("he=e-1
syn match skillFunction     "(reverse\>"hs=s+1
syn match skillFunction     "\<reverse("he=e-1
syn match skillFunction     "(rexCompile\>"hs=s+1
syn match skillFunction     "\<rexCompile("he=e-1
syn match skillFunction     "(rexExecute\>"hs=s+1
syn match skillFunction     "\<rexExecute("he=e-1
syn match skillFunction     "(rexMagic\>"hs=s+1
syn match skillFunction     "\<rexMagic("he=e-1
syn match skillFunction     "(rexMatchAssocList\>"hs=s+1
syn match skillFunction     "\<rexMatchAssocList("he=e-1
syn match skillFunction     "(rexMatchList\>"hs=s+1
syn match skillFunction     "\<rexMatchList("he=e-1
syn match skillFunction     "(rexMatchp\>"hs=s+1
syn match skillFunction     "\<rexMatchp("he=e-1
syn match skillFunction     "(rexReplace\>"hs=s+1
syn match skillFunction     "\<rexReplace("he=e-1
syn match skillFunction     "(rexSubstitute\>"hs=s+1
syn match skillFunction     "\<rexSubstitute("he=e-1
syn match skillFunction     "(rindex\>"hs=s+1
syn match skillFunction     "\<rindex("he=e-1
syn match skillFunction     "(round\>"hs=s+1
syn match skillFunction     "\<round("he=e-1
syn match skillFunction     "(rplac[ad]\>"hs=s+1
syn match skillFunction     "\<rplac[ad]("he=e-1
syn match skillFunction     "(schemeTopLevelEnv\>"hs=s+1
syn match skillFunction     "\<schemeTopLevelEnv("he=e-1
syn match skillFunction     "(set\>"hs=s+1
syn match skillFunction     "\<set("he=e-1
syn match skillFunction     "(setarray\>"hs=s+1
syn match skillFunction     "\<setarray("he=e-1
syn match skillFunction     "(setc[ad]r\>"hs=s+1
syn match skillFunction     "\<setc[ad]r("he=e-1
syn match skillFunction     "(setFnWriteProtect\>"hs=s+1
syn match skillFunction     "\<setFnWriteProtect("he=e-1
syn match skillFunction     "(setof\>"hs=s+1
syn match skillFunction     "\<setof("he=e-1
syn match skillFunction     "(setplist\>"hs=s+1
syn match skillFunction     "\<setplist("he=e-1
syn match skillFunction     "(setq\>"hs=s+1
syn match skillFunction     "\<setq("he=e-1
syn match skillFunction     "(setShellEnvVar\>"hs=s+1
syn match skillFunction     "\<setShellEnvVar("he=e-1
syn match skillFunction     "(setSkillPath\>"hs=s+1
syn match skillFunction     "\<setSkillPath("he=e-1
syn match skillFunction     "(setVarWriteProtect\>"hs=s+1
syn match skillFunction     "\<setVarWriteProtect("he=e-1
syn match skillFunction     "(sh\(ell\)\=\>"hs=s+1
syn match skillFunction     "\<sh\(ell\)\=("he=e-1
syn match skillFunction     "(simplifyFilename\>"hs=s+1
syn match skillFunction     "\<simplifyFilename("he=e-1
syn match skillFunction     "(sort\(car\)\=\>"hs=s+1
syn match skillFunction     "\<sort\(car\)\=("he=e-1
syn match skillFunction     "(sqrt\>"hs=s+1
syn match skillFunction     "\<sqrt("he=e-1
syn match skillFunction     "(srandom\>"hs=s+1
syn match skillFunction     "\<srandom("he=e-1
syn match skillFunction     "(sstatus\>"hs=s+1
syn match skillFunction     "\<sstatus("he=e-1
syn match skillFunction     "(strn\=cat\>"hs=s+1
syn match skillFunction     "\<strn\=cat("he=e-1
syn match skillFunction     "(strn\=cmp\>"hs=s+1
syn match skillFunction     "\<strn\=cmp("he=e-1
syn match skillFunction     "(stringp\>"hs=s+1
syn match skillFunction     "\<stringp("he=e-1
syn match skillFunction     "(stringTo\(Function\|Symbol\|Time\)\>"hs=s+1
syn match skillFunction     "\<stringTo\(Function\|Symbol\|Time\)("he=e-1
syn match skillFunction     "(strlen\>"hs=s+1
syn match skillFunction     "\<strlen("he=e-1
syn match skillFunction     "(sub1\>"hs=s+1
syn match skillFunction     "\<sub1("he=e-1
syn match skillFunction     "(subst\>"hs=s+1
syn match skillFunction     "\<subst("he=e-1
syn match skillFunction     "(substring\>"hs=s+1
syn match skillFunction     "\<substring("he=e-1
syn match skillFunction     "(sxtd\>"hs=s+1
syn match skillFunction     "\<sxtd("he=e-1
syn match skillFunction     "(symbolp\>"hs=s+1
syn match skillFunction     "\<symbolp("he=e-1
syn match skillFunction     "(symbolToString\>"hs=s+1
syn match skillFunction     "\<symbolToString("he=e-1
syn match skillFunction     "(symeval\>"hs=s+1
syn match skillFunction     "\<symeval("he=e-1
syn match skillFunction     "(symstrp\>"hs=s+1
syn match skillFunction     "\<symstrp("he=e-1
syn match skillFunction     "(system\>"hs=s+1
syn match skillFunction     "\<system("he=e-1
syn match skillFunction     "(tablep\>"hs=s+1
syn match skillFunction     "\<tablep("he=e-1
syn match skillFunction     "(tableToList\>"hs=s+1
syn match skillFunction     "\<tableToList("he=e-1
syn match skillFunction     "(tailp\>"hs=s+1
syn match skillFunction     "\<tailp("he=e-1
syn match skillFunction     "(tconc\>"hs=s+1
syn match skillFunction     "\<tconc("he=e-1
syn match skillFunction     "(timeToString\>"hs=s+1
syn match skillFunction     "\<timeToString("he=e-1
syn match skillFunction     "(timeToTm\>"hs=s+1
syn match skillFunction     "\<timeToTm("he=e-1
syn match skillFunction     "(tmToTime\>"hs=s+1
syn match skillFunction     "\<tmToTime("he=e-1
syn match skillFunction     "(truncate\>"hs=s+1
syn match skillFunction     "\<truncate("he=e-1
syn match skillFunction     "(typep\=\>"hs=s+1
syn match skillFunction     "\<typep\=("he=e-1
syn match skillFunction     "(unalias\>"hs=s+1
syn match skillFunction     "\<unalias("he=e-1
syn match skillConditional  "(unless\>"hs=s+1
syn match skillConditional  "\<unless("he=e-1
syn match skillFunction     "(upperCase\>"hs=s+1
syn match skillFunction     "\<upperCase("he=e-1
syn match skillFunction     "(vector\(ToList\)\=\>"hs=s+1
syn match skillFunction     "\<vector\(ToList\)\=("he=e-1
syn match skillFunction     "(warn\>"hs=s+1
syn match skillFunction     "\<warn("he=e-1
syn match skillConditional  "(when\>"hs=s+1
syn match skillConditional  "\<when("he=e-1
syn match skillRepeat       "(while\>"hs=s+1
syn match skillRepeat       "\<while("he=e-1
syn match skillFunction     "(write\>"hs=s+1
syn match skillFunction     "\<write("he=e-1
syn match skillFunction     "(writeTable\>"hs=s+1
syn match skillFunction     "\<writeTable("he=e-1
syn match skillFunction     "(xcons\>"hs=s+1
syn match skillFunction     "\<xcons("he=e-1
syn match skillFunction     "(zerop\>"hs=s+1
syn match skillFunction     "\<zerop("he=e-1
syn match skillFunction     "(zxtd\>"hs=s+1
syn match skillFunction     "\<zxtd("he=e-1

" DFII procedural interface routines

" CDF functions
syn match skillcdfFunctions			"(cdf\u\a\+\>"hs=s+1
syn match skillcdfFunctions			"\<cdf\u\a\+("he=e-1
" graphic editor functions
syn match skillgeFunctions			"(ge\u\a\+\>"hs=s+1
syn match skillgeFunctions			"\<ge\u\a\+("he=e-1
" human interface functions
syn match skillhiFunctions			"(hi\u\a\+\>"hs=s+1
syn match skillhiFunctions			"\<hi\u\a\+("he=e-1
" layout editor functions
syn match skillleFunctions			"(le\u\a\+\>"hs=s+1
syn match skillleFunctions			"\<le\u\a\+("he=e-1
" database|design editor|design flow functions
syn match skilldbefFunctions		"(d[bef]\u\a\+\>"hs=s+1
syn match skilldbefFunctions		"\<d[bef]\u\a\+("he=e-1
" design management & design data services functions
syn match skillddFunctions			"(dd[s]\=\u\a\+\>"hs=s+1
syn match skillddFunctions			"\<dd[s]\=\u\a\+("he=e-1
" parameterized cell functions
syn match skillpcFunctions			"(pc\u\a\+\>"hs=s+1
syn match skillpcFunctions			"\<pc\u\a\+("he=e-1
" tech file functions
syn match skilltechFunctions		"(\(tech\|tc\)\u\a\+\>"hs=s+1
syn match skilltechFunctions		"\<\(tech\|tc\)\u\a\+("he=e-1

" strings
syn region skillString				start=+"+ skip=+\\"+ end=+"+

syn keyword skillTodo contained		TODO FIXME XXX
syn keyword skillNote contained		NOTE IMPORTANT

" comments are either C-style or begin with a semicolon
syn region skillComment				start="/\*" end="\*/" contains=skillTodo,skillNote
syn match skillComment				";.*" contains=skillTodo,skillNote
syn match skillCommentError			"\*/"

syn sync ccomment skillComment minlines=10

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link skillcdfFunctions	Function
hi def link skillgeFunctions		Function
hi def link skillhiFunctions		Function
hi def link skillleFunctions		Function
hi def link skilldbefFunctions	Function
hi def link skillddFunctions		Function
hi def link skillpcFunctions		Function
hi def link skilltechFunctions	Function
hi def link skillConstants		Constant
hi def link skillFunction		Function
hi def link skillKeywords		Statement
hi def link skillConditional		Conditional
hi def link skillRepeat			Repeat
hi def link skillString			String
hi def link skillTodo			Todo
hi def link skillNote			Todo
hi def link skillComment			Comment
hi def link skillCommentError	Error


let b:current_syntax = "skill"

" vim: ts=4
