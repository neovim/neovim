" Vim syntax file
" Language:	Valve Data Format
" Maintainer:	ObserverOfTime <chronobserver@disroot.org>
" Filenames:	*.vdf
" Last Change:	2022 Sep 15

if exists('b:current_syntax')
    finish
endif

let s:cpo_save = &cpoptions
set cpoptions&vim

" Comment
syn keyword vdfTodo contained TODO FIXME XXX
syn match vdfComment +//.*+ contains=vdfTodo

" Macro
syn match vdfMacro /^\s*#.*/

" Tag
syn region vdfTag start=/"/ skip=/\\"/ end=/"/
            \ nextgroup=vdfValue skipwhite oneline

" Section
syn region vdfSection matchgroup=vdfBrace
            \ start=/{/ end=/}/ transparent fold
            \ contains=vdfTag,vdfSection,vdfComment,vdfConditional

" Conditional
syn match vdfConditional /\[\$\w\{1,1021}\]/ nextgroup=vdfTag

" Value
syn region vdfValue start=/"/ skip=/\\"/ end=/"/
            \ oneline contained contains=vdfVariable,vdfNumber,vdfEscape
syn region vdfVariable start=/%/ skip=/\\%/ end=/%/ oneline contained
syn match vdfEscape /\\[nt\\"]/ contained
syn match vdfNumber /"-\?\d\+"/ contained

hi def link vdfBrace Delimiter
hi def link vdfComment Comment
hi def link vdfConditional Constant
hi def link vdfEscape SpecialChar
hi def link vdfMacro Macro
hi def link vdfNumber Number
hi def link vdfTag Keyword
hi def link vdfTodo Todo
hi def link vdfValue String
hi def link vdfVariable Identifier

let b:current_syntax = 'vdf'

let &cpoptions = s:cpo_save
unlet s:cpo_save
