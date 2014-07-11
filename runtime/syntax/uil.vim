" Vim syntax file
" Language:	Motif UIL (User Interface Language)
" Maintainer:	Thomas Koehler <jean-luc@picard.franken.de>
" Last Change:	2013 May 23
" URL:		http://gott-gehabt.de/800_wer_wir_sind/thomas/Homepage/Computer/vim/syntax/uil.vim

" Quit when a syntax file was already loaded
if version < 600
   syntax clear
elseif exists("b:current_syntax")
  finish
endif

" A bunch of useful keywords
syn keyword uilType	arguments	callbacks	color
syn keyword uilType	compound_string	controls	end
syn keyword uilType	exported	file		include
syn keyword uilType	module		object		procedure
syn keyword uilType	user_defined	xbitmapfile

syn keyword uilTodo contained	TODO

" String and Character constants
" Highlight special characters (those which have a backslash) differently
syn match   uilSpecial contained "\\\d\d\d\|\\."
syn region  uilString		start=+"+  skip=+\\\\\|\\"+  end=+"+  contains=@Spell,uilSpecial
syn match   uilCharacter	"'[^\\]'"
syn region  uilString		start=+'+  skip=+\\\\\|\\'+  end=+'+  contains=@Spell,uilSpecial
syn match   uilSpecialCharacter	"'\\.'"
syn match   uilSpecialStatement	"Xm[^	 =(){}:;]*"
syn match   uilSpecialFunction	"MrmNcreateCallback"
syn match   uilRessource	"XmN[^	 =(){}:;]*"

syn match  uilNumber		"-\=\<\d*\.\=\d\+\(e\=f\=\|[uU]\=[lL]\=\)\>"
syn match  uilNumber		"0[xX]\x\+\>"

syn region uilComment		start="/\*"  end="\*/" contains=@Spell,uilTodo
syn match  uilComment		"!.*" contains=@Spell,uilTodo
syn match  uilCommentError	"\*/"

syn region uilPreCondit		start="^#\s*\(if\>\|ifdef\>\|ifndef\>\|elif\>\|else\>\|endif\>\)"  skip="\\$"  end="$" contains=uilComment,uilString,uilCharacter,uilNumber,uilCommentError
syn match  uilIncluded contained "<[^>]*>"
syn match  uilInclude		"^#\s*include\s\+." contains=uilString,uilIncluded
syn match  uilLineSkip		"\\$"
syn region uilDefine		start="^#\s*\(define\>\|undef\>\)" end="$" contains=uilLineSkip,uilComment,uilString,uilCharacter,uilNumber,uilCommentError

syn sync ccomment uilComment

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_uil_syn_inits")
  if version < 508
    let did_uil_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  " The default highlighting.
  HiLink uilCharacter		uilString
  HiLink uilSpecialCharacter	uilSpecial
  HiLink uilNumber		uilString
  HiLink uilCommentError	uilError
  HiLink uilInclude		uilPreCondit
  HiLink uilDefine		uilPreCondit
  HiLink uilIncluded		uilString
  HiLink uilSpecialFunction	uilRessource
  HiLink uilRessource		Identifier
  HiLink uilSpecialStatement	Keyword
  HiLink uilError		Error
  HiLink uilPreCondit		PreCondit
  HiLink uilType		Type
  HiLink uilString		String
  HiLink uilComment		Comment
  HiLink uilSpecial		Special
  HiLink uilTodo		Todo

  delcommand HiLink
endif


let b:current_syntax = "uil"

" vim: ts=8
