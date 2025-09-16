" Vim syntax file
" Language:	codeowners
" Maintainer:	Jon Parise <jon@indelible.org>
" Last Change:	2025 Sep 14

if exists('b:current_syntax')
  finish
endif

" Comments
syn match codeownersComment /#.*$/ contains=codeownersTodo,@Spell
syn keyword codeownersTodo TODO FIXME XXX contained

" Patterns
syn match codeownersPattern /^#\@![^#]*/ contains=codeownersGlob
syn match codeownersGlob /^\S\+/ contained nextgroup=codeownersOwner skipwhite
syn match codeownersOwner /\S\+/ contained nextgroup=codeownersOwner skipwhite

hi def link codeownersComment Comment
hi def link codeownersOwner Identifier
hi def link codeownersTodo Todo

let b:current_syntax = 'codeowners'
