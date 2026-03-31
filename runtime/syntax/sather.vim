" Vim syntax file
" Language:	Sather/pSather
" Maintainer:	Claudio Fleiner <claudio@fleiner.com>
" URL:		http://www.fleiner.com/vim/syntax/sather.vim
" Last Change:	2003 May 11

" Sather is a OO-language developed at the International Computer Science
" Institute (ICSI) in Berkeley, CA. pSather is a parallel extension to Sather.
" Homepage: http://www.icsi.berkeley.edu/~sather
" Sather files use .sa as suffix

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" keyword definitions
syn keyword satherExternal	 extern
syn keyword satherBranch	 break continue
syn keyword satherLabel		 when then
syn keyword satherConditional	 if else elsif end case typecase assert with
syn match satherConditional	 "near$"
syn match satherConditional	 "far$"
syn match satherConditional	 "near *[^(]"he=e-1
syn match satherConditional	 "far *[^(]"he=e-1
syn keyword satherSynchronize	 lock guard sync
syn keyword satherRepeat	 loop parloop do
syn match satherRepeat		 "while!"
syn match satherRepeat		 "break!"
syn match satherRepeat		 "until!"
syn keyword satherBoolValue	 true false
syn keyword satherValue		 self here cluster
syn keyword satherOperator	 new "== != & ^ | && ||
syn keyword satherOperator	 and or not
syn match satherOperator	 "[#!]"
syn match satherOperator	 ":-"
syn keyword satherType		 void attr where
syn match satherType	       "near *("he=e-1
syn match satherType	       "far *("he=e-1
syn keyword satherStatement	 return
syn keyword satherStorageClass	 static const
syn keyword satherExceptions	 try raise catch
syn keyword satherMethodDecl	 is pre post
syn keyword satherClassDecl	 abstract value class include
syn keyword satherScopeDecl	 public private readonly


syn match   satherSpecial	    contained "\\\d\d\d\|\\."
syn region  satherString	    start=+"+  skip=+\\\\\|\\"+  end=+"+  contains=satherSpecial
syn match   satherCharacter	    "'[^\\]'"
syn match   satherSpecialCharacter  "'\\.'"
syn match   satherNumber	  "-\=\<\d\+L\=\>\|0[xX][0-9a-fA-F]\+\>"
syn match   satherCommentSkip	  contained "^\s*\*\($\|\s\+\)"
syn region  satherComment2String  contained start=+"+  skip=+\\\\\|\\"+  end=+$\|"+  contains=satherSpecial
syn match   satherComment	  "--.*" contains=satherComment2String,satherCharacter,satherNumber


syn sync ccomment satherComment

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link satherBranch		satherStatement
hi def link satherLabel		satherStatement
hi def link satherConditional	satherStatement
hi def link satherSynchronize	satherStatement
hi def link satherRepeat		satherStatement
hi def link satherExceptions	satherStatement
hi def link satherStorageClass	satherDeclarative
hi def link satherMethodDecl	satherDeclarative
hi def link satherClassDecl	satherDeclarative
hi def link satherScopeDecl	satherDeclarative
hi def link satherBoolValue	satherValue
hi def link satherSpecial		satherValue
hi def link satherString		satherValue
hi def link satherCharacter	satherValue
hi def link satherSpecialCharacter satherValue
hi def link satherNumber		satherValue
hi def link satherStatement	Statement
hi def link satherOperator		Statement
hi def link satherComment		Comment
hi def link satherType		Type
hi def link satherValue		String
hi def link satherString		String
hi def link satherSpecial		String
hi def link satherCharacter	String
hi def link satherDeclarative	Type
hi def link satherExternal		PreCondit

let b:current_syntax = "sather"

" vim: ts=8
