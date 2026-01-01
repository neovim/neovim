" VIM syntax file
" Language:	nroff/groff
" Maintainer:	John Marshall <jmarshall@hey.com>
" Previous Maintainer:	Pedro Alejandro López-Valencia <palopezv@gmail.com>
" Previous Maintainer:	Jérôme Plût <Jerome.Plut@ens.fr>
" Last Change:	2021 Mar 28
"	2025 Apr 24 by Eisuke Kawashima (move options from syntax to ftplugin #17174)
"
" {{{1 Todo
"
" TODO:
"
" * Write syntax highlighting files for the preprocessors,
"	and integrate with nroff.vim.
"
"
" {{{1 Start syntax highlighting.
"
" quit when a syntax file was already loaded
"
if exists("b:current_syntax")
	finish
endif

let s:cpo_save = &cpo
set cpo&vim

if exists("nroff_is_groff")
	let b:nroff_is_groff = 1
endif

syn spell toplevel
syn case match

"
" {{{1 plugin settings...
"
" {{{2 enable spacing error highlighting
"
if exists("nroff_space_errors")
	syn match nroffError /\s\+$/
	syn match nroffSpaceError /[.,:;!?]\s\{2,}/
endif

" {{{1 Escape sequences
" ------------------------------------------------------------

syn match nroffEscChar /\\[CN]/ nextgroup=nroffEscCharArg
syn match nroffEscape /\\[*fgmnYV]/ nextgroup=nroffEscRegPar,nroffEscRegArg
syn match nroffEscape /\\s[+-]\=/ nextgroup=nroffSize
syn match nroffEscape /\\[$AbDhlLRvxXZ]/ nextgroup=nroffEscPar,nroffEscArg

