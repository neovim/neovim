" Vim syntax file
" Language:	DCL (Digital Command Language - vms)
" Maintainer:	Charles E. Campbell <NdrOchipS@PcampbellAfamily.Mbiz>
" Last Change:	Aug 31, 2016
" Version:	11
" URL:	http://www.drchip.org/astronaut/vim/index.html#SYNTAX_DCL

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

if !has("patch-7.4.1142")
  setlocal iskeyword=$,@,48-57,_
else
 syn iskeyword $,@,48-57,_
endif

syn case ignore
syn keyword dclInstr	accounting	del[ete]	gen[cat]	mou[nt]	run
syn keyword dclInstr	all[ocate]	dep[osit]	gen[eral]	ncp	run[off]
syn keyword dclInstr	ana[lyze]	dia[gnose]	gos[ub]	ncs	sca
syn keyword dclInstr	app[end]	dif[ferences]	got[o]	on	sea[rch]
syn keyword dclInstr	ass[ign]	dir[ectory]	hel[p]	ope[n]	set
syn keyword dclInstr	att[ach]	dis[able]	ico[nv]	pas[cal]	sho[w]
syn keyword dclInstr	aut[horize]	dis[connect]	if	pas[sword]	sor[t]
syn keyword dclInstr	aut[ogen]	dis[mount]	ini[tialize]	pat[ch]	spa[wn]
syn keyword dclInstr	bac[kup]	dpm[l]	inq[uire]	pca	sta[rt]
syn keyword dclInstr	cal[l]	dqs	ins[tall]	pho[ne]	sto[p]
syn keyword dclInstr	can[cel]	dsr	job	pri[nt]	sub[mit]
syn keyword dclInstr	cc	dst[graph]	lat[cp]	pro[duct]	sub[routine]
syn keyword dclInstr	clo[se]	dtm	lib[rary]	psw[rap]	swx[cr]
syn keyword dclInstr	cms	dum[p]	lic[ense]	pur[ge]	syn[chronize]
syn keyword dclInstr	con[nect]	edi[t]	lin[k]	qde[lete]	sys[gen]
syn keyword dclInstr	con[tinue]	ena[ble]	lmc[p]	qse[t]	sys[man]
syn keyword dclInstr	con[vert]	end[subroutine]	loc[ale]	qsh[ow]	tff
syn keyword dclInstr	cop[y]	eod	log[in]	rea[d]	then
syn keyword dclInstr	cre[ate]	eoj	log[out]	rec[all]	typ[e]
syn keyword dclInstr	cxx	exa[mine]	lse[dit]	rec[over]	uil
syn keyword dclInstr	cxx[l_help]	exc[hange]	mac[ro]	ren[ame]	unl[ock]
syn keyword dclInstr	dea[llocate]	exi[t]	mai[l]	rep[ly]	ves[t]
syn keyword dclInstr	dea[ssign]	fdl	mer[ge]	req[uest]	vie[w]
syn keyword dclInstr	deb[ug]	flo[wgraph]	mes[sage]	ret[urn]	wai[t]
syn keyword dclInstr	dec[k]	fon[t]	mms	rms	wri[te]
syn keyword dclInstr	def[ine]	for[tran]

syn keyword dclLexical	f$context	f$edit	  f$getjpi	f$message	f$setprv
syn keyword dclLexical	f$csid	f$element	  f$getqui	f$mode	f$string
syn keyword dclLexical	f$cvsi	f$environment	  f$getsyi	f$parse	f$time
syn keyword dclLexical	f$cvtime	f$extract	  f$identifier	f$pid	f$trnlnm
syn keyword dclLexical	f$cvui	f$fao	  f$integer	f$privilege	f$type
syn keyword dclLexical	f$device	f$file_attributes f$length	f$process	f$user
syn keyword dclLexical	f$directory	f$getdvi	  f$locate	f$search	f$verify

syn match   dclMdfy	"/\I\i*"	nextgroup=dclMdfySet,dclMdfySetString
syn match   dclMdfySet	"=[^ \t"]*"	contained
syn region  dclMdfySet	matchgroup=dclMdfyBrkt start="=\[" matchgroup=dclMdfyBrkt end="]"	contains=dclMdfySep
syn region  dclMdfySetString	start='="'	skip='""'	end='"'	contained
syn match   dclMdfySep	"[:,]"	contained

