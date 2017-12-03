" Vim syntax file
" Language: FreeBSD send-pr file
" Maintainer: Hendrik Scholz <hendrik@scholz.net>
" Last Change: 2012 Feb 03
"
" http://raisdorf.net/files/misc/send-pr.vim

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn match sendprComment /^SEND-PR:/
" email address
syn match sendprType /<[a-zA-Z0-9\-\_\.]*@[a-zA-Z0-9\-\_\.]*>/
" ^> lines
syn match sendprString /^>[a-zA-Z\-]*:/
syn region sendprLabel start="\[" end="\]"
syn match sendprString /^To:/
syn match sendprString /^From:/
syn match sendprString /^Reply-To:/
syn match sendprString /^Cc:/
syn match sendprString /^X-send-pr-version:/
syn match sendprString /^X-GNATS-Notify:/

hi def link sendprComment   Comment
hi def link sendprType      Type
hi def link sendprString    String
hi def link sendprLabel     Label

let &cpo = s:cpo_save
unlet s:cpo_save
