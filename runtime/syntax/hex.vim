" Vim syntax file
" Language:	Intel hex MCS51
" Maintainer:	Sams Ricahrd <sams@ping.at>
" Last Change:	2003 Apr 25

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn case ignore

" storage types

syn match hexChecksum	"[0-9a-fA-F]\{2}$"
syn match hexAdress  "^:[0-9a-fA-F]\{6}" contains=hexDataByteCount
syn match hexRecType  "^:[0-9a-fA-F]\{8}" contains=hexAdress
syn match hexDataByteCount  contained "^:[0-9a-fA-F]\{2}" contains=hexStart
syn match hexStart contained "^:"
syn match hexExtAdrRec "^:02000002[0-9a-fA-F]\{4}" contains=hexSpecRec
syn match hexExtLinAdrRec "^:02000004[0-9a-fA-F]\{4}" contains=hexSpecRec
syn match hexSpecRec contained "^:0[02]00000[124]" contains=hexStart
syn match hexEOF "^:00000001" contains=hexStart

syn case match

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_hex_syntax_inits")
  if version < 508
    let did_hex_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  " The default methods for highlighting.  Can be overridden later
  HiLink hexStart		SpecialKey
  HiLink hexDataByteCount	Constant
  HiLink hexAdress		Comment
  HiLink hexRecType		WarningMsg
  HiLink hexChecksum		Search
  HiLink hexExtAdrRec		hexAdress
  HiLink hexEOF			hexSpecRec
  HiLink hexExtLinAdrRec	hexAdress
  HiLink hexSpecRec		DiffAdd

  delcommand HiLink
endif

let b:current_syntax = "hex"

" vim: ts=8