" Numbers
syn match   dclNumber	"\d\+"

" Varname (mainly to prevent dclNumbers from being recognized when part of a dclVarname)
syn match   dclVarname	"\I\i*"

" Filenames (devices, paths)
syn match   dclDevice	"\I\i*\(\$\I\i*\)\=:[^=]"me=e-1		nextgroup=dclDirPath,dclFilename
syn match   dclDirPath	"\[\(\I\i*\.\)*\I\i*\]"		contains=dclDirSep	nextgroup=dclFilename
syn match   dclFilename	"\I\i*\$\(\I\i*\)\=\.\(\I\i*\)*\(;\d\+\)\="	contains=dclDirSep
syn match   dclFilename	"\I\i*\.\(\I\i*\)\=\(;\d\+\)\="	contains=dclDirSep	contained
syn match   dclDirSep	"[[\].;]"

" Strings
syn region  dclString	start='"'	skip='""'	end='"'	contains=@Spell

" $ stuff and comments
syn cluster dclCommentGroup	contains=dclStart,dclTodo,@Spell
syn match   dclStart	"^\$"	skipwhite nextgroup=dclExe
syn match   dclContinue	"-$"
syn match   dclComment	"^\$!.*$"	contains=@dclCommentGroup
syn match   dclExe	"\I\i*"	contained
syn keyword dclTodo contained	COMBAK	DEBUG	FIXME	TODO	XXX

" Assignments and Operators
syn match   dclAssign	":==\="
syn match   dclAssign	"="
syn match   dclOper	"--\|+\|\*\|/"
syn match   dclLogOper	"\.[a-zA-Z][a-zA-Z][a-zA-Z]\=\." contains=dclLogical,dclLogSep
syn keyword dclLogical contained	and	ge	gts	lt	nes
syn keyword dclLogical contained	eq	ges	le	lts	not
syn keyword dclLogical contained	eqs	gt	les	ne	or
syn match   dclLogSep	"\."		contained

" @command procedures
syn match   dclCmdProcStart	"@"			nextgroup=dclCmdProc
syn match   dclCmdProc	"\I\i*\(\.\I\i*\)\="	contained
syn match   dclCmdProc	"\I\i*:"		contained	nextgroup=dclCmdDirPath,dclCmdProc
syn match   dclCmdDirPath	"\[\(\I\i*\.\)*\I\i*\]"	contained	nextgroup=delCmdProc

" labels
syn match   dclGotoLabel	"^\$\s*\I\i*:\s*$"	contains=dclStart

" parameters
syn match   dclParam	"'\I[a-zA-Z0-9_$]*'\="

syn region  dclFuncList	matchgroup=Delimiter start="(" matchgroup=Delimiter end=")" contains=ALLBUT,dclCmdDirPath,dclCmdProc,dclCmdProc,dclDirPath,dclFilename,dclFilename,dclMdfySet,dclMdfySetString,delCmdProc,dclExe,dclTodo
syn match   dclError	")"

" Define the default highlighting.
if !exists("skip_dcl_syntax_inits")

 hi def link dclLogOper	dclError
 hi def link dclLogical	dclOper
 hi def link dclLogSep	dclSep

 hi def link dclAssign	Operator
 hi def link dclCmdProc	Special
 hi def link dclCmdProcStart	Operator
 hi def link dclComment	Comment
 hi def link dclContinue	Statement
 hi def link dclDevice	Identifier
 hi def link dclDirPath	Identifier
 hi def link dclDirPath	Identifier
 hi def link dclDirSep	Delimiter
 hi def link dclError	Error
 hi def link dclExe		Statement
 hi def link dclFilename	NONE
 hi def link dclGotoLabel	Label
 hi def link dclInstr	Statement
 hi def link dclLexical	Function
 hi def link dclMdfy	Type
 hi def link dclMdfyBrkt	Delimiter
 hi def link dclMdfySep	Delimiter
 hi def link dclMdfySet	Type
 hi def link dclMdfySetString	String
 hi def link dclNumber	Number
 hi def link dclOper	Operator
 hi def link dclParam	Special
 hi def link dclSep		Delimiter
 hi def link dclStart	Delimiter
 hi def link dclString	String
 hi def link dclTodo	Todo

endif

let b:current_syntax = "dcl"

" vim: ts=16
