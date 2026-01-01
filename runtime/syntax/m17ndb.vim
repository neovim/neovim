" Vim syntax file
" Language:	m17n database
" Maintainer:	David Mandelberg <david@mandelberg.org>
" Last Change:	2025 Feb 21
"
" https://www.nongnu.org/m17n/manual-en/m17nDBFormat.html describes the
" syntax, but some of its regexes don't match the code. read_element() in
" https://git.savannah.nongnu.org/cgit/m17n/m17n-lib.git/tree/src/plist.c
" seems to be a better place to understand the syntax.

if exists("b:current_syntax")
 finish
endif
let b:current_syntax = "m17ndb"

syn match m17ndbSymbol /\([^\x00- ()"\\]\|\\\_.\)\+/
syn match m17ndbComment ";.*$" contains=@Spell
syn match m17ndbInteger "-\?[0-9]\+"
syn match m17ndbInteger "[0#]x[0-9A-Fa-f]\+"
syn match m17ndbCharacter "?\(\_[^\\]\|\\\_.\)"
syn region m17ndbText start=/\Z"/ skip=/\\\\\|\\"/ end=/"/
syn region m17ndbPlist matchgroup=m17ndbParen start="(" end=")" fold contains=ALL

hi def link m17ndbCharacter Character
hi def link m17ndbComment Comment
hi def link m17ndbInteger Number
hi def link m17ndbParen Delimiter
hi def link m17ndbText String
