" Vim syntax file
" Language:	JavaCC, a Java Compiler Compiler written by JavaSoft
" Maintainer:	Claudio Fleiner <claudio@fleiner.com>
" URL:		http://www.fleiner.com/vim/syntax/javacc.vim
" Last Change:	2012 Oct 05

" Uses java.vim, and adds a few special things for JavaCC Parser files.
" Those files usually have the extension  *.jj

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" source the java.vim file
if version < 600
  source <sfile>:p:h/java.vim
else
  runtime! syntax/java.vim
endif
unlet b:current_syntax

"remove catching errors caused by wrong parenthesis (does not work in javacc
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
syn clear javaFuncDef
syn match javaFuncDef "[$_a-zA-Z][$_a-zA-Z0-9_. \[\]]*([^-+*/()]*)[ \t]*:" contains=javaType

syn keyword javaccPackages options DEBUG_PARSER DEBUG_LOOKAHEAD DEBUG_TOKEN_MANAGER
syn keyword javaccPackages COMMON_TOKEN_ACTION IGNORE_CASE CHOICE_AMBIGUITY_CHECK
syn keyword javaccPackages OTHER_AMBIGUITY_CHECK STATIC LOOKAHEAD ERROR_REPORTING
syn keyword javaccPackages USER_TOKEN_MANAGER  USER_CHAR_STREAM JAVA_UNICODE_ESCAPE
syn keyword javaccPackages UNICODE_INPUT JDK_VERSION
syn match javaccPackages "PARSER_END([^)]*)"
syn match javaccPackages "PARSER_BEGIN([^)]*)"
syn match javaccSpecToken "<EOF>"
" the dot is necessary as otherwise it will be matched as a keyword.
syn match javaccSpecToken ".LOOKAHEAD("ms=s+1,me=e-1
syn match javaccToken "<[^> \t]*>"
syn keyword javaccActionToken TOKEN SKIP MORE SPECIAL_TOKEN
syn keyword javaccError DEBUG IGNORE_IN_BNF

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_css_syn_inits")
  if version < 508
    let did_css_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif
  HiLink javaccSpecToken Statement
  HiLink javaccActionToken Type
  HiLink javaccPackages javaScopeDecl
  HiLink javaccToken String
  HiLink javaccError Error
  delcommand HiLink
endif

let b:current_syntax = "javacc"
let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8
