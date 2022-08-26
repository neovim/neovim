" Vim syntax file
" Language:	kscript
" Maintainer:	Thomas Capricelli <orzel@yalbi.com>
" URL:		http://aquila.rezel.enst.fr/thomas/vim/kscript.vim
" CVS:		$Id: kscript.vim,v 1.1 2004/06/13 17:40:02 vimboss Exp $

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn keyword	kscriptPreCondit	import from

syn keyword	kscriptHardCoded	print println connect length arg mid upper lower isEmpty toInt toFloat findApplication
syn keyword	kscriptConditional	if else switch
syn keyword	kscriptRepeat		while for do foreach
syn keyword	kscriptExceptions	emit catch raise try signal
syn keyword	kscriptFunction		class struct enum
syn keyword	kscriptConst		FALSE TRUE false true
syn keyword	kscriptStatement	return delete
syn keyword	kscriptLabel		case default
syn keyword	kscriptStorageClass	const
syn keyword	kscriptType		in out inout var

syn keyword	kscriptTodo		contained TODO FIXME XXX

syn region	kscriptComment		start="/\*" end="\*/" contains=kscriptTodo
syn match	kscriptComment		"//.*" contains=kscriptTodo
syn match	kscriptComment		"#.*$" contains=kscriptTodo

syn region	kscriptString		start=+'+  end=+'+ skip=+\\\\\|\\'+
syn region	kscriptString		start=+"+  end=+"+ skip=+\\\\\|\\"+
syn region	kscriptString		start=+"""+  end=+"""+
syn region	kscriptString		start=+'''+  end=+'''+

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link kscriptConditional		Conditional
hi def link kscriptRepeat			Repeat
hi def link kscriptExceptions		Statement
hi def link kscriptFunction		Function
hi def link kscriptConst			Constant
hi def link kscriptStatement		Statement
hi def link kscriptLabel			Label
hi def link kscriptStorageClass		StorageClass
hi def link kscriptType			Type
hi def link kscriptTodo			Todo
hi def link kscriptComment		Comment
hi def link kscriptString			String
hi def link kscriptPreCondit		PreCondit
hi def link kscriptHardCoded		Statement


let b:current_syntax = "kscript"

" vim: ts=8
