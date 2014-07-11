" Vim syntax file
" Language:     Blank 1.4.1
" Maintainer:   Rafal M. Sulejman <unefunge@friko2.onet.pl>
" Last change:  2011 Dec 28 by Thilo Six

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
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
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_blank_syntax_inits")
  if version < 508
    let did_blank_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink blankInstruction      Statement
  HiLink blankNumber	       Number
  HiLink blankString	       String

  delcommand HiLink
endif

let b:current_syntax = "blank"

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: ts=8
