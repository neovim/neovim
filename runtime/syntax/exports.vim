" Vim syntax file
" Language:	exports
" Maintainer:	Charles E. Campbell <NdrOchipS@PcampbellAfamily.Mbiz>
" Last Change:	Oct 23, 2014
" Version:	5
" Notes:		This file includes both SysV and BSD 'isms
" URL:	http://www.drchip.org/astronaut/vim/index.html#SYNTAX_EXPORTS

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
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
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_exports_syntax_inits")
  if version < 508
    let did_exports_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

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
endif

let b:current_syntax = "exports"
" vim: ts=10
