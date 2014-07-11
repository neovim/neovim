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


" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syn clear
elseif exists("b:current_syntax")
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
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_mgp_syn_inits")
  let did_mgp_syn_inits = 1
  if version < 508
    let did_mgp_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink mgpLineSkip	Special

  HiLink mgpHash	mgpComment
  HiLink mgpPercent	mgpComment
  HiLink mgpComment	Comment

  HiLink mgpCommand	Identifier

  HiLink mgpLine	Type

  HiLink mgpFile	String
  HiLink mgpSize	Number
  HiLink mgpValue	Number

  HiLink mgpPage	mgpDefine
  HiLink mgpNoDefault	mgpDefine
  HiLink mgpDefine	Define

  delcommand HiLink
endif

let b:current_syntax = "mgp"
