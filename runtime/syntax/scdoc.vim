" Syntax file for scdoc files
" Maintainer: Gregory Anders <contact@gpanders.com>
" Last Updated: 2022-05-09
" Upstream: https://github.com/gpanders/vim-scdoc

if exists('b:current_syntax')
    finish
endif
let b:current_syntax = 'scdoc'

syntax match scdocFirstLineError "\%^.*$"
syntax match scdocFirstLineValid "\%^\S\+(\d[0-9A-Za-z]*)\%(\s\+\"[^"]*\"\%(\s\+\"[^"]*\"\)\=\)\=$"

syntax region scdocCommentError start="^;\S" end="$" keepend
syntax region scdocComment start="^; " end="$" keepend

syntax region scdocHeaderError start="^#\{3,}" end="$" keepend
syntax region scdocHeader start="^#\{1,2}" end="$" keepend

syntax match scdocIndentError "^[ ]\+"

syntax match scdocLineBreak "++$"

syntax region scdocOrderedListItem matchgroup=scdocOrderedListMarker start="^\z(\s*\)\." skip="^\z1  .*$" end="^" contains=scdocBold,scdocUnderline
syntax region scdocListItem matchgroup=scdocListMarker start="^\z(\s*\)-" skip="^\z1  .*$" end="^" contains=scdocBold,scdocUnderline

" Tables cannot start with a column
syntax match scdocTableError "^:"

syntax region scdocTable matchgroup=scdocTableEntry start="^[\[|\]][\[\-\]<=>]" end="^$" contains=scdocTableEntry,scdocTableError,scdocTableContinuation,scdocBold,scdocUnderline,scdocPre
syntax match scdocTableError "^.*$" contained
syntax match scdocTableContinuation "^   \+\S\+" contained
syntax match scdocTableEntry "^[|:][\[\-\]<=> ]" contained
syntax match scdocTableError "^[|:][\[\-\]<=> ]\S.*$" contained

syntax region scdocBold concealends matchgroup=scdocBoldDelimiter start="\\\@<!\*" end="\\\@<!\*"
syntax region scdocUnderline concealends matchgroup=scdocUnderlineDelimiter start="\<\\\@<!_" end="\\\@<!_\>"
syntax region scdocPre matchgroup=scdocPreDelimiter start="^\t*```" end="^\t*```"

syntax sync minlines=50

hi default link scdocFirstLineValid     Comment
hi default link scdocComment            Comment
hi default link scdocHeader             Title
hi default link scdocOrderedListMarker  Statement
hi default link scdocListMarker         scdocOrderedListMarker
hi default link scdocLineBreak          Special
hi default link scdocTableSpecifier     Statement
hi default link scdocTableEntry         Statement

hi default link scdocFirstLineError        Error
hi default link scdocCommentError          Error
hi default link scdocHeaderError           Error
hi default link scdocIndentError           Error
hi default link scdocTableError            Error
hi default link scdocTableError Error

hi default link scdocPreDelimiter       Delimiter

hi default scdocBold term=bold cterm=bold gui=bold
hi default scdocUnderline term=underline cterm=underline gui=underline
hi default link scdocBoldDelimiter scdocBold
hi default link scdocUnderlineDelimiter scdocUnderline
