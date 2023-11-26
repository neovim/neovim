" Vim syntax file
" Language:             netrc(5) configuration file
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2010-01-03
" Last Change:		2023 Feb 27 by Keith Smiley

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword netrcKeyword    machine nextgroup=netrcMachine skipwhite skipnl
syn keyword netrcKeyword    account
                          \ login
                          \ nextgroup=netrcLogin,netrcSpecial skipwhite skipnl
syn keyword netrcKeyword    password nextgroup=netrcPassword skipwhite skipnl
syn keyword netrcKeyword    default
syn keyword netrcKeyword    macdef
                          \ nextgroup=netrcInit,netrcMacroName skipwhite skipnl
syn region  netrcMacro      contained start='.' end='^$'

syn match   netrcMachine    contained display '\S\+'
syn match   netrcMachine    contained display '"[^\\"]*\(\\.[^\\"]*\)*"'
syn match   netrcLogin      contained display '\S\+'
syn match   netrcLogin      contained display '"[^\\"]*\(\\.[^\\"]*\)*"'
syn match   netrcPassword   contained display '\S\+'
syn match   netrcPassword   contained display '"[^\\"]*\(\\.[^\\"]*\)*"'
syn match   netrcMacroName  contained display '\S\+'
                          \ nextgroup=netrcMacro skipwhite skipnl
syn match   netrcMacroName  contained display '"[^\\"]*\(\\.[^\\"]*\)*"'
                          \ nextgroup=netrcMacro skipwhite skipnl

syn keyword netrcSpecial    contained anonymous
syn match   netrcInit       contained '\<init$'
                          \ nextgroup=netrcMacro skipwhite skipnl

syn match   netrcComment    '#.*$'

syn sync fromstart

hi def link netrcKeyword    Keyword
hi def link netrcMacro      PreProc
hi def link netrcMachine    Identifier
hi def link netrcLogin      String
hi def link netrcPassword   String
hi def link netrcMacroName  String
hi def link netrcSpecial    Special
hi def link netrcInit       Special
hi def link netrcComment    Comment

let b:current_syntax = "netrc"

let &cpo = s:cpo_save
unlet s:cpo_save
