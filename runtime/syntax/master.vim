" Vim syntax file
" Language:	Focus Master File
" Maintainer:	Rob Brady <robb@datatone.com>
" Last Change:	$Date: 2004/06/13 15:54:03 $
" URL: http://www.datatone.com/~robb/vim/syntax/master.vim
" $Revision: 1.1 $

" this is a very simple syntax file - I will be improving it
" add entire DEFINE syntax

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn case match

" A bunch of useful keywords
syn keyword masterKeyword	FILENAME SUFFIX SEGNAME SEGTYPE PARENT FIELDNAME
syn keyword masterKeyword	FIELD ALIAS USAGE INDEX MISSING ON
syn keyword masterKeyword	FORMAT CRFILE CRKEY
syn keyword masterDefine	DEFINE DECODE EDIT
syn region  masterString	start=+"+  end=+"+
syn region  masterString	start=+'+  end=+'+
syn match   masterComment	"\$.*"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_master_syntax_inits")
  if version < 508
    let did_master_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink masterKeyword Keyword
  HiLink masterComment Comment
  HiLink masterString  String

  delcommand HiLink
endif

let b:current_syntax = "master"

" vim: ts=8
