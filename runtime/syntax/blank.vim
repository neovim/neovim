" Vim syntax file
" Language:     Blank 1.4.1
" Maintainer:   Rafal M. Sulejman <unefunge@friko2.onet.pl>
" Last change:  2011 Dec 28 by Thilo Six

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn case ignore

" Blank instructions
syn match blankInstruction "{[:;,\.+\-*$#@/\\`'"!\|><{}\[\]()?xspo\^&\~=_%]}"

" Common strings
syn match blankString "\~[^}]"

" Numbers
syn match blankNumber "\[[0-9]\+\]"

syn case match

" Define the default highlighting.
" Only when an item doesn't have highlighting yet
command -nargs=+ HiLink hi def link <args>

HiLink blankInstruction      Statement
HiLink blankNumber	       Number
HiLink blankString	       String

delcommand HiLink

let b:current_syntax = "blank"

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: ts=8
