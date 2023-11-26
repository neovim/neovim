" Vim syntax file
" Language:	git ignore
" Maintainer:	ObserverOfTime <chronobserver@disroot.org>
" Filenames:	.gitignore, *.git/info/exclude
" Last Change:	2022 Sep 10

if exists('b:current_syntax')
    finish
endif

" Comment
syn keyword gitignoreTodo contained TODO FIXME XXX
syn match gitignoreComment /^#.*/ contains=gitignoreTodo

" Pattern
syn match gitignorePattern /^#\@!.*$/ contains=gitignoreNegation,gitignoreGlob,gitignoreRange,gitignoreSeparator
syn match gitignoreNegation /^!/ contained
syn match gitignoreGlob /\\\@1<![?*]/ contained
syn match gitignoreRange /\\\@1<!\[.\{-}\]/ contained
syn match gitignoreSeparator '/' contained

hi def link gitignoreComment Comment
hi def link gitignoreGlob Special
hi def link gitignoreNegation SpecialChar
hi def link gitignoreRange Special
hi def link gitignoreSeparator Delimiter
hi def link gitignoreTodo Todo

let b:current_syntax = 'gitignore'
