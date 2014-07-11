" Vim syntax file
" Language:	GDMO
"		(ISO-10165-4; Guidelines for the Definition of Managed Object)
" Maintainer:	Gyuman (Chester) Kim <violkim@gmail.com>
" URL:		http://classicalprogrammer.wikidot.com/local--files/vim-syntax-file-for-gdmo/gdmo.vim
" Last change:	8th June, 2011

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" keyword definitions
syn match   gdmoCategory      "MANAGED\s\+OBJECT\s\+CLASS"
syn keyword gdmoCategory      NOTIFICATION ATTRIBUTE BEHAVIOUR PACKAGE ACTION
syn match   gdmoCategory      "NAME\s\+BINDING"
syn match   gdmoRelationship  "DERIVED\s\+FROM"
syn match   gdmoRelationship  "SUPERIOR\s\+OBJECT\s\+CLASS"
syn match   gdmoRelationship  "SUBORDINATE\s\+OBJECT\s\+CLASS"
syn match   gdmoExtension     "AND\s\+SUBCLASSES"
syn match   gdmoDefinition    "DEFINED\s\+AS"
syn match   gdmoDefinition    "REGISTERED\s\+AS"
syn match   gdmoExtension     "ORDER\s\+BY"
syn match   gdmoReference     "WITH\s\+ATTRIBUTE"
syn match   gdmoReference     "WITH\s\+INFORMATION\s\+SYNTAX"
syn match   gdmoReference     "WITH\s\+REPLY\s\+SYNTAX"
syn match   gdmoReference     "WITH\s\+ATTRIBUTE\s\+SYNTAX"
syn match   gdmoExtension     "AND\s\+ATTRIBUTE\s\+IDS"
syn match   gdmoExtension     "MATCHES\s\+FOR"
syn match   gdmoReference     "CHARACTERIZED\s\+BY"
syn match   gdmoReference     "CONDITIONAL\s\+PACKAGES"
syn match   gdmoExtension     "PRESENT\s\+IF"
syn match   gdmoExtension     "DEFAULT\s\+VALUE"
syn match   gdmoExtension     "PERMITTED\s\+VALUES"
syn match   gdmoExtension     "REQUIRED\s\+VALUES"
syn match   gdmoExtension     "NAMED\s\+BY"
syn keyword gdmoReference     ATTRIBUTES NOTIFICATIONS ACTIONS
syn keyword gdmoExtension     DELETE CREATE
syn keyword gdmoExtension     EQUALITY SUBSTRINGS ORDERING
syn match   gdmoExtension     "REPLACE-WITH-DEFAULT"
syn match   gdmoExtension     "GET"
syn match   gdmoExtension     "GET-REPLACE"
syn match   gdmoExtension     "ADD-REMOVE"
syn match   gdmoExtension     "WITH-REFERENCE-OBJECT"
syn match   gdmoExtension     "WITH-AUTOMATIC-INSTANCE-NAMING"
syn match   gdmoExtension     "ONLY-IF-NO-CONTAINED-OBJECTS"


" Strings and constants
syn match   gdmoSpecial		contained "\\\d\d\d\|\\."
syn region  gdmoString		start=+"+  skip=+\\\\\|\\"+  end=+"+  contains=gdmoSpecial
syn match   gdmoCharacter	  "'[^\\]'"
syn match   gdmoSpecialCharacter  "'\\.'"
syn match   gdmoNumber		  "0[xX][0-9a-fA-F]\+\>"
syn match   gdmoLineComment       "--.*"
syn match   gdmoLineComment       "--.*--"

syn match gdmoDefinition "^\s*[a-zA-Z][-a-zA-Z0-9_.\[\] \t{}]* *::="me=e-3
syn match gdmoBraces     "[{}]"

syn sync ccomment gdmoComment

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_gdmo_syntax_inits")
  if version < 508
    let did_gdmo_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink gdmoCategory	      Structure
  HiLink gdmoRelationship     Macro
  HiLink gdmoDefinition       Statement
  HiLink gdmoReference	      Type
  HiLink gdmoExtension	      Operator
  HiLink gdmoBraces	      Function
  HiLink gdmoSpecial	      Special
  HiLink gdmoString	      String
  HiLink gdmoCharacter	      Character
  HiLink gdmoSpecialCharacter gdmoSpecial
  HiLink gdmoComment	      Comment
  HiLink gdmoLineComment      gdmoComment
  HiLink gdmoType	      Type

  delcommand HiLink
endif

let b:current_syntax = "gdmo"

" vim: ts=8
