" Vim syntax file
" Language:	    XBL 1.0
" Maintainer:	    Doug Kearns <dougkearns@gmail.com>
" Latest Revision:  2007 November 5

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

runtime! syntax/xml.vim
unlet b:current_syntax

syn include @javascriptTop syntax/javascript.vim
unlet b:current_syntax

syn region xblJavascript
	\ matchgroup=xmlCdataStart start=+<!\[CDATA\[+
	\ matchgroup=xmlCdataEnd end=+]]>+
	\ contains=@javascriptTop keepend extend

let b:current_syntax = "xbl"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8
