" Vim syntax file
" Language:	Sather/pSather
" Maintainer:	Claudio Fleiner <claudio@fleiner.com>
" URL:		http://www.fleiner.com/vim/syntax/sather.vim
" Last Change:	2003 May 11

" Sather is a OO-language developped at the International Computer Science
" Institute (ICSI) in Berkeley, CA. pSather is a parallel extension to Sather.
" Homepage: http://www.icsi.berkeley.edu/~sather
" Sather files use .sa as suffix

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
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
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_sather_syn_inits")
  if version < 508
    let did_sather_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink satherBranch		satherStatement
  HiLink satherLabel		satherStatement
  HiLink satherConditional	satherStatement
  HiLink satherSynchronize	satherStatement
  HiLink satherRepeat		satherStatement
  HiLink satherExceptions	satherStatement
  HiLink satherStorageClass	satherDeclarative
  HiLink satherMethodDecl	satherDeclarative
  HiLink satherClassDecl	satherDeclarative
  HiLink satherScopeDecl	satherDeclarative
  HiLink satherBoolValue	satherValue
  HiLink satherSpecial		satherValue
  HiLink satherString		satherValue
  HiLink satherCharacter	satherValue
  HiLink satherSpecialCharacter satherValue
  HiLink satherNumber		satherValue
  HiLink satherStatement	Statement
  HiLink satherOperator		Statement
  HiLink satherComment		Comment
  HiLink satherType		Type
  HiLink satherValue		String
  HiLink satherString		String
  HiLink satherSpecial		String
  HiLink satherCharacter	String
  HiLink satherDeclarative	Type
  HiLink satherExternal		PreCondit
  delcommand HiLink
endif

let b:current_syntax = "sather"

" vim: ts=8
