" Vim syntax file
" Language:	PyPA manifest
" Maintainer:	ObserverOfTime <chronobserver@disroot.org>
" Filenames:	MANIFEST.in
" Last Change:	2023 Aug 12

if exists('b:current_syntax')
    finish
endif

let s:cpo_save = &cpoptions
set cpoptions&vim

syn iskeyword @,-

" Comments
syn keyword pymanifestTodo contained TODO FIXME XXX
syn match pymanifestComment /\\\@1<!#.*/ contains=pymanifestTodo

" Commands
syn keyword pymanifestCommand
            \ include exclude
            \ recursive-include recursive-exclude
            \ global-include global-exclude
            \ graft prune

" Globs & character ranges
syn match pymanifestGlob /\*\|\*\*\|?/
syn match pymanifestRange /\\\@1<!\[.\{-}\]/

" Line break
syn match pymanifestLinebreak /\\$\|\\\ze\s\+#/

hi def link pymanifestCommand Keyword
hi def link pymanifestComment Comment
hi def link pymanifestGlob SpecialChar
hi def link pymanifestLinebreak SpecialKey
hi def link pymanifestRange Special
hi def link pymanifestTodo Todo

let b:current_syntax = 'pymanifest'

let &cpoptions = s:cpo_save
unlet s:cpo_save
