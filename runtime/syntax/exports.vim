" Vim syntax file
" Language:	exports
" Maintainer:	Charles E. Campbell <NdrOchipS@PcampbellAfamily.Mbiz>
" Last Change:	Oct 23, 2014
" Version:	5
" Notes:		This file includes both SysV and BSD 'isms
" URL:	http://www.drchip.org/astronaut/vim/index.html#SYNTAX_EXPORTS

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Options: -word
syn keyword exportsKeyOptions contained	alldirs	nohide	ro	wsync
syn keyword exportsKeyOptions contained	kerb	o	rw
syn match exportsOptError contained	"[a-z]\+"

" Settings: word=
syn keyword exportsKeySettings contained	access	anon	root	rw
syn match exportsSetError contained	"[a-z]\+"

" OptSet: -word=
syn keyword exportsKeyOptSet contained	mapall	maproot	mask	network
syn match exportsOptSetError contained	"[a-z]\+"

" options and settings
syn match exportsSettings	"[a-z]\+="  contains=exportsKeySettings,exportsSetError
syn match exportsOptions	"-[a-z]\+"  contains=exportsKeyOptions,exportsOptError
syn match exportsOptSet	"-[a-z]\+=" contains=exportsKeyOptSet,exportsOptSetError

" Separators
syn match exportsSeparator	"[,:]"

" comments
syn match exportsComment	"^\s*#.*$"	contains=@Spell

" Define the default highlighting.
" Only when an item doesn't have highlighting yet
command -nargs=+ HiLink hi def link <args>

HiLink exportsKeyOptSet	exportsKeySettings
HiLink exportsOptSet	exportsSettings

HiLink exportsComment	Comment
HiLink exportsKeyOptions	Type
HiLink exportsKeySettings	Keyword
HiLink exportsOptions	Constant
HiLink exportsSeparator	Constant
HiLink exportsSettings	Constant

HiLink exportsOptError	Error
HiLink exportsOptSetError	Error
HiLink exportsSetError	Error

delcommand HiLink

let b:current_syntax = "exports"
" vim: ts=10
