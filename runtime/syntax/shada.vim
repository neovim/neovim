if exists("b:current_syntax")
    finish
endif

syntax match ShaDaEntryHeader
      \ '^\u.\{-} with timestamp \d\{4}-\d\d-\d\dT\d\d:\d\d:\d\d:$'
syntax match ShaDaEntryName '^\u.\{-}\ze with' contained
      \ containedin=ShaDaEntryHeader
syntax match ShaDaEntryTimestamp 'timestamp \zs\d\{4}-\d\d-\d\dT\d\d:\d\d:\d\d'
      \ contained containedin=ShaDaEntryHeader
syntax match ShaDaEntryTimestampNumber '\d\+' contained
      \ containedin=ShaDaEntryTimestamp

syntax match ShaDaComment '^\s*#.*$'

syntax region ShaDaEntryMapLong start='^  % Key_*  Description_*  Value$'
      \ end='^  %\|^\S'me=s-1 contains=ShaDaComment,ShaDaEntryMapLongEntryStart
syntax region ShaDaEntryMapShort start='^  % Key_*  Value$'
      \ end='^  %\|^\S'me=s-1 contains=ShaDaComment,ShaDaEntryMapShortEntryStart
syntax match ShaDaEntryMapHeader '^  % Key_*  \(Description_*  \)\?Value$'
      \ contained containedin=ShaDaEntryMapLong,ShaDaEntryMapShort
syntax match ShaDaEntryMapLongEntryStart '^  + 'hs=e-2,he=e-1
      \ nextgroup=ShaDaEntryMapLongKey
syntax match ShaDaEntryMapLongKey '\S\+  \+\ze\S'he=e-2 contained
      \ nextgroup=ShaDaEntryMapLongDescription
syntax match ShaDaEntryMapLongDescription '.\{-}  \ze\S'he=e-2 contained
      \ nextgroup=@ShaDaEntryMsgpackValue
syntax match ShaDaEntryMapShortEntryStart '^  + 'hs=e-2,he=e-1 contained
      \ nextgroup=ShaDaEntryMapShortKey
syntax match ShaDaEntryMapShortKey '\S\+  \+\ze\S'he=e-2 contained
      \ nextgroup=@ShaDaEntryMsgpackValue
syntax match ShaDaEntryMapBinArrayStart '^  | - 'hs=e-4,he=e-1 contained
      \ containedin=ShaDaEntryMapLong,ShaDaEntryMapShort
      \ nextgroup=@ShaDaEntryMsgpackValue

syntax region ShaDaEntryArray start='^  @ Description_*  Value$'
      \ end='^\S'me=s-1 keepend
      \ contains=ShaDaComment,ShaDaEntryArrayEntryStart,ShaDaEntryArrayHeader
syntax match ShaDaEntryArrayHeader '^  @ Description_*  Value$' contained
syntax match ShaDaEntryArrayEntryStart '^  - 'hs=e-2,he=e-1
      \ nextgroup=ShaDaEntryArrayDescription
syntax match ShaDaEntryArrayDescription '.\{-}  \ze\S'he=e-2 contained
      \ nextgroup=@ShaDaEntryMsgpackValue

syntax match ShaDaEntryRawMsgpack '^  = ' nextgroup=@ShaDaEntryMsgpackValue

syntax cluster ShaDaEntryMsgpackValue
      \ add=ShaDaMsgpackKeyword,ShaDaMsgpackShaDaKeyword
      \ add=ShaDaMsgpackInteger,ShaDaMsgpackCharacter,ShaDaMsgpackFloat
      \ add=ShaDaMsgpackBinaryString,ShaDaMsgpackString,ShaDaMsgpackExt
      \ add=ShaDaMsgpackArray,ShaDaMsgpackMap
      \ add=ShaDaMsgpackMultilineArray
syntax keyword ShaDaMsgpackKeyword contained NIL TRUE FALSE
syntax keyword ShaDaMsgpackShaDaKeyword contained
      \ CMD SEARCH EXPR INPUT DEBUG
      \ CHARACTERWISE LINEWISE BLOCKWISE
