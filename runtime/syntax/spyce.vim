" Vim syntax file
" Language:	   SPYCE
" Maintainer:	 Rimon Barr <rimon AT acm DOT org>
" URL:		     http://spyce.sourceforge.net
" Last Change: 2009 Nov 11

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" we define it here so that included files can test for it
if !exists("main_syntax")
  let main_syntax='spyce'
endif

" Read the HTML syntax to start with
let b:did_indent = 1	     " don't perform HTML indentation!
let html_no_rendering = 1    " do not render <b>,<i>, etc...
runtime! syntax/html.vim
unlet b:current_syntax
syntax spell default  " added by Bram

" include python
syn include @Python <sfile>:p:h/python.vim
syn include @Html <sfile>:p:h/html.vim

" spyce definitions
syn keyword spyceDirectiveKeyword include compact module import contained
syn keyword spyceDirectiveArg name names file contained
syn region  spyceDirectiveString start=+"+ end=+"+ contained
syn match   spyceDirectiveValue "=[\t ]*[^'", \t>][^, \t>]*"hs=s+1 contained

syn match spyceBeginErrorS  ,\[\[,
syn match spyceBeginErrorA  ,<%,
syn cluster spyceBeginError contains=spyceBeginErrorS,spyceBeginErrorA
syn match spyceEndErrorS    ,\]\],
syn match spyceEndErrorA    ,%>,
syn cluster spyceEndError contains=spyceEndErrorS,spyceEndErrorA

syn match spyceEscBeginS       ,\\\[\[,
syn match spyceEscBeginA       ,\\<%,
syn cluster spyceEscBegin contains=spyceEscBeginS,spyceEscBeginA
syn match spyceEscEndS	       ,\\\]\],
syn match spyceEscEndA	       ,\\%>,
syn cluster spyceEscEnd contains=spyceEscEndS,spyceEscEndA
syn match spyceEscEndCommentS  ,--\\\]\],
syn match spyceEscEndCommentA  ,--\\%>,
syn cluster spyceEscEndComment contains=spyceEscEndCommentS,spyceEscEndCommentA

syn region spyceStmtS      matchgroup=spyceStmtDelim start=,\[\[, end=,\]\], contains=@Python,spyceLambdaS,spyceLambdaA,spyceBeginError keepend
syn region spyceStmtA      matchgroup=spyceStmtDelim start=,<%, end=,%>, contains=@Python,spyceLambdaS,spyceLambdaA,spyceBeginError keepend
syn region spyceChunkS     matchgroup=spyceChunkDelim start=,\[\[\\, end=,\]\], contains=@Python,spyceLambdaS,spyceLambdaA,spyceBeginError keepend
syn region spyceChunkA     matchgroup=spyceChunkDelim start=,<%\\, end=,%>, contains=@Python,spyceLambdaS,spyceLambdaA,spyceBeginError keepend
syn region spyceEvalS      matchgroup=spyceEvalDelim start=,\[\[=, end=,\]\], contains=@Python,spyceLambdaS,spyceLambdaA,spyceBeginError keepend
syn region spyceEvalA      matchgroup=spyceEvalDelim start=,<%=, end=,%>, contains=@Python,spyceLambdaS,spyceLambdaA,spyceBeginError keepend
syn region spyceDirectiveS matchgroup=spyceDelim start=,\[\[\., end=,\]\], contains=spyceBeginError,spyceDirectiveKeyword,spyceDirectiveArg,spyceDirectiveValue,spyceDirectiveString keepend
syn region spyceDirectiveA matchgroup=spyceDelim start=,<%@, end=,%>, contains=spyceBeginError,spyceDirectiveKeyword,spyceDirectiveArg,spyceDirectiveValue,spyceDirectiveString keepend
syn region spyceCommentS   matchgroup=spyceCommentDelim start=,\[\[--, end=,--\]\],
syn region spyceCommentA   matchgroup=spyceCommentDelim start=,<%--, end=,--%>,
syn region spyceLambdaS    matchgroup=spyceLambdaDelim start=,\[\[spy!\?, end=,\]\], contains=@Html,@spyce extend
syn region spyceLambdaA    matchgroup=spyceLambdaDelim start=,<%spy!\?, end=,%>, contains=@Html,@spyce extend

syn cluster spyce contains=spyceStmtS,spyceStmtA,spyceChunkS,spyceChunkA,spyceEvalS,spyceEvalA,spyceCommentS,spyceCommentA,spyceDirectiveS,spyceDirectiveA

syn cluster htmlPreproc contains=@spyce

hi link spyceDirectiveKeyword	Special
hi link spyceDirectiveArg	Type
hi link spyceDirectiveString	String
hi link spyceDirectiveValue	String

hi link spyceDelim		Special
hi link spyceStmtDelim		spyceDelim
hi link spyceChunkDelim		spyceDelim
hi link spyceEvalDelim		spyceDelim
hi link spyceLambdaDelim	spyceDelim
hi link spyceCommentDelim	Comment

hi link spyceBeginErrorS	Error
hi link spyceBeginErrorA	Error
hi link spyceEndErrorS		Error
hi link spyceEndErrorA		Error

hi link spyceStmtS		spyce
hi link spyceStmtA		spyce
hi link spyceChunkS		spyce
hi link spyceChunkA		spyce
hi link spyceEvalS		spyce
hi link spyceEvalA		spyce
hi link spyceDirectiveS		spyce
hi link spyceDirectiveA		spyce
hi link spyceCommentS		Comment
hi link spyceCommentA		Comment
hi link spyceLambdaS		Normal
hi link spyceLambdaA		Normal

hi link spyce			Statement

let b:current_syntax = "spyce"
if main_syntax == 'spyce'
  unlet main_syntax
endif

