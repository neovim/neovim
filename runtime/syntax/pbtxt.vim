" Vim syntax file
" Language:             Protobuf Text Format
" Maintainer:           Lakshay Garg <lakshayg@outlook.in>
" Last Change:          2020 Nov 17
" Homepage:             https://github.com/lakshayg/vim-pbtxt

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn case ignore

syn keyword pbtxtTodo     TODO FIXME contained
syn keyword pbtxtBool     true false contained

syn match   pbtxtInt      display   "\<\(0\|[1-9]\d*\)\>"
syn match   pbtxtHex      display   "\<0[xX]\x\+\>"
syn match   pbtxtFloat    display   "\(0\|[1-9]\d*\)\=\.\d*"
syn match   pbtxtMessage  display   "^\s*\w\+\s*{"me=e-1
syn match   pbtxtField    display   "^\s*\w\+:"me=e-1
syn match   pbtxtEnum     display   ":\s*\a\w\+"ms=s+1   contains=pbtxtBool
syn region  pbtxtString   start=+"+ skip=+\\"+ end=+"+   contains=@Spell
syn region  pbtxtComment  start="#" end="$"      keepend contains=pbtxtTodo,@Spell

hi def link pbtxtTodo     Todo
hi def link pbtxtBool     Boolean
hi def link pbtxtInt      Number
hi def link pbtxtHex      Number
hi def link pbtxtFloat    Float
hi def link pbtxtMessage  Structure
hi def link pbtxtField    Identifier
hi def link pbtxtEnum     Define
hi def link pbtxtString   String
hi def link pbtxtComment  Comment

let b:current_syntax = "pbtxt"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet
