" Vim syntax file
" Language:	Microsoft Module-Definition (.def) File
" Orig Author:	Rob Brady <robb@datatone.com>
" Maintainer:	Wu Yongwei <wuyongwei@gmail.com>
" Last Change:	$Date: 2007/10/02 13:51:24 $
" $Revision: 1.2 $

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn case ignore

syn match defComment	";.*"

syn keyword defKeyword	LIBRARY STUB EXETYPE DESCRIPTION CODE WINDOWS DOS
syn keyword defKeyword	RESIDENTNAME PRIVATE EXPORTS IMPORTS SEGMENTS
syn keyword defKeyword	HEAPSIZE DATA
syn keyword defStorage	LOADONCALL MOVEABLE DISCARDABLE SINGLE
syn keyword defStorage	FIXED PRELOAD

syn match   defOrdinal	"\s\+@\d\+"

syn region  defString	start=+'+ end=+'+

syn match   defNumber	"\d+"
syn match   defNumber	"0x\x\+"


" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_def_syntax_inits")
  if version < 508
    let did_def_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink defComment	Comment
  HiLink defKeyword	Keyword
  HiLink defStorage	StorageClass
  HiLink defString	String
  HiLink defNumber	Number
  HiLink defOrdinal	Operator

  delcommand HiLink
endif

let b:current_syntax = "def"

" vim: ts=8
