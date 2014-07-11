" Vim syntax file
" Language:	TealInfo source files (*.tli)
" Maintainer:	Kurt W. Andrews <kandrews@fastrans.net>
" Last Change:	2001 May 10
" Version:      1.0

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" TealInfo Objects

syn keyword tliObject LIST POPLIST WINDOW POPWINDOW OUTLINE CHECKMARK GOTO
syn keyword tliObject LABEL IMAGE RECT TRES PASSWORD POPEDIT POPIMAGE CHECKLIST

" TealInfo Fields

syn keyword tliField X Y W H BX BY BW BH SX SY FONT BFONT CYCLE DELAY TABS
syn keyword tliField STYLE BTEXT RECORD DATABASE KEY TARGET DEFAULT TEXT
syn keyword tliField LINKS MAXVAL

" TealInfo Styles

syn keyword tliStyle INVERTED HORIZ_RULE VERT_RULE NO_SCROLL NO_BORDER BOLD_BORDER
syn keyword tliStyle ROUND_BORDER ALIGN_RIGHT ALIGN_CENTER ALIGN_LEFT_START ALIGN_RIGHT_START
syn keyword tliStyle ALIGN_CENTER_START ALIGN_LEFT_END ALIGN_RIGHT_END ALIGN_CENTER_END
syn keyword tliStyle LOCKOUT BUTTON_SCROLL BUTTON_SELECT STROKE_FIND FILLED REGISTER

" String and Character constants

syn match tliSpecial	"@"
syn region tliString	start=+"+ end=+"+

"TealInfo Numbers, identifiers and comments

syn case ignore
syn match tliNumber	"\d*"
syn match tliIdentifier	"\<\h\w*\>"
syn match tliComment	"#.*"
syn case match

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_tli_syntax_inits")
  if version < 508
    let did_tli_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink tliNumber	Number
  HiLink tliString	String
  HiLink tliComment	Comment
  HiLink tliSpecial	SpecialChar
  HiLink tliIdentifier Identifier
  HiLink tliObject     Statement
  HiLink tliField      Type
  HiLink tliStyle      PreProc

  delcommand HiLink
endif

let b:current_syntax = "tli"

" vim: ts=8
