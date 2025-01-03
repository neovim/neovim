" Vim syntax file
" Language:	jj description
" Maintainer:	Gregory Anders <greg@gpanders.com>
" Last Change:	2024 May 8

if exists('b:current_syntax')
  finish
endif

syn match jjAdded "A .*" contained
syn match jjRemoved "D .*" contained
syn match jjChanged "M .*" contained

syn region jjComment start="^JJ: " end="$" contains=jjAdded,jjRemoved,jjChanged

syn include @jjCommitDiff syntax/diff.vim
syn region jjCommitDiff start=/\%(^diff --\%(git\|cc\|combined\) \)\@=/ end=/^\%(diff --\|$\|@@\@!\|[^[:alnum:]\ +-]\S\@!\)\@=/ fold contains=@jjCommitDiff

hi def link jjComment Comment
hi def link jjAdded Added
hi def link jjRemoved Removed
hi def link jjChanged Changed

let b:current_syntax = 'jj'
