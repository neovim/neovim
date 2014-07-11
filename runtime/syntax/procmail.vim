" Vim syntax file
" Language:	Procmail definition file
" Maintainer:	Melchior FRANZ <mfranz@aon.at>
" Last Change:	2003 Aug 14
" Author:	Sonia Heimann

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn match   procmailComment      "#.*$" contains=procmailTodo
syn keyword   procmailTodo      contained Todo TBD

syn region  procmailString       start=+"+  skip=+\\"+  end=+"+
syn region  procmailString       start=+'+  skip=+\\'+  end=+'+

syn region procmailVarDeclRegion start="^\s*[a-zA-Z0-9_]\+\s*="hs=e-1 skip=+\\$+ end=+$+ contains=procmailVar,procmailVarDecl,procmailString
syn match procmailVarDecl contained "^\s*[a-zA-Z0-9_]\+"
syn match procmailVar "$[a-zA-Z0-9_]\+"

syn match procmailCondition contained "^\s*\*.*"

syn match procmailActionFolder contained "^\s*[-_a-zA-Z0-9/]\+"
syn match procmailActionVariable contained "^\s*$[a-zA-Z_]\+"
syn region procmailActionForward start=+^\s*!+ skip=+\\$+ end=+$+
syn region procmailActionPipe start=+^\s*|+ skip=+\\$+ end=+$+
syn region procmailActionNested start=+^\s*{+ end=+^\s*}+ contains=procmailRecipe,procmailComment,procmailVarDeclRegion

syn region procmailRecipe start=+^\s*:.*$+ end=+^\s*\($\|}\)+me=e-1 contains=procmailComment,procmailCondition,procmailActionFolder,procmailActionVariable,procmailActionForward,procmailActionPipe,procmailActionNested,procmailVarDeclRegion

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_procmail_syntax_inits")
  if version < 508
    let did_procmail_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink procmailComment Comment
  HiLink procmailTodo    Todo

  HiLink procmailRecipe   Statement
  "HiLink procmailCondition   Statement

  HiLink procmailActionFolder	procmailAction
  HiLink procmailActionVariable procmailAction
  HiLink procmailActionForward	procmailAction
  HiLink procmailActionPipe	procmailAction
  HiLink procmailAction		Function
  HiLink procmailVar		Identifier
  HiLink procmailVarDecl	Identifier

  HiLink procmailString String

  delcommand HiLink
endif

let b:current_syntax = "procmail"

" vim: ts=8
