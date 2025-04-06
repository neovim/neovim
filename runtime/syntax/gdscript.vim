" Vim syntax file for Godot gdscript
" Language:     gdscript
" Maintainer:   Maxim Kim <habamax@gmail.com>
" Website:      https://github.com/habamax/vim-gdscript
" Filenames:    *.gd

if exists("b:current_syntax")
    finish
endif

let s:keepcpo = &cpo
set cpo&vim

syntax sync maxlines=100

syn keyword gdscriptConditional if else elif match
syn keyword gdscriptRepeat for while break continue

syn keyword gdscriptOperator is as not and or in

syn match gdscriptBlockStart ":\s*$"

syn keyword gdscriptKeyword null self owner parent tool
syn keyword gdscriptBoolean false true

syn keyword gdscriptStatement remote master puppet remotesync mastersync puppetsync sync
syn keyword gdscriptStatement return pass
syn keyword gdscriptStatement static const enum
syn keyword gdscriptStatement breakpoint assert
syn keyword gdscriptStatement onready
syn keyword gdscriptStatement class_name extends

syn keyword gdscriptType void bool int float String contained
syn match gdscriptType ":\s*\zs\h\w*" contained
syn match gdscriptType "->\s*\zs\h\w*" contained

syn keyword gdscriptStatement var nextgroup=gdscriptTypeDecl skipwhite
syn keyword gdscriptStatement const nextgroup=gdscriptTypeDecl skipwhite
syn match gdscriptTypeDecl "\h\w*\s*:\s*\h\w*" contains=gdscriptType contained skipwhite
syn match gdscriptTypeDecl "->\s*\h\w*" contains=gdscriptType skipwhite

syn keyword gdscriptStatement export nextgroup=gdscriptExportTypeDecl skipwhite
syn match gdscriptExportTypeDecl "(.\{-}[,)]" contains=gdscriptOperator,gdscriptType contained skipwhite

syn keyword gdscriptStatement setget nextgroup=gdscriptSetGet,gdscriptSetGetSeparator skipwhite
syn match gdscriptSetGet "\h\w*" nextgroup=gdscriptSetGetSeparator display contained skipwhite
syn match gdscriptSetGetSeparator "," nextgroup=gdscriptSetGet display contained skipwhite

syn keyword gdscriptStatement class func signal nextgroup=gdscriptFunctionName skipwhite
syn match gdscriptFunctionName "\h\w*" nextgroup=gdscriptFunctionParams display contained skipwhite
syn match gdscriptFunctionParams "(.*)" contains=gdscriptTypeDecl display contained skipwhite

syn match gdscriptNode "\$\h\w*\%(/\h\w*\)*"

syn match gdscriptComment "#.*$" contains=@Spell,gdscriptTodo

syn region gdscriptString matchgroup=gdscriptQuotes
      \ start=+[uU]\=\z(['"]\)+ end="\z1" skip="\\\\\|\\\z1"
      \ contains=gdscriptEscape,@Spell

syn region gdscriptString matchgroup=gdscriptTripleQuotes
      \ start=+[uU]\=\z('''\|"""\)+ end="\z1" keepend
      \ contains=gdscriptEscape,@Spell

syn match gdscriptEscape +\\[abfnrtv'"\\]+ contained
syn match gdscriptEscape "\\$"

" Numbers
syn match gdscriptNumber "\<0x\%(_\=\x\)\+\>"
syn match gdscriptNumber "\<0b\%(_\=[01]\)\+\>"
syn match gdscriptNumber "\<\d\%(_\=\d\)*\>"
syn match gdscriptNumber "\<\d\%(_\=\d\)*\%(e[+-]\=\d\%(_\=\d\)*\)\=\>"
syn match gdscriptNumber "\<\d\%(_\=\d\)*\.\%(e[+-]\=\d\%(_\=\d\)*\)\=\%(\W\|$\)\@="
syn match gdscriptNumber "\%(^\|\W\)\@1<=\%(\d\%(_\=\d\)*\)\=\.\d\%(_\=\d\)*\%(e[+-]\=\d\%(_\=\d\)*\)\=\>"

" XXX, TODO, etc
syn keyword gdscriptTodo TODO XXX FIXME HACK NOTE BUG contained

hi def link gdscriptStatement Statement
hi def link gdscriptKeyword Keyword
hi def link gdscriptConditional Conditional
hi def link gdscriptBoolean Boolean
hi def link gdscriptOperator Operator
hi def link gdscriptRepeat Repeat
hi def link gdscriptSetGet Function
hi def link gdscriptFunctionName Function
hi def link gdscriptBuiltinStruct Typedef
hi def link gdscriptComment Comment
hi def link gdscriptString String
hi def link gdscriptQuotes String
hi def link gdscriptTripleQuotes String
hi def link gdscriptEscape Special
hi def link gdscriptNode PreProc
hi def link gdscriptType Type
hi def link gdscriptNumber Number
hi def link gdscriptBlockStart Special
hi def link gdscriptTodo Todo


let b:current_syntax = "gdscript"

let &cpo = s:keepcpo
unlet s:keepcpo
