" Vim syntax file
" Language:         RFC 2614 - An API for Service Location SPI file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword slpspiTodo          contained TODO FIXME XXX NOTE

syn region  slpspiComment       display oneline start='^[#;]' end='$'
                                \ contains=slpspiTodo,@Spell

syn match   slpspiBegin         display '^'
                                \ nextgroup=slpspiKeyType,
                                \ slpspiComment skipwhite

syn keyword slpspiKeyType       contained PRIVATE PUBLIC
                                \ nextgroup=slpspiString skipwhite

syn match   slpspiString        contained '\S\+'
                                \ nextgroup=slpspiKeyFile skipwhite

syn match   slpspiKeyFile       contained '\S\+'

hi def link slpspiTodo          Todo
hi def link slpspiComment       Comment
hi def link slpspiKeyType       Type
hi def link slpspiString        Identifier
hi def link slpspiKeyFile       String

let b:current_syntax = "slpspi"

let &cpo = s:cpo_save
unlet s:cpo_save
