" Vim syntax file
" Language:     mgp - MaGic Point
" Maintainer:   Gerfried Fuchs <alfie@ist.org>
" Filenames:    *.mgp
" Last Change:  25 Apr 2001
" URL:		http://alfie.ist.org/vim/syntax/mgp.vim
"
" Comments are very welcome - but please make sure that you are commenting on
" the latest version of this file.
" SPAM is _NOT_ welcome - be ready to be reported!


" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif


syn match mgpLineSkip "\\$"

" all the commands that are currently recognized
syn keyword mgpCommand contained size fore back bgrad left leftfill center
syn keyword mgpCommand contained right shrink lcutin rcutin cont xfont vfont
syn keyword mgpCommand contained tfont tmfont tfont0 bar image newimage
syn keyword mgpCommand contained prefix icon bimage default tab vgap hgap
syn keyword mgpCommand contained pause mark again system filter endfilter
syn keyword mgpCommand contained vfcap tfdir deffont font embed endembed
syn keyword mgpCommand contained noop pcache include

" charset is not yet supported :-)
" syn keyword mgpCommand contained charset

syn region mgpFile     contained start=+"+ skip=+\\\\\|\\"+ end=+"+
syn match mgpValue     contained "\d\+"
syn match mgpSize      contained "\d\+x\d\+"
syn match mgpLine      +^%.*$+ contains=mgpCommand,mgpFile,mgpSize,mgpValue

" Comments
syn match mgpPercent   +^%%.*$+
syn match mgpHash      +^#.*$+

" these only work alone
syn match mgpPage      +^%page$+
syn match mgpNoDefault +^%nodefault$+


" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link mgpLineSkip	Special

hi def link mgpHash	mgpComment
hi def link mgpPercent	mgpComment
hi def link mgpComment	Comment

hi def link mgpCommand	Identifier

hi def link mgpLine	Type

hi def link mgpFile	String
hi def link mgpSize	Number
hi def link mgpValue	Number

hi def link mgpPage	mgpDefine
hi def link mgpNoDefault	mgpDefine
hi def link mgpDefine	Define


let b:current_syntax = "mgp"
