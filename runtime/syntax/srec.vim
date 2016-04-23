" Vim syntax file
" Language:	Motorola S-Record
" Maintainer:	Markus Heidelberg <markus.heidelberg@web.de>
" Last Change:	2015 Feb 24

" Each record (line) is built as follows:
"
"    field       digits          states
"
"  +----------+
"  | start    |  1 ('S')         srecRecStart
"  +----------+
"  | type     |  1               srecRecType, (srecRecTypeUnknown)
"  +----------+
"  | count    |  2               srecByteCount
"  +----------+
"  | address  |  4/6/8           srecNoAddress, srecDataAddress, srecRecCount, srecStartAddress, (srecAddressFieldUnknown)
"  +----------+
"  | data     |  0..504/502/500  srecDataOdd, srecDataEven, (srecDataUnexpected)
"  +----------+
"  | checksum |  2               srecChecksum
"  +----------+
"
" States in parentheses in the upper format description indicate that they
" should not appear in a valid file.

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn match srecRecStart "^S"

syn match srecRecTypeUnknown "^S."        contains=srecRecStart
syn match srecRecType        "^S[0-35-9]" contains=srecRecStart

syn match srecByteCount "^S.[0-9a-fA-F]\{2}"        contains=srecRecTypeUnknown nextgroup=srecAddressFieldUnknown,srecChecksum
syn match srecByteCount "^S[0-35-9][0-9a-fA-F]\{2}" contains=srecRecType

syn match srecAddressFieldUnknown "[0-9a-fA-F]\{2}" contained nextgroup=srecAddressFieldUnknown,srecChecksum

syn match srecNoAddress    "^S0[0-9a-fA-F]\{6}"  contains=srecByteCount nextgroup=srecDataOdd,srecChecksum
syn match srecDataAddress  "^S1[0-9a-fA-F]\{6}"  contains=srecByteCount nextgroup=srecDataOdd,srecChecksum
syn match srecDataAddress  "^S2[0-9a-fA-F]\{8}"  contains=srecByteCount nextgroup=srecDataOdd,srecChecksum
syn match srecDataAddress  "^S3[0-9a-fA-F]\{10}" contains=srecByteCount nextgroup=srecDataOdd,srecChecksum
syn match srecRecCount     "^S5[0-9a-fA-F]\{6}"  contains=srecByteCount nextgroup=srecDataUnexpected,srecChecksum
syn match srecRecCount     "^S6[0-9a-fA-F]\{8}"  contains=srecByteCount nextgroup=srecDataUnexpected,srecChecksum
syn match srecStartAddress "^S7[0-9a-fA-F]\{10}" contains=srecByteCount nextgroup=srecDataUnexpected,srecChecksum
syn match srecStartAddress "^S8[0-9a-fA-F]\{8}"  contains=srecByteCount nextgroup=srecDataUnexpected,srecChecksum
syn match srecStartAddress "^S9[0-9a-fA-F]\{6}"  contains=srecByteCount nextgroup=srecDataUnexpected,srecChecksum

" alternating highlight per byte for easier reading
syn match srecDataOdd        "[0-9a-fA-F]\{2}" contained nextgroup=srecDataEven,srecChecksum
syn match srecDataEven       "[0-9a-fA-F]\{2}" contained nextgroup=srecDataOdd,srecChecksum
" data bytes which should not exist
syn match srecDataUnexpected "[0-9a-fA-F]\{2}" contained nextgroup=srecDataUnexpected,srecChecksum
" Data digit pair regex usage also results in only highlighting the checksum
" if the number of data characters is even.

syn match srecChecksum "[0-9a-fA-F]\{2}$" contained

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_srec_syntax_inits")
  if version < 508
    let did_srec_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  " The default methods for highlighting. Can be overridden later
  HiLink srecRecStart            srecRecType
  HiLink srecRecTypeUnknown      srecRecType
  HiLink srecRecType             WarningMsg
  HiLink srecByteCount           Constant
  hi def srecAddressFieldUnknown term=italic cterm=italic gui=italic
  HiLink srecNoAddress           DiffAdd
  HiLink srecDataAddress         Comment
  HiLink srecRecCount            srecNoAddress
  HiLink srecStartAddress        srecDataAddress
  hi def srecDataOdd             term=bold cterm=bold gui=bold
  hi def srecDataEven            term=NONE cterm=NONE gui=NONE
  HiLink srecDataUnexpected      Error
  HiLink srecChecksum            DiffChange

  delcommand HiLink
endif

let b:current_syntax = "srec"

" vim: ts=8