syn match nroffEscRegArg /./ contained
syn match nroffEscRegArg2 /../ contained
syn match nroffEscRegPar /(/ contained nextgroup=nroffEscRegArg2
syn match nroffEscArg /./ contained
syn match nroffEscArg2 /../ contained
syn match nroffEscPar /(/ contained nextgroup=nroffEscArg2
syn match nroffSize /\((\d\)\=\d/ contained

syn region nroffEscCharArg start=/'/ end=/'/ contained
syn region nroffEscArg start=/'/ end=/'/ contained contains=nroffEscape,@nroffSpecial

if exists("b:nroff_is_groff")
	syn region nroffEscRegArg matchgroup=nroffEscape start=/\[/ end=/\]/ contained oneline
	syn region nroffSize matchgroup=nroffEscape start=/\[/ end=/\]/ contained
endif

syn match nroffEscape /\\[adprtu{}]/
syn match nroffEscape /\\$/
syn match nroffEscape /\\\$[@*]/

" {{{1 Strings and special characters
" ------------------------------------------------------------

syn match nroffSpecialChar /\\[\\eE?!-]/
syn match nroffSpace "\\[&%~|^0)/,]"
syn match nroffSpecialChar /\\(../

if exists("b:nroff_is_groff")
	syn match nroffSpecialChar /\\\[[^]]*]/
	syn region nroffPreserve  matchgroup=nroffSpecialChar start=/\\?/ end=/\\?/ oneline
endif

syn region nroffPreserve matchgroup=nroffSpecialChar start=/\\!/ end=/$/ oneline

syn cluster nroffSpecial contains=nroffSpecialChar,nroffSpace


syn region nroffString start=/"/ end=/"/ skip=/\\$/ contains=nroffEscape,@nroffSpecial contained
syn region nroffString start=/'/ end=/'/ skip=/\\$/ contains=nroffEscape,@nroffSpecial contained


" {{{1 Numbers and units
" ------------------------------------------------------------
syn match nroffNumBlock /[0-9.]\a\=/ contained contains=nroffNumber
syn match nroffNumber /\d\+\(\.\d*\)\=/ contained nextgroup=nroffUnit,nroffBadChar
syn match nroffNumber /\.\d\+)/ contained nextgroup=nroffUnit,nroffBadChar
syn match nroffBadChar /./ contained
syn match nroffUnit /[icpPszmnvMu]/ contained


" {{{1 Requests
" ------------------------------------------------------------

" Requests begin with . or ' at the beginning of a line, or
" after .if or .ie.

syn match nroffReqLeader /^[.']/	nextgroup=nroffReqName skipwhite
syn match nroffReqLeader /[.']/	contained nextgroup=nroffReqName skipwhite

if exists("b:nroff_is_groff")
"
" GNU troff allows long request names
"
	syn match nroffReqName /[^\t \\\[?]\+/ contained nextgroup=nroffReqArg
else
	syn match nroffReqName /[^\t \\\[?]\{1,2}/ contained nextgroup=nroffReqArg
endif

syn region nroffReqArg start=/\S/ skip=/\\$/ end=/$/ contained contains=nroffEscape,@nroffSpecial,nroffString,nroffError,nroffSpaceError,nroffNumBlock,nroffComment

" {{{2 Conditional: .if .ie .el
syn match nroffReqName /\(if\|ie\)/ contained nextgroup=nroffCond skipwhite
syn match nroffReqName /el/ contained nextgroup=nroffReqLeader skipwhite
syn match nroffCond /\S\+/ contained nextgroup=nroffReqLeader skipwhite

" {{{2 String definition: .ds .as
syn match nroffReqname /[da]s/ contained nextgroup=nroffDefIdent skipwhite
syn match nroffDefIdent /\S\+/ contained nextgroup=nroffDefinition skipwhite
syn region nroffDefinition matchgroup=nroffSpecialChar start=/"/ matchgroup=NONE end=/\\"/me=e-2 skip=/\\$/ start=/\S/ end=/$/ contained contains=nroffDefSpecial
syn match nroffDefSpecial /\\$/ contained
syn match nroffDefSpecial /\\\((.\)\=./ contained

if exists("b:nroff_is_groff")
	syn match nroffDefSpecial /\\\[[^]]*]/ contained
endif

" {{{2 Macro definition: .de .am, also diversion: .di
syn match nroffReqName /\(d[ei]\|am\)/ contained nextgroup=nroffIdent skipwhite
syn match nroffIdent /[^[?( \t]\+/ contained
if exists("b:nroff_is_groff")
	syn match nroffReqName /als/ contained nextgroup=nroffIdent skipwhite
endif

" {{{2 Register definition: .rn .rr
syn match nroffReqName /[rn]r/ contained nextgroup=nroffIdent skipwhite
if exists("b:nroff_is_groff")
	syn match nroffReqName /\(rnn\|aln\)/ contained nextgroup=nroffIdent skipwhite
endif


" {{{1 eqn/tbl/pic
" ------------------------------------------------------------
" <jp>
" XXX: write proper syntax highlight for eqn / tbl / pic ?
" <jp />

syn region nroffEquation start=/^\.\s*EQ\>/ end=/^\.\s*EN\>/
syn region nroffTable start=/^\.\s*TS\>/ end=/^\.\s*TE\>/ contains=@Spell
syn region nroffPicture start=/^\.\s*PS\>/ end=/^\.\s*PE\>/
syn region nroffRefer start=/^\.\s*\[\>/ end=/^\.\s*\]\>/ contains=@Spell
syn region nroffGrap start=/^\.\s*G1\>/ end=/^\.\s*G2\>/
syn region nroffGremlin start=/^\.\s*GS\>/ end=/^\.\s*GE|GF\>/

" {{{1 Comments
" ------------------------------------------------------------

syn region nroffIgnore start=/^[.']\s*ig/ end=/^['.]\s*\./
syn match nroffComment /\(^[.']\s*\)\=\\".*/ contains=nroffTodo,@Spell
syn match nroffComment /^'''.*/  contains=nroffTodo,@Spell

if exists("b:nroff_is_groff")
	syn match nroffComment "\\#.*$" contains=nroffTodo,@Spell
endif

syn keyword nroffTodo TODO XXX FIXME contained

" {{{1 Hilighting
" ------------------------------------------------------------
"

"
" Define the default highlighting.
" Only when an item doesn't have highlighting yet
"

hi def link nroffEscChar nroffSpecialChar
hi def link nroffEscCharArg nroffSpecialChar
hi def link nroffSpecialChar SpecialChar
hi def link nroffSpace Delimiter

hi def link nroffEscRegArg2 nroffEscRegArg
hi def link nroffEscRegArg nroffIdent

hi def link nroffEscArg2 nroffEscArg
hi def link nroffEscPar nroffEscape

hi def link nroffEscRegPar nroffEscape
hi def link nroffEscArg nroffEscape
hi def link nroffSize nroffEscape
hi def link nroffEscape PreProc

hi def link nroffIgnore Comment
hi def link nroffComment Comment
hi def link nroffTodo Todo

hi def link nroffReqLeader nroffRequest
hi def link nroffReqName nroffRequest
hi def link nroffRequest Statement
hi def link nroffCond PreCondit
hi def link nroffDefIdent nroffIdent
hi def link nroffIdent Identifier

hi def link nroffEquation PreProc
hi def link nroffTable PreProc
hi def link nroffPicture PreProc
hi def link nroffRefer PreProc
hi def link nroffGrap PreProc
hi def link nroffGremlin PreProc

hi def link nroffNumber Number
hi def link nroffBadChar nroffError
hi def link nroffSpaceError nroffError
hi def link nroffError Error

hi def link nroffPreserve String
hi def link nroffString String
hi def link nroffDefinition String
hi def link nroffDefSpecial Special


let b:current_syntax = "nroff"

let &cpo = s:cpo_save
unlet s:cpo_save
" vim600: set fdm=marker fdl=2:
