" Vim syntax file
" Language:	Lex and Flex
" Maintainer:	This runtime file is looking for a new maintainer.
" Former Maintainer:	Charles E. Campbell
" Contributor:	Robert A. van Engelen <engelen@acm.org>
" Version:	18
" Last Change:	Apr 24, 2020
"   2024 Feb 19 by Vim Project (announce adoption)

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Read the C++ syntax to start with
let s:Cpath= fnameescape(expand("<sfile>:p:h")."/cpp.vim")
if !filereadable(s:Cpath)
 for s:Cpath in split(globpath(&rtp,"syntax/cpp.vim"),"\n")
  if filereadable(fnameescape(s:Cpath))
   let s:Cpath= fnameescape(s:Cpath)
   break
  endif
 endfor
endif
exe "syn include @lexCcode ".s:Cpath

" --- ========= ---
" --- Lex stuff ---
" --- ========= ---

" Definitions
" %%
" Rules
" %%
" User Code
"
" --- ======= ---
" --- Example ---
" --- ======= ---
"
"   // this is a valid lex file
"   // indented initial code block
"   #include <stdlib.h>
" %{
" // initial code block
" #include <stdio.h>
" const char *sep = "";
" %}
" %option outfile="scanner.c" noyywrap nodefault
" %x COMMENT
" id      [A-Za-z_][A-Za-z0-9_]*
" %%
"   // indented initial action code block
"   printf("BEGIN");
" {id}    printf("%s%s", sep, yytext); sep = "";
" .       |
" \n      { sep = "\n"; }
" "/*"    { BEGIN COMMENT; }
" "//".*  { }
" <COMMENT>{
" "*/"    { BEGIN INITIAL; }
" .|\n    
" }
" <*><<EOF>> { // end of file
"              printf("\nEND\n");
"              yyterminate();
"            }
" %%
" void scan()
" {
"   while (yylex())
"     continue;
" }
" /* main program */
" int main()
" { 
"   scan();
" }   

" Definitions Section with initial code blocks, abbreviations, options, states
if has("folding")
 syn region lexAbbrvBlock	fold	start="^\S"	end="^\ze%%"	skipnl	nextgroup=lexPatBlock	contains=lexOptions,lexAbbrv,lexInitialCodeBlock,lexInclude,lexAbbrvComment,lexStartState
else
 syn region lexAbbrvBlock		start="^\S"	end="^\ze%%"	skipnl	nextgroup=lexPatBlock	contains=lexOptions,lexAbbrv,lexInitialCodeBlock,lexInclude,lexAbbrvComment,lexStartState
endif
syn match  lexOptions		"^%\a\+\(\s.*\|[^{]*\)$"				contains=lexOptionsEq,lexPatString,lexSlashQuote,lexBrace,lexSlashBrace
syn match  lexOptionsEq		"="					skipwhite	contained
syn match  lexAbbrv		"^\I\i*\s"me=e-1			skipwhite	contained	nextgroup=lexAbbrvPat
syn match  lexAbbrvPat		"\s\S.*$"lc=1						contained	contains=lexPatAbbrv,lexPatString,lexSlashQuote,lexBrace,lexSlashBrace	nextgroup=lexAbbrv,lexInclude
syn match  lexStartState	"^%\(xs\?\|s\)\(t\(a\(t\(e\?\)\?\)\?\)\?\)\?\(\s\+\I\i*\)\+\s*$"	contained	contains=lexStartStateCmd
syn match  lexStartStateCmd	'^%\(xs\?\|s\)\(t\(a\(t\(e\?\)\?\)\?\)\?\)\?'	contained
if has("folding")
 syn region lexInitialCodeBlock	fold				start="^\s\+"	end="^\S"me=e-1			contains=@lexCcode
 syn region lexInclude		fold	matchgroup=lexSep	start="^%\a*{"	end="^%\?}"	contained	contains=@lexCcode,lexCFunctions
 syn region lexAbbrvComment	fold				start="^\s*//"	end="$"		contains=@Spell
 syn region lexAbbrvComment	fold				start="^\s*/\*"	end="\*/"	contains=@Spell
