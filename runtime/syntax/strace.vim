" Vim syntax file
" This is a GENERATED FILE. Please always refer to source file at the URI below.
" Language: strace output
" Maintainer: David Necas (Yeti) <yeti@physics.muni.cz>
" Last Change: 2015-01-16

" Setup
" quit when a syntax file was already loaded
if exists("b:current_syntax")
	finish
endif

syn case match

" Parse the line
syn match straceSpecialChar "\\\o\{1,3}\|\\." contained
syn region straceString start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=straceSpecialChar oneline
syn match straceNumber "\W[+-]\=\(\d\+\)\=\.\=\d\+\([eE][+-]\=\d\+\)\="lc=1
syn match straceNumber "\W0x\x\+"lc=1
syn match straceNumberRHS "\W\(0x\x\+\|-\=\d\+\)"lc=1 contained
syn match straceOtherRHS "?" contained
syn match straceConstant "[A-Z_]\{2,}"
syn region straceVerbosed start="(" end=")" matchgroup=Normal contained oneline
syn region straceReturned start="\s=\s" end="$" contains=StraceEquals,straceNumberRHS,straceOtherRHS,straceConstant,straceVerbosed oneline transparent
syn match straceEquals "\s=\s"ms=s+1,me=e-1
syn match straceParenthesis "[][(){}]"
syn match straceSysCall "^\w\+"
syn match straceOtherPID "^\[[^]]*\]" contains=stracePID,straceNumber nextgroup=straceSysCallEmbed skipwhite
syn match straceSysCallEmbed "\w\+" contained
syn keyword stracePID pid contained
syn match straceOperator "[-+=*/!%&|:,]"
syn region straceComment start="/\*" end="\*/" oneline

" Define the default highlighting

hi def link straceComment Comment
hi def link straceVerbosed Comment
hi def link stracePID PreProc
hi def link straceNumber Number
hi def link straceNumberRHS Type
hi def link straceOtherRHS Type
hi def link straceString String
hi def link straceConstant Function
hi def link straceEquals Type
hi def link straceSysCallEmbed straceSysCall
hi def link straceSysCall Statement
hi def link straceParenthesis Statement
hi def link straceOperator Normal
hi def link straceSpecialChar Special
hi def link straceOtherPID PreProc


let b:current_syntax = "strace"
