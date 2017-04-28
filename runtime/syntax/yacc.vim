" Vim syntax file
" Language:	Yacc
" Maintainer:	Charles E. Campbell <NdrOchipS@PcampbellAfamily.Mbiz>
" Last Change:	Aug 31, 2016
" Version:	15
" URL:	http://www.drchip.org/astronaut/vim/index.html#SYNTAX_YACC
"
" Options: {{{1
"   g:yacc_uses_cpp : if this variable exists, then C++ is loaded rather than C

" ---------------------------------------------------------------------
" this version of syntax/yacc.vim requires 6.0 or later
if exists("b:current_syntax")
 syntax clear
endif

" ---------------------------------------------------------------------
"  Folding Support {{{1
if has("folding")
 com! -nargs=+ SynFold	<args> fold
else
 com! -nargs=+ SynFold	<args>
endif

" ---------------------------------------------------------------------
" Read the C syntax to start with {{{1
" Read the C/C++ syntax to start with
let s:Cpath= fnameescape(expand("<sfile>:p:h").(exists("g:yacc_uses_cpp")? "/cpp.vim" : "/c.vim"))
if !filereadable(s:Cpath)
 for s:Cpath in split(globpath(&rtp,(exists("g:yacc_uses_cpp")? "syntax/cpp.vim" : "syntax/c.vim")),"\n")
  if filereadable(fnameescape(s:Cpath))
   let s:Cpath= fnameescape(s:Cpath)
   break
  endif
 endfor
endif
exe "syn include @yaccCode ".s:Cpath

" ---------------------------------------------------------------------
"  Yacc Clusters: {{{1
syn cluster yaccInitCluster	contains=yaccKey,yaccKeyActn,yaccBrkt,yaccType,yaccString,yaccUnionStart,yaccHeader2,yaccComment,yaccDefines,yaccParseParam,yaccParseOption
syn cluster yaccRulesCluster	contains=yaccNonterminal,yaccString

" ---------------------------------------------------------------------
"  Yacc Sections: {{{1
SynFold syn	region	yaccInit	start='.'ms=s-1,rs=s-1	matchgroup=yaccSectionSep	end='^%%$'me=e-2,re=e-2	contains=@yaccInitCluster	nextgroup=yaccRules	skipwhite skipempty contained
SynFold syn	region	yaccInit2      start='\%^.'ms=s-1,rs=s-1	matchgroup=yaccSectionSep	end='^%%$'me=e-2,re=e-2	contains=@yaccInitCluster	nextgroup=yaccRules	skipwhite skipempty
SynFold syn	region	yaccHeader2	matchgroup=yaccSep	start="^\s*\zs%{"	end="^\s*%}"		contains=@yaccCode	nextgroup=yaccInit	skipwhite skipempty contained
SynFold syn	region	yaccHeader	matchgroup=yaccSep	start="^\s*\zs%{"	end="^\s*%}"		contains=@yaccCode	nextgroup=yaccInit	skipwhite skipempty
SynFold syn	region	yaccRules	matchgroup=yaccSectionSep	start='^%%$'		end='^%%$'me=e-2,re=e-2	contains=@yaccRulesCluster	nextgroup=yaccEndCode	skipwhite skipempty contained
SynFold syn	region	yaccEndCode	matchgroup=yaccSectionSep	start='^%%$'		end='\%$'		contains=@yaccCode	contained

" ---------------------------------------------------------------------
" Yacc Commands: {{{1
syn	match	yaccDefines	'^%define\s\+.*$'
syn	match	yaccParseParam	'%\(parse\|lex\)-param\>'		skipwhite	nextgroup=yaccParseParamStr
syn	match	yaccParseOption '%\%(api\.pure\|pure-parser\|locations\|error-verbose\)\>'
syn	region	yaccParseParamStr	contained matchgroup=Delimiter	start='{'	end='}'	contains=cStructure

syn	match	yaccDelim	"[:|]"	contained
syn	match	yaccOper	"@\d\+"	contained

syn	match	yaccKey	"^\s*%\(token\|type\|left\|right\|start\|ident\|nonassoc\)\>"	contained
syn	match	yaccKey	"\s%\(prec\|expect\)\>"	contained
syn	match	yaccKey	"\$\(<[a-zA-Z_][a-zA-Z_0-9]*>\)\=[\$0-9]\+"	contained
syn	keyword	yaccKeyActn	yyerrok yyclearin	contained

syn	match	yaccUnionStart	"^%union"	skipwhite skipnl nextgroup=yaccUnion	contained
SynFold syn	region	yaccUnion	matchgroup=yaccCurly start="{" matchgroup=yaccCurly end="}" contains=@yaccCode	contained
syn	match	yaccBrkt	"[<>]"	contained
syn	match	yaccType	"<[a-zA-Z_][a-zA-Z0-9_]*>"	contains=yaccBrkt	contained

SynFold syn	region	yaccNonterminal	start="^\s*\a\w*\ze\_s*\(/\*\_.\{-}\*/\)\=\_s*:"	matchgroup=yaccDelim end=";"	matchgroup=yaccSectionSep end='^%%$'me=e-2,re=e-2 contains=yaccAction,yaccDelim,yaccString,yaccComment	contained
syn	region	yaccComment	start="/\*"	end="\*/"
syn	match	yaccString	"'[^']*'"	contained


" ---------------------------------------------------------------------
" I'd really like to highlight just the outer {}.  Any suggestions??? {{{1
syn	match	yaccCurlyError	"[{}]"
SynFold syn	region	yaccAction	matchgroup=yaccCurly start="{" end="}" 	contains=@yaccCode,yaccVar		contained
syn	match	yaccVar	'\$\d\+\|\$\$\|\$<\I\i*>\$\|\$<\I\i*>\d\+'	containedin=cParen,cPreProc,cMulti	contained

" ---------------------------------------------------------------------
" Yacc synchronization: {{{1
syn sync fromstart

" ---------------------------------------------------------------------
" Define the default highlighting. {{{1
if !exists("skip_yacc_syn_inits")
  hi def link yaccBrkt	yaccStmt
  hi def link yaccComment	Comment
  hi def link yaccCurly	Delimiter
  hi def link yaccCurlyError	Error
  hi def link yaccDefines	cDefine
  hi def link yaccDelim	Delimiter
  hi def link yaccKeyActn	Special
  hi def link yaccKey	yaccStmt
  hi def link yaccNonterminal	Function
  hi def link yaccOper	yaccStmt
  hi def link yaccParseOption	cDefine
  hi def link yaccParseParam	yaccParseOption
  hi def link yaccSectionSep	Todo
  hi def link yaccSep	Delimiter
  hi def link yaccStmt	Statement
  hi def link yaccString	String
  hi def link yaccType	Type
  hi def link yaccUnionStart	yaccKey
  hi def link yaccVar	Special
endif

" ---------------------------------------------------------------------
"  Cleanup: {{{1
delcommand SynFold
let b:current_syntax = "yacc"

" ---------------------------------------------------------------------
"  Modelines: {{{1
" vim: ts=15 fdm=marker
