" Vim syntax file
" Language:      ART-IM and ART*Enterprise
" Maintainer:    Dorai Sitaram <ds26@gte.com>
" URL:		 http://www.ccs.neu.edu/~dorai/vimplugins/vimplugins.html
" Last Change:   2011 Dec 28 by Thilo Six

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn case ignore

syn keyword artspform => and assert bind
syn keyword artspform declare def-art-fun deffacts defglobal defrule defschema do
syn keyword artspform else for if in$ not or
syn keyword artspform progn retract salience schema test then while

syn match artvariable "?[^ \t";()|&~]\+"

syn match artglobalvar "?\*[^ \t";()|&~]\+\*"

syn match artinstance "![^ \t";()|&~]\+"

syn match delimiter "[()|&~]"

syn region string start=/"/ skip=/\\[\\"]/ end=/"/

syn match number "\<[-+]\=\([0-9]\+\(\.[0-9]*\)\=\|\.[0-9]\+\)\>"

syn match comment ";.*$"

syn match comment "#+:\=ignore" nextgroup=artignore skipwhite skipnl

syn region artignore start="(" end=")" contained contains=artignore,comment

syn region artignore start=/"/ skip=/\\[\\"]/ end=/"/ contained

hi def link artinstance type
hi def link artglobalvar preproc
hi def link artignore comment
hi def link artspform statement
hi def link artvariable function

let b:current_syntax = "art"

let &cpo = s:cpo_save
unlet s:cpo_save
