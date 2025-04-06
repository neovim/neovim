" Vim syntax file
" Language: HLS Playlist
" Maintainer: Benoît Ryder <benoit@ryder.fr>
" Latest Revision: 2022-09-23

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Comment line
syn match  hlsplaylistComment  "^#\(EXT\)\@!.*$"
" Segment URL
syn match  hlsplaylistUrl      "^[^#].*$"

" Unknown tags, assume an attribute list or nothing
syn match  hlsplaylistTagUnknown    "^#EXT[^:]*$"
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagUnknown    start="^#EXT[^:]*\ze:"  end="$" keepend contains=hlsplaylistAttributeList

" Basic Tags
syn match  hlsplaylistTagHeader     "^#EXTM3U$"
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagHeader     start="^#EXT-X-VERSION\ze:"  end="$" keepend contains=hlsplaylistValueInt

" Media or Multivariant Playlist Tags
syn match  hlsplaylistTagHeader     "^#EXT-X-INDEPENDENT-SEGMENTS$"
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagDelimiter  start="^#EXT-X-START\ze:"  end="$" keepend contains=hlsplaylistAttributeList
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagStandard   start="^#EXT-X-DEFINE\ze:"  end="$" keepend contains=hlsplaylistAttributeList

" Media Playlist Tags
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagHeader     start="^#EXT-X-TARGETDURATION\ze:"  end="$" keepend contains=hlsplaylistValueFloat
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagHeader     start="^#EXT-X-MEDIA-SEQUENCE\ze:"  end="$" keepend contains=hlsplaylistValueInt
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagHeader     start="^#EXT-X-DISCONTINUITY-SEQUENCE\ze:"  end="$" keepend contains=hlsplaylistValueInt
syn match  hlsplaylistTagDelimiter  "^#EXT-X-ENDLIST$"
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagHeader     start="^#EXT-X-PLAYLIST-TYPE\ze:"  end="$" keepend contains=hlsplaylistAttributeEnum
syn match  hlsplaylistTagStandard   "^#EXT-X-I-FRAME-ONLY$"
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagHeader     start="^#EXT-X-PART-INF\ze:"  end="$" keepend contains=hlsplaylistAttributeList
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagHeader     start="^#EXT-X-SERVER-CONTROL\ze:"  end="$" keepend contains=hlsplaylistAttributeList

" Media Segment Tags
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagStatement  start="^#EXTINF\ze:"  end="$" keepend contains=hlsplaylistValueFloat,hlsplaylistExtInfDesc
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagStandard   start="^#EXT-X-BYTERANGE\ze:"  end="$" keepend contains=hlsplaylistValueInt
syn match  hlsplaylistTagDelimiter  "^#EXT-X-DISCONTINUITY$"
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagStandard   start="^#EXT-X-KEY\ze:"  end="$" keepend contains=hlsplaylistAttributeList
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagStandard   start="^#EXT-X-MAP\ze:"  end="$" keepend contains=hlsplaylistAttributeList
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagStandard   start="^#EXT-X-PROGRAM-DATE-TIME\ze:"  end="$" keepend contains=hlsplaylistValueDateTime
syn match  hlsplaylistTagDelimiter  "^#EXT-X-GAP$"
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagStandard   start="^#EXT-X-BITRATE\ze:"  end="$" keepend contains=hlsplaylistValueFloat
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagStatement  start="^#EXT-X-PART\ze:"  end="$" keepend contains=hlsplaylistAttributeList

" Media Metadata Tags
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagStandard   start="^#EXT-X-DATERANGE\ze:"  end="$" keepend contains=hlsplaylistAttributeList
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagStandard   start="^#EXT-X-SKIP\ze:"  end="$" keepend contains=hlsplaylistAttributeList
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagStatement  start="^#EXT-X-PRELOAD-HINT\ze:"  end="$" keepend contains=hlsplaylistAttributeList
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagStatement  start="^#EXT-X-RENDITION-REPORT\ze:"  end="$" keepend contains=hlsplaylistAttributeList

