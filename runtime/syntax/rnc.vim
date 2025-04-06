" Vim syntax file
" Language:             Relax NG compact syntax
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2007-06-17

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

setlocal iskeyword+=-,.

syn keyword rncTodo         contained TODO FIXME XXX NOTE

syn region  rncComment      display oneline start='^\s*#' end='$'
                            \ contains=rncTodo,@Spell

syn match   rncOperator     display '[-|,&+?*~]'
syn match   rncOperator     display '\%(|&\)\=='
syn match   rncOperator     display '>>'

syn match   rncNamespace    display '\<\k\+:'

syn match   rncQuoted       display '\\\k\+\>'

syn match   rncSpecial      display '\\x{\x\+}'

syn region rncAnnotation    transparent start='\[' end='\]'
                            \ contains=ALLBUT,rncComment,rncTodo

syn region  rncLiteral      display oneline start=+"+ end=+"+
                            \ contains=rncSpecial
syn region  rncLiteral      display oneline start=+'+ end=+'+
syn region  rncLiteral      display oneline start=+"""+ end=+"""+
                            \ contains=rncSpecial
syn region  rncLiteral      display oneline start=+'''+ end=+'''+

syn match   rncDelimiter    display '[{},()]'

syn keyword rncKeyword      datatypes default div empty external grammar
syn keyword rncKeyword      include inherit list mixed name namespace
syn keyword rncKeyword      notAllowed parent start string text token

syn match   rncIdentifier   display '\k\+\_s*\%(=\|&=\||=\)\@='
                            \ nextgroup=rncOperator
syn keyword rncKeyword      element attribute
                            \ nextgroup=rncIdName skipwhite skipempty
syn match   rncIdName       contained '\k\+'

hi def link rncTodo         Todo
hi def link rncComment      Comment
hi def link rncOperator     Operator
hi def link rncNamespace    Identifier
hi def link rncQuoted       Special
hi def link rncSpecial      SpecialChar
hi def link rncAnnotation   Special
hi def link rncLiteral      String
hi def link rncDelimiter    Delimiter
hi def link rncKeyword      Keyword
hi def link rncIdentifier   Identifier
hi def link rncIdName       Identifier

let b:current_syntax = "rnc"

let &cpo = s:cpo_save
unlet s:cpo_save
