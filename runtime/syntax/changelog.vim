" Vim syntax file
" Language:	generic ChangeLog file
" Written By:	Gediminas Paulauskas <menesis@delfi.lt>
" Maintainer:	Corinna Vinschen <vinschen@redhat.com>
" Last Change:	June 1, 2003

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn case ignore

if exists('b:changelog_spacing_errors')
  let s:spacing_errors = b:changelog_spacing_errors
elseif exists('g:changelog_spacing_errors')
  let s:spacing_errors = g:changelog_spacing_errors
else
  let s:spacing_errors = 1
endif

if s:spacing_errors
  syn match	changelogError "^ \+"
endif

syn match	changelogText	"^\s.*$" contains=changelogMail,changelogNumber,changelogMonth,changelogDay,changelogError
syn match	changelogHeader	"^\S.*$" contains=changelogNumber,changelogMonth,changelogDay,changelogMail
syn region	changelogFiles	start="^\s\+[+*]\s" end=":" end="^$" contains=changelogBullet,changelogColon,changelogFuncs,changelogError keepend
syn region	changelogFiles	start="^\s\+[([]" end=":" end="^$" contains=changelogBullet,changelogColon,changelogFuncs,changelogError keepend
syn match	changelogFuncs  contained "(.\{-})" extend
syn match	changelogFuncs  contained "\[.\{-}]" extend
syn match	changelogColon	contained ":"

syn match	changelogBullet	contained "^\s\+[+*]\s" contains=changelogError
syn match	changelogMail	contained "<[A-Za-z0-9\._:+-]\+@[A-Za-z0-9\._-]\+>"
syn keyword	changelogMonth	contained jan feb mar apr may jun jul aug sep oct nov dec
syn keyword	changelogDay	contained mon tue wed thu fri sat sun
syn match	changelogNumber	contained "[.-]*[0-9]\+"

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link changelogText		Normal
hi def link changelogBullet	Type
hi def link changelogColon		Type
hi def link changelogFiles		Comment
hi def link changelogFuncs	Comment
hi def link changelogHeader	Statement
hi def link changelogMail		Special
hi def link changelogNumber	Number
hi def link changelogMonth		Number
hi def link changelogDay		Number
hi def link changelogError		Folded


let b:current_syntax = "changelog"

" vim: ts=8
