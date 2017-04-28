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
command -nargs=+ HiLink hi def link <args>

HiLink changelogText		Normal
HiLink changelogBullet	Type
HiLink changelogColon		Type
HiLink changelogFiles		Comment
HiLink changelogFuncs	Comment
HiLink changelogHeader	Statement
HiLink changelogMail		Special
HiLink changelogNumber	Number
HiLink changelogMonth		Number
HiLink changelogDay		Number
HiLink changelogError		Folded

delcommand HiLink

let b:current_syntax = "changelog"

" vim: ts=8
