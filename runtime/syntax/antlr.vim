" Vim syntax file
" Antlr:	ANTLR, Another Tool For Language Recognition <www.antlr.org>
" Maintainer:	Mathieu Clabaut <mathieu.clabaut@free.fr>
" LastChange:	02 May 2001
" Original:	Comes from JavaCC.vim

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
   syntax clear
elseif exists("b:current_syntax")
   finish
endif

" This syntac file is a first attempt. It is far from perfect...

" Uses java.vim, and adds a few special things for JavaCC Parser files.
" Those files usually have the extension  *.jj

" source the java.vim file
if version < 600
   so <sfile>:p:h/java.vim
else
   runtime! syntax/java.vim
   unlet b:current_syntax
endif

"remove catching errors caused by wrong parenthesis (does not work in antlr
"files) (first define them in case they have not been defined in java)
syn match	javaParen "--"
syn match	javaParenError "--"
syn match	javaInParen "--"
syn match	javaError2 "--"
syn clear	javaParen
syn clear	javaParenError
syn clear	javaInParen
syn clear	javaError2

" remove function definitions (they look different) (first define in
" in case it was not defined in java.vim)
"syn match javaFuncDef "--"
"syn clear javaFuncDef
"syn match javaFuncDef "[a-zA-Z][a-zA-Z0-9_. \[\]]*([^-+*/()]*)[ \t]*:" contains=javaType
" syn region javaFuncDef start=+t[a-zA-Z][a-zA-Z0-9_. \[\]]*([^-+*/()]*,[ 	]*+ end=+)[ \t]*:+

syn keyword antlrPackages options language buildAST
syn match antlrPackages "PARSER_END([^)]*)"
syn match antlrPackages "PARSER_BEGIN([^)]*)"
syn match antlrSpecToken "<EOF>"
" the dot is necessary as otherwise it will be matched as a keyword.
syn match antlrSpecToken ".LOOKAHEAD("ms=s+1,me=e-1
syn match antlrSep "[|:]\|\.\."
syn keyword antlrActionToken TOKEN SKIP MORE SPECIAL_TOKEN
syn keyword antlrError DEBUG IGNORE_IN_BNF

if version >= 508 || !exists("did_antlr_syntax_inits")
   if version < 508
      let did_antlr_syntax_inits = 1
      command -nargs=+ HiLink hi link <args>
   else
      command -nargs=+ HiLink hi def link <args>
   endif
   HiLink antlrSep Statement
   HiLink antlrPackages Statement
  delcommand HiLink
endif

let b:current_syntax = "antlr"

" vim: ts=8
