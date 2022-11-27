" Vim syntax file for Godot resource (scenes)
" Language:     gdresource
" Maintainer:   Maxim Kim <habamax@gmail.com>
" Filenames:    *.tscn, *.tres
" Website:      https://github.com/habamax/vim-gdscript

if exists("b:current_syntax")
    finish
endif

let s:keepcpo = &cpo
set cpo&vim

syn match gdResourceNumber "\<0x\%(_\=\x\)\+\>"
syn match gdResourceNumber "\<0b\%(_\=[01]\)\+\>"
syn match gdResourceNumber "\<\d\%(_\=\d\)*\>"
syn match gdResourceNumber "\<\d\%(_\=\d\)*\%(e[+-]\=\d\%(_\=\d\)*\)\=\>"
syn match gdResourceNumber "\<\d\%(_\=\d\)*\.\%(e[+-]\=\d\%(_\=\d\)*\)\=\%(\W\|$\)\@="
syn match gdResourceNumber "\%(^\|\W\)\@1<=\%(\d\%(_\=\d\)*\)\=\.\d\%(_\=\d\)*\%(e[+-]\=\d\%(_\=\d\)*\)\=\>"

syn keyword gdResourceKeyword true false

syn region gdResourceString
      \ start=+[uU]\="+ end='"' skip='\\\\\|\\"'
      \ contains=@Spell keepend

" Section
syn region gdResourceSection matchgroup=gdResourceSectionDelimiter
      \ start='^\[' end=']\s*$'
      \ oneline keepend
      \ contains=gdResourceSectionName,gdResourceSectionAttribute

syn match gdResourceSectionName '\[\@<=\S\+' contained skipwhite
syn match gdResourceSectionAttribute '\S\+\s*=\s*\S\+'
      \ skipwhite keepend contained
      \ contains=gdResourceSectionAttributeName,gdResourceSectionAttributeValue
syn match gdResourceSectionAttributeName '\S\+\ze\(\s*=\)' skipwhite contained
syn match gdResourceSectionAttributeValue '\(=\s*\)\zs\S\+\ze' skipwhite
      \ contained
      \ contains=gdResourceString,gdResourceNumber,gdResourceKeyword


" Section body
syn match gdResourceAttribute '^\s*\S\+\s*=.*$'
      \ skipwhite keepend
      \ contains=gdResourceAttributeName,gdResourceAttributeValue

syn match gdResourceAttributeName '\S\+\ze\(\s*=\)' skipwhite contained
syn match gdResourceAttributeValue '\(=\s*\)\zs.*$' skipwhite
      \ contained
      \ contains=gdResourceString,gdResourceNumber,gdResourceKeyword


hi def link gdResourceNumber Constant
hi def link gdResourceKeyword Constant
hi def link gdResourceSectionName Statement
hi def link gdResourceSectionDelimiter Delimiter
hi def link gdResourceSectionAttributeName Type
hi def link gdResourceAttributeName Identifier
hi def link gdResourceString String

let b:current_syntax = "gdresource"

let &cpo = s:keepcpo
unlet s:keepcpo
