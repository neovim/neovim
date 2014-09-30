" Vim syntax file
" Language:         CRM114
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword crmTodo       contained TODO FIXME XXX NOTE

syn region  crmComment    display oneline start='#' end='\\#'
                          \ contains=crmTodo,@Spell

syn match   crmVariable   display ':[*#@]:[^:]\{-1,}:'

syn match   crmSpecial    display '\\\%(x\x\x\|o\o\o\o\|[]nrtabvf0>)};/\\]\)'

syn keyword crmStatement  insert noop accept alius alter classify eval exit
syn keyword crmStatement  fail fault goto hash intersect isolate input learn
syn keyword crmStatement  liaf match output syscall trap union window

syn region  crmRegex      start='/' skip='\\/' end='/' contains=crmVariable

syn match   crmLabel      display '^\s*:[[:graph:]]\+:'

hi def link crmTodo       Todo
hi def link crmComment    Comment
hi def link crmVariable   Identifier
hi def link crmSpecial    SpecialChar
hi def link crmStatement  Statement
hi def link crmRegex      String
hi def link crmLabel      Label

let b:current_syntax = "crm"

let &cpo = s:cpo_save
unlet s:cpo_save
