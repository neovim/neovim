" Vim syntax file
" Language:             BDF font definition
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn region  bdfFontDefinition transparent matchgroup=bdfKeyword
                              \ start='^STARTFONT\>' end='^ENDFONT\>'
                              \ contains=bdfComment,bdfFont,bdfSize,
                              \ bdfBoundingBox,bdfProperties,bdfChars,bdfChar

syn match   bdfNumber         contained display
                              \ '\<\%(\x\+\|[+-]\=\d\+\%(\.\d\+\)*\)'

syn keyword bdfTodo           contained FIXME TODO XXX NOTE

syn region  bdfComment        contained start='^COMMENT\>' end='$'
                              \ contains=bdfTodo,@Spell

syn region  bdfFont           contained matchgroup=bdfKeyword
                              \ start='^FONT\>' end='$'

syn region  bdfSize           contained transparent matchgroup=bdfKeyword
                              \ start='^SIZE\>' end='$' contains=bdfNumber

syn region  bdfBoundingBox    contained transparent matchgroup=bdfKeyword
                              \ start='^FONTBOUNDINGBOX' end='$'
                              \ contains=bdfNumber

syn region  bdfProperties     contained transparent matchgroup=bdfKeyword
                              \ start='^STARTPROPERTIES' end='^ENDPROPERTIES'
                              \ contains=bdfNumber,bdfString,bdfProperty,
                              \ bdfXProperty

syn keyword bdfProperty       contained FONT_ASCENT FONT_DESCENT DEFAULT_CHAR
syn match   bdfProperty       contained '^\S\+'

syn keyword bdfXProperty      contained FONT_ASCENT FONT_DESCENT DEFAULT_CHAR
                              \ FONTNAME_REGISTRY FOUNDRY FAMILY_NAME
                              \ WEIGHT_NAME SLANT SETWIDTH_NAME PIXEL_SIZE
                              \ POINT_SIZE RESOLUTION_X RESOLUTION_Y SPACING
                              \ CHARSET_REGISTRY CHARSET_ENCODING COPYRIGHT
                              \ ADD_STYLE_NAME WEIGHT RESOLUTION X_HEIGHT
                              \ QUAD_WIDTH FONT AVERAGE_WIDTH

syn region  bdfString         contained start=+"+ skip=+""+ end=+"+

syn region  bdfChars          contained display transparent
                              \ matchgroup=bdfKeyword start='^CHARS' end='$'
                              \ contains=bdfNumber

syn region  bdfChar           transparent matchgroup=bdfKeyword
                              \ start='^STARTCHAR' end='^ENDCHAR'
                              \ contains=bdfEncoding,bdfWidth,bdfAttributes,
                              \ bdfBitmap

syn region  bdfEncoding       contained transparent matchgroup=bdfKeyword
                              \ start='^ENCODING' end='$' contains=bdfNumber

syn region  bdfWidth          contained transparent matchgroup=bdfKeyword
                              \ start='^SWIDTH\|DWIDTH\|BBX' end='$'
                              \ contains=bdfNumber

syn region  bdfAttributes     contained transparent matchgroup=bdfKeyword
                              \ start='^ATTRIBUTES' end='$'

syn keyword bdfBitmap         contained BITMAP

if exists("bdf_minlines")
  let b:bdf_minlines = bdf_minlines
else
  let b:bdf_minlines = 30
endif
exec "syn sync ccomment bdfChar minlines=" . b:bdf_minlines


hi def link bdfKeyword        Keyword
hi def link bdfNumber         Number
hi def link bdfTodo           Todo
hi def link bdfComment        Comment
hi def link bdfFont           String
hi def link bdfProperty       Identifier
hi def link bdfXProperty      Identifier
hi def link bdfString         String
hi def link bdfChars          Keyword
hi def link bdfBitmap         Keyword

let b:current_syntax = "bdf"

let &cpo = s:cpo_save
unlet s:cpo_save