" Multivariant Playlist Tags
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagStandard   start="^#EXT-X-MEDIA\ze:"  end="$" keepend contains=hlsplaylistAttributeList
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagStatement  start="^#EXT-X-STREAM-INF\ze:"  end="$" keepend contains=hlsplaylistAttributeList
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagStatement  start="^#EXT-X-I-FRAME-STREAM-INF\ze:"  end="$" keepend contains=hlsplaylistAttributeList
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagStandard   start="^#EXT-X-SESSION-DATA\ze:"  end="$" keepend contains=hlsplaylistAttributeList
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagStandard   start="^#EXT-X-SESSION-KEY\ze:"  end="$" keepend contains=hlsplaylistAttributeList
syn region hlsplaylistTagLine matchgroup=hlsplaylistTagStandard   start="^#EXT-X-CONTENT-STEERING\ze:"  end="$" keepend contains=hlsplaylistAttributeList

" Attributes
syn region hlsplaylistAttributeList  start=":" end="$" keepend contained
  \ contains=hlsplaylistAttributeName,hlsplaylistAttributeInt,hlsplaylistAttributeHex,hlsplaylistAttributeFloat,hlsplaylistAttributeString,hlsplaylistAttributeEnum,hlsplaylistAttributeResolution,hlsplaylistAttributeUri
" Common attributes
syn match  hlsplaylistAttributeName        "[A-Za-z-]\+\ze=" contained
syn match  hlsplaylistAttributeEnum        "=\zs[A-Za-z][A-Za-z0-9-_]*" contained
syn match  hlsplaylistAttributeString      +=\zs"[^"]*"+ contained
syn match  hlsplaylistAttributeInt         "=\zs\d\+" contained
syn match  hlsplaylistAttributeFloat       "=\zs-\?\d*\.\d*" contained
syn match  hlsplaylistAttributeHex         "=\zs0[xX]\d*" contained
syn match  hlsplaylistAttributeResolution  "=\zs\d\+x\d\+" contained
" Allow different highligting for URI attributes
syn region hlsplaylistAttributeUri matchgroup=hlsplaylistAttributeName    start="\zsURI\ze" end="\(,\|$\)" contained contains=hlsplaylistUriQuotes
syn region hlsplaylistUriQuotes    matchgroup=hlsplaylistAttributeString  start=+"+ end=+"+ keepend contained contains=hlsplaylistUriValue
syn match  hlsplaylistUriValue             /[^" ]\+/ contained
" Individual values
syn match  hlsplaylistValueInt             "[0-9]\+" contained
syn match  hlsplaylistValueFloat           "\(\d\+\|\d*\.\d*\)" contained
syn match  hlsplaylistExtInfDesc           ",\zs.*$" contained
syn match  hlsplaylistValueDateTime        "\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d\(\.\d*\)\?\(Z\|\d\d:\?\d\d\)$" contained


" Define default highlighting

hi def link hlsplaylistComment  Comment
hi def link hlsplaylistUrl      NONE

hi def link hlsplaylistTagHeader     Special
hi def link hlsplaylistTagStandard   Define
hi def link hlsplaylistTagDelimiter  Delimiter
hi def link hlsplaylistTagStatement  Statement
hi def link hlsplaylistTagUnknown    Special

hi def link hlsplaylistUriQuotes            String
hi def link hlsplaylistUriValue             Underlined
hi def link hlsplaylistAttributeQuotes      String
hi def link hlsplaylistAttributeName        Identifier
hi def link hlsplaylistAttributeInt         Number
hi def link hlsplaylistAttributeHex         Number
hi def link hlsplaylistAttributeFloat       Float
hi def link hlsplaylistAttributeString      String
hi def link hlsplaylistAttributeEnum        Constant
hi def link hlsplaylistAttributeResolution  Constant
hi def link hlsplaylistValueInt             Number
hi def link hlsplaylistValueFloat           Float
hi def link hlsplaylistExtInfDesc           String
hi def link hlsplaylistValueDateTime        Constant


let b:current_syntax = "hlsplaylist"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: sts=2 sw=2 et
