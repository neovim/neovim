" Vim syntax file
" Language:	jj description
" Maintainer:	Gregory Anders <greg@gpanders.com>
" Last Change:	2024 May 8

if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'jj'

syn match jjAdded "A .*" contained
syn match jjRemoved "D .*" contained
syn match jjChanged "M .*" contained

syn region jjComment start="^JJ: " end="$" contains=jjAdded,jjRemoved,jjChanged

hi def link jjComment Comment
hi def link jjAdded Added
hi def link jjRemoved Removed
hi def link jjChanged Changed