else
 syn region lexInitialCodeBlock					start="^\s\+"	end="^\S"me=e-1			contains=@lexCcode
 syn region lexInclude			matchgroup=lexSep	start="^%\a*{"	end="^%\?}"	contained	contains=@lexCcode,lexCFunctions
 syn region lexAbbrvComment					start="^\s*//"	end="$"		contains=@Spell
 syn region lexAbbrvComment					start="^\s*/\*"	end="\*/"	contains=@Spell
endif

" Rules Section with patterns and actions
if has("folding")
 syn region lexPatBlock		fold	matchgroup=Todo		start="^%%"	matchgroup=Todo		end="^\ze%%"	skipnl	skipwhite	nextgroup=lexFinalCodeBlock	contains=lexPatTag,lexPatTagZone,lexPatComment,lexPat,lexPatSep,lexPatInclude
 syn region lexPat		fold				start="\S"	skip="\\\\\|\\\s"	end="\ze\(\s*$\|\s\+\(\h\|{\W\|{$\|[-+*]\|//\|/\*\)\)"	skipwhite	contained nextgroup=lexMorePat,lexPatSep,lexPatEnd	contains=lexPatTag,lexPatString,lexSlashQuote,lexPatAbbrv,lexBrace,lexSlashBrace
 syn region lexPatInclude	fold	matchgroup=lexSep	start="^%{"	end="^%}"	contained	contains=@lexCcode
 syn region lexBrace		fold	matchgroup=Character	start="\["	skip="\\.\|\[:\a\+:\]\|\[\.\a\+\.\]\|\[=.=\]"	end="\]"	contained
 syn region lexPatString	fold	matchgroup=String	start=+"+	skip=+\\\\\|\\"+	matchgroup=String	end=+"+	contained
else
 syn region lexPatBlock			matchgroup=Todo		start="^%%"	matchgroup=Todo		end="^\ze%%"	skipnl	skipwhite	nextgroup=lexFinalCodeBlock	contains=lexPatTag,lexPatTagZone,lexPatComment,lexPat,lexPatSep,lexPatInclude
 syn region lexPat						start="\S"	skip="\\\\\|\\\s"	end="\ze\(\s*$\|\s\+\(\h\|{\W\|{$\|[-+*]\|//\|/\*\)\)"	skipwhite	contained nextgroup=lexMorePat,lexPatSep,lexPatEnd	contains=lexPatTag,lexPatString,lexSlashQuote,lexPatAbbrv,lexBrace,lexSlashBrace
 syn region lexPatInclude		matchgroup=lexSep	start="^%{"	end="^%}"	contained	contains=@lexCcode
 syn region lexBrace			matchgroup=Character	start="\["	skip="\\.\|\[:\a\+:\]\|\[\.\a\+\.\]\|\[=.=\]"	end="\]"	contained
 syn region lexPatString		matchgroup=String	start=+"+	skip=+\\\\\|\\"+	matchgroup=String	end=+"+	contained
endif
syn match  lexPatAbbrv		"{\I\i*}"hs=s+1,he=e-1					contained
syn match  lexPatTag		"^<\^\?\(\I\i*\|\*\)\(,\^\?\(\I\i*\|\*\)\)*>"		contained	nextgroup=lexPat,lexMorePat,lexPatSep,lexPatEnd
syn match  lexPatTagZone	"^<\^\?\(\I\i*\|\*\)\(,\^\?\(\I\i*\|\*\)\)*>\s*{$"me=e-1	contained	nextgroup=lexPatTagZoneStart

if has("folding")
 syn region lexPatTagZoneStart	fold	matchgroup=lexPatTag	start='{$'	end='^}'	skipnl	skipwhite	contained	contains=lexPatTag,lexPatTagZone,lexPatComment,lexPat,lexPatSep,lexPatInclude
 syn region lexPatComment	fold	start="//"	end="$"		skipnl	contained	contains=cTodo	skipwhite	nextgroup=lexPatComment,lexPat,@Spell
 syn region lexPatComment	fold	start="/\*"	end="\*/"	skipnl	contained	contains=cTodo	skipwhite	nextgroup=lexPatComment,lexPat,@Spell
