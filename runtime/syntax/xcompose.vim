" Vim syntax file
" Language:	XCompose
" Maintainer:	ObserverOfTime <chronobserver@disroot.org>
" Filenames:	.XCompose, Compose
" Last Change:	2023 Nov 09

" Comments
syn keyword xcomposeTodo contained TODO FIXME XXX
syn match xcomposeComment /#.*/ contains=xcomposeTodo

" Includes
syn keyword xcomposeInclude include nextgroup=xcomposeFile skipwhite
syn match xcomposeFile /"\([^"]\|\\"\)\+"/ contained
syn match xcomposeSubstitution /%[HLS]/ contained containedin=xcomposeFile

" Modifiers
syn keyword xcomposeModifier Ctrl Lock Caps Shift Alt Meta None
syn match xcomposeModifierPrefix /\s*\zs[!~]\ze\s*/

" Keysyms
syn match xcomposeKeysym /<[A-Za-z0-9_]\+>/
syn match xcomposeKeysym /[A-Za-z0-9_]\+/ contained
syn match xcomposeString /"\([^"]\|\\"\)\+"/ contained nextgroup=xcomposeKeysym skipwhite
syn match xcomposeColon /:/ nextgroup=xcomposeKeysym,xcomposeString skipwhite

hi def link xcomposeColon Delimiter
hi def link xcomposeComment Comment
hi def link xcomposeFile String
hi def link xcomposeInclude Include
hi def link xcomposeKeysym Constant
hi def link xcomposeModifier Function
hi def link xcomposeModifierPrefix Operator
hi def link xcomposeString String
hi def link xcomposeSubstitution Special
hi def link xcomposeTodo Todo

let b:current_syntax = 'xcompose'
