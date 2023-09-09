" Vim syntax file
" Language:	Intel HEX
" Maintainer:	Markus Heidelberg <markus.heidelberg@web.de>
" Previous version:	Sams Ricahrd <sams@ping.at>
" Last Change:	2015 Feb 24

" Each record (line) is built as follows:
"
"    field       digits          states
"
"  +----------+
"  | start    |  1 (':')         hexRecStart
"  +----------+
"  | count    |  2               hexDataByteCount
"  +----------+
"  | address  |  4               hexNoAddress, hexDataAddress, (hexAddressFieldUnknown)
"  +----------+
"  | type     |  2               hexRecType, (hexRecTypeUnknown)
"  +----------+
"  | data     |  0..510          hexDataOdd, hexDataEven, hexExtendedAddress, hexStartAddress, (hexDataFieldUnknown, hexDataUnexpected)
"  +----------+
"  | checksum |  2               hexChecksum
"  +----------+
"
" States in parentheses in the upper format description indicate that they
" should not appear in a valid file.

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn match hexRecStart "^:"

syn match hexDataByteCount "^:[0-9a-fA-F]\{2}" contains=hexRecStart nextgroup=hexAddress

syn match hexAddress "[0-9a-fA-F]\{4}" transparent contained nextgroup=hexRecTypeUnknown,hexRecType
" The address field groups include the record type field in the last 2
" characters, the proper match for highlighting follows below.
syn match hexAddressFieldUnknown "^:[0-9a-fA-F]\{8}"      contains=hexDataByteCount nextgroup=hexDataFieldUnknown,hexChecksum
syn match hexDataAddress         "^:[0-9a-fA-F]\{6}00"    contains=hexDataByteCount nextgroup=hexDataOdd,hexChecksum
syn match hexNoAddress           "^:[0-9a-fA-F]\{6}01"    contains=hexDataByteCount nextgroup=hexDataUnexpected,hexChecksum
syn match hexNoAddress           "^:[0-9a-fA-F]\{6}0[24]" contains=hexDataByteCount nextgroup=hexExtendedAddress
syn match hexNoAddress           "^:[0-9a-fA-F]\{6}0[35]" contains=hexDataByteCount nextgroup=hexStartAddress

syn match hexRecTypeUnknown "[0-9a-fA-F]\{2}" contained
syn match hexRecType        "0[0-5]"          contained

syn match hexDataFieldUnknown "[0-9a-fA-F]\{2}" contained nextgroup=hexDataFieldUnknown,hexChecksum
" alternating highlight per byte for easier reading
syn match hexDataOdd          "[0-9a-fA-F]\{2}" contained nextgroup=hexDataEven,hexChecksum
syn match hexDataEven         "[0-9a-fA-F]\{2}" contained nextgroup=hexDataOdd,hexChecksum
" data bytes which should not exist
syn match hexDataUnexpected   "[0-9a-fA-F]\{2}" contained nextgroup=hexDataUnexpected,hexChecksum
" Data digit pair regex usage also results in only highlighting the checksum
" if the number of data characters is even.

" special data fields
syn match hexExtendedAddress "[0-9a-fA-F]\{4}" contained nextgroup=hexDataUnexpected,hexChecksum
syn match hexStartAddress    "[0-9a-fA-F]\{8}" contained nextgroup=hexDataUnexpected,hexChecksum

syn match hexChecksum "[0-9a-fA-F]\{2}$" contained

" Folding Data Records below an Extended Segment/Linear Address Record
syn region hexExtAdrBlock start="^:[0-9a-fA-F]\{7}[24]" skip="^:[0-9a-fA-F]\{7}0" end="^:"me=s-1 fold transparent

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

" The default methods for highlighting. Can be overridden later
hi def link hexRecStart            hexRecType
hi def link hexDataByteCount       Constant
hi def hexAddressFieldUnknown term=italic cterm=italic gui=italic
hi def link hexDataAddress         Comment
hi def link hexNoAddress           DiffAdd
hi def link hexRecTypeUnknown      hexRecType
hi def link hexRecType             WarningMsg
hi def hexDataFieldUnknown    term=italic cterm=italic gui=italic
hi def hexDataOdd             term=bold cterm=bold gui=bold
hi def hexDataEven            term=NONE cterm=NONE gui=NONE
hi def link hexDataUnexpected      Error
hi def link hexExtendedAddress     hexDataAddress
hi def link hexStartAddress        hexDataAddress
hi def link hexChecksum            DiffChange


let b:current_syntax = "hex"

" vim: ts=8
