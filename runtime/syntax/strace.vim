" Vim syntax file
" This is a GENERATED FILE. Please always refer to source file at the URI below.
" Language: strace output
" Maintainer: David Necas (Yeti) <yeti@physics.muni.cz>
" Last Change: 2015-01-16

" Setup
if version >= 600
	if exists("b:current_syntax")
		finish
	endif
else
	syntax clear
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
if version >= 508 || !exists("did_strace_syntax_inits")
	if version < 508
		let did_strace_syntax_inits = 1
		command -nargs=+ HiLink hi link <args>
	else
		command -nargs=+ HiLink hi def link <args>
	endif

	HiLink straceComment Comment
	HiLink straceVerbosed Comment
	HiLink stracePID PreProc
	HiLink straceNumber Number
	HiLink straceNumberRHS Type
	HiLink straceOtherRHS Type
	HiLink straceString String
	HiLink straceConstant Function
	HiLink straceEquals Type
	HiLink straceSysCallEmbed straceSysCall
	HiLink straceSysCall Statement
	HiLink straceParenthesis Statement
	HiLink straceOperator Normal
	HiLink straceSpecialChar Special
	HiLink straceOtherPID PreProc

	delcommand HiLink
endif

let b:current_syntax = "strace"