syntax region ShaDaMsgpackBinaryString matchgroup=ShaDaMsgpackStringQuotes
      \ start='"' skip='\\"' end='"' contained keepend
syntax match ShaDaMsgpackBinaryStringEscape '\\[\\0n"]'
      \ contained containedin=ShaDaMsgpackBinaryString
syntax match ShaDaMsgpackString '=' contained nextgroup=ShaDaMsgpackBinaryString
syntax match ShaDaMsgpackExt '+(-\?\d\+)' contained
      \ nextgroup=ShaDaMsgpackBinaryString
syntax match ShaDaMsgpackExtType '-\?\d\+' contained containedin=ShaDaMsgpackExt
syntax match ShaDaMsgpackCharacter /'.'/ contained
syntax match ShaDaMsgpackInteger '-\?\%(0x\x\{,16}\|\d\+\)' contained
syntax match ShaDaMsgpackFloat '-\?\d\+\.\d\+\%(e[+-]\?\d\+\)\?' contained
syntax region ShaDaMsgpackArray matchgroup=ShaDaMsgpackArrayBraces
      \ start='\[' end='\]' contained
      \ contains=@ShaDaEntryMsgpackValue,ShaDaMsgpackComma
syntax region ShaDaMsgpackMap matchgroup=ShaDaMsgpackMapBraces
      \ start='{' end='}' contained
      \ contains=@ShaDaEntryMsgpackValue,ShaDaMsgpackComma,ShaDaMsgpackColon
syntax match ShaDaMsgpackComma ',' contained
syntax match ShaDaMsgpackColon ':' contained
syntax match ShaDaMsgpackMultilineArray '@' contained

hi def link ShaDaComment Comment
hi def link ShaDaEntryNumber Number
hi def link ShaDaEntryTimestamp Operator
hi def link ShaDaEntryName Keyword

hi def link ShaDaEntryMapHeader PreProc

hi def link ShaDaEntryMapEntryStart Label
hi def link ShaDaEntryMapLongEntryStart ShaDaEntryMapEntryStart
hi def link ShaDaEntryMapShortEntryStart ShaDaEntryMapEntryStart
hi def link ShaDaEntryMapBinArrayStart ShaDaEntryMapEntryStart
hi def link ShaDaEntryArrayEntryStart ShaDaEntryMapEntryStart

hi def link ShaDaEntryMapKey String
hi def link ShaDaEntryMapLongKey ShaDaEntryMapKey
hi def link ShaDaEntryMapShortKey ShaDaEntryMapKey

hi def link ShaDaEntryMapDescription Comment
hi def link ShaDaEntryMapLongDescription ShaDaEntryMapDescription
hi def link ShaDaEntryMapShortDescription ShaDaEntryMapDescription

hi def link ShaDaEntryArrayHeader PreProc

hi def link ShaDaEntryArrayDescription ShaDaEntryMapDescription

hi def link ShaDaMsgpackKeyword Keyword
hi def link ShaDaMsgpackShaDaKeyword ShaDaMsgpackKeyword
hi def link ShaDaMsgpackCharacter Character
hi def link ShaDaMsgpackInteger Number
hi def link ShaDaMsgpackFloat Float

hi def link ShaDaMsgpackBinaryString String
hi def link ShaDaMsgpackBinaryStringEscape SpecialChar
hi def link ShaDaMsgpackExtType Typedef

hi def link ShaDaMsgpackStringQuotes Operator
hi def link ShaDaMsgpackString ShaDaMsgpackStringQuotes
hi def link ShaDaMsgpackExt ShaDaMsgpackStringQuotes

hi def link ShaDaMsgpackMapBraces Operator
hi def link ShaDaMsgpackArrayBraces ShaDaMsgpackMapBraces

hi def link ShaDaMsgpackComma Operator
hi def link ShaDaMsgpackColon ShaDaMsgpackComma

hi def link ShaDaMsgpackMultilineArray Operator

let b:current_syntax = "shada"