else
 syn region lexPatTagZoneStart		matchgroup=lexPatTag		start='{'	end='^}'	skipnl	skipwhite	contained	contains=lexPatTag,lexPatTagZone,lexPatComment,lexPat,lexPatSep,lexPatInclude
 syn region lexPatComment		start="//"	end="$"		skipnl	contained	contains=cTodo	skipwhite	nextgroup=lexPatComment,lexPat,@Spell
 syn region lexPatComment		start="/\*"	end="\*/"	skipnl	contained	contains=cTodo	skipwhite	nextgroup=lexPatComment,lexPat,@Spell
endif
syn match  lexPatEnd		"\s*$"				skipnl	contained
syn match  lexPatCodeLine	"[^{\[].*"				contained	contains=@lexCcode,lexCFunctions
syn match  lexMorePat		"\s*|\s*$"			skipnl	contained	nextgroup=lexPat,lexPatTag,lexPatComment
syn match  lexPatSep		"\s\+"					contained	nextgroup=lexMorePat,lexPatCode,lexPatCodeLine
syn match  lexSlashQuote	+\(\\\\\)*\\"+				contained
syn match  lexSlashBrace	+\(\\\\\)*\\\[+				contained
if has("folding")
 syn region lexPatCode		fold	matchgroup=Delimiter	start="{"	end="}"	skipnl	contained	contains=@lexCcode,lexCFunctions
else
 syn region lexPatCode			matchgroup=Delimiter	start="{"	end="}"	skipnl	contained	contains=@lexCcode,lexCFunctions
endif

" User Code Section with final code block
syn region lexFinalCodeBlock	matchgroup=Todo	start="^%%"	end="\%$"	contained	contains=@lexCcode

" Lex macros which may appear in C/C++ code blocks
syn keyword lexCFunctions	BEGIN	ECHO	REJECT	yytext	YYText	yyleng	YYLeng	yymore	yyless	yywrap	yylook
syn keyword lexCFunctions	yyrestart	yyterminate	yylineno	yycolumno	yyin	yyout
syn keyword lexCFunctions	input	unput	output		winput		wunput		woutput
syn keyword lexCFunctions	yyinput	yyunput	yyoutput	yywinput	yywunput	yywoutput

" <c.vim> includes several ALLBUTs; these have to be treated so as to exclude lex* groups
syn cluster cParenGroup		add=lex.*
syn cluster cDefineGroup	add=lex.*
syn cluster cPreProcGroup	add=lex.*
syn cluster cMultiGroup		add=lex.*

" Synchronization
syn sync clear
syn sync minlines=500
syn sync match lexSyncPat	grouphere  lexPatBlock	"^%[a-zA-Z]"
syn sync match lexSyncPat	groupthere lexPatBlock	"^<$"
syn sync match lexSyncPat	groupthere lexPatBlock	"^%%"

" The default highlighting.
if !exists("skip_lex_syntax_inits")
 hi def link lexAbbrvComment	lexPatComment
 hi def link lexAbbrvPat	lexPat
 hi def link lexAbbrv		Special
 hi def link lexBrace		lexPat
 hi def link lexCFunctions	PreProc
 hi def link lexMorePat		Special
 hi def link lexOptions		PreProc
 hi def link lexOptionsEq	Operator
 hi def link lexPatComment	Comment
 hi def link lexPat		Function
 hi def link lexPatString	lexPat
 hi def link lexPatAbbrv	Special
 hi def link lexPatTag		Statement
 hi def link lexPatTagZone	lexPatTag
 hi def link lexSep		Delimiter
 hi def link lexSlashQuote	lexPat
 hi def link lexSlashBrace	lexPat
 hi def link lexStartState	lexPatTag
 hi def link lexStartStateCmd	Special
endif

let b:current_syntax = "lex"

" vim:ts=8
