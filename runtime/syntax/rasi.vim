" Vim syntax file
" Language:	rasi (Rofi Advanced Style Information)
" Maintainer:	Pierrick Guillaume  <pierguill@gmail.com>
" Last Change:	2024 May 21
"
" Syntax support for rasi config file

" This file is based on syntax defined in rofi-theme man page
" https://man.archlinux.org/man/community/rofi/rofi-theme.5.en

if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'rasi'

" String {{{
syn region rasiString    start=+"+ skip=+\\"+ end=+"+ oneline contained
syn match  rasiCharacter +L\='[^\\]'+ contained

syn cluster rasiPropertyVals add=rasiString,rasiCharacter
" }}}

" Integer/Real {{{
syn match rasiNumber  display contained '[+-]\?\d\+\(\.\d\+\)\?'

syn cluster rasiPropertyVals add=rasiNumber
" }}}

" Boolean {{{
syn keyword rasiBool  contained true false

syn cluster rasiPropertyVals add=rasiBool
" }}}

" Image {{{
syn match rasiInvImage        display contained 'url([^)]*)'
syn keyword rasiImageK        contained url linear-gradient

syn match rasiImage           display contained transparent 'url(\s*"\([^"]\|\\"\)\+"\(\s*,\s*\(none\|both\|width\|height\)\)\?\s*)' contains=rasiImageScale,rasiString,rasiImageK
syn keyword rasiImageScale  contained none both width height

syn match rasiImage           display contained transparent 'linear-gradient(\s*\(\(top\|left\|right\|bottom\)\s*,\s*\)\?[^,)]\+\s*\(,\s*[^,)]\+\s*\)\+)' contains=rasiImageDirection,@rasiColors,rasiImageK
syn keyword rasiImageDirection contained top left right bottom

syn match rasiImage           display contained transparent 'linear-gradient(\s*\d\+\(rad\|grad\|deg\)\s*,\s*[^,)]\+\s*\(,\s*[^,)]\+\s*\)\+)' contains=rasiImageUnit,@rasiColor,@rasiInvColor,rasiNumber,rasiImageK
syn match rasiImageUnit       display contained '\(rad\|grad\|deg\)\>'

syn cluster rasiPropertyVals  add=rasiInvImage,rasiImage
" }}}

" Reference {{{
syn match rasiReference       display contained '@[a-zA-Z0-9-]\+'

syn keyword rasiVarReferenceK contained var

syn match rasiInvVarReference display contained 'var([^)]*)'
syn match rasiVarReference    display contained transparent 'var(\s*[a-zA-Z0-9-]\+\s*,\s*\(\a\+\s*([^)]*)\)\?[^),]*)' contains=rasiVarReferenceK,rasiPropertyIdRef,@rasiPropertyVals
syn match rasiPropertyIdRef   display contained '\a[a-zA-Z0-9-]*'

syn cluster rasiPropertyVals  add=rasiReference,rasiInvVarReference,rasiVarReference
" }}}

" Env variable {{{
syn match rasiInvEnv          display contained '${[^}]*}'
syn match rasiEnv             display contained '${\w\+}'hs=s+2,he=e-1

syn keyword rasiEnvVarK       contained env

syn match rasiInvEnvVar       display contained 'env([^)]*)'
syn match rasiEnvVar          display contained transparent 'env(\s*\w\+\s*,\s*\(\a\+([^)]*)\)\?[^),]*)' contains=rasiEnvVarK,rasiEnvRef,@rasiPropertyVals
syn match rasiEnvRef          display contained '\a\w*'

syn cluster rasiPropertyVals  add=rasiEnv,rasiInvEnv,rasiInvEnvVar,rasiEnvVar
" }}}

" Color {{{
syn keyword rasiColorK        contained rgb[a] hsl[a] hwb[a] cmyk

syn match rasiHexColor        display contained '#\x\{3,4}'
syn match rasiHexColor        display contained '#\x\{6}'
syn match rasiHexColor        display contained '#\x\{8}'
syn match rasiInvHexColor     display contained '#\x\{5}\X'he=e-1,me=e-1
syn match rasiInvHexColor     display contained '#\x\{7}\X'he=e-1,me=e-1

syn match rasiInvRGBColor     display contained 'rgb\(a\)\?([^)]*)'
syn match rasiRGBColor        display contained transparent 'rgb\(a\)\?(\s*\d\+\s*\(%\)\?\s*,\(\s*\d\+\s*\(%\)\?\s*\){2}\(,\s*\(\d\(\.\d*\)\?\|\d\{,3}%\)\s*\)\?)' contains=rasiColorK,rasiNumber,rasiDistance

syn match rasiInvHSLColor     display contained 'h\(sl\|wb\)\(a\)\?([^)]*)'
syn match rasiHSLColor        display contained transparent 'h\(sl\|wb\)\(a\)\?(\s*\d\+\(\.\d*\)\?\(deg\|rad\|grad\|turn\)\?\s*\(,\s*\(\d\(\.\d*\)\?\|\d\{,3}%\)\s*\)\{2,3})' contains=rasiColorK,rasiNumber,rasiDistance


"this matches doesn't works properly (too long ?)
syn match rasiInvCMYKColor  display contained 'cmyk([^)]*)'
syn match rasiCMYKColor     display contained transparent 'cmyk(\s*\(\d\(\.\d*\)\?\|\d\{,3}%\)\s*\(,\s*\(\d\(\.\d*\)\?\|\d\{,3}%\)\s*\)\{3,4})' contains=rasiColorK,rasiNumber,rasiDistance

syn case ignore
syn keyword rasiNamedColor contained
      \ AliceBlue AntiqueWhite Aqua Aquamarine Azure Beige Bisque Black BlanchedAlmond Blue
      \ BlueViolet Brown BurlyWood CadetBlue Chartreuse Chocolate Coral CornflowerBlue Cornsilk
      \ Crimson Cyan DarkBlue DarkCyan DarkGoldenRod DarkGray DarkGrey DarkGreen DarkKhaki DarkMagenta
      \ DarkOliveGreen DarkOrange DarkOrchid DarkRed DarkSalmon DarkSeaGreen Dark SlateBlue
      \ DarkSlateGray DarkSlateGrey DarkTurquoise DarkViolet DeepPink DeepSkyBlue DimGray DimGrey
      \ DodgerBlue FireBrick FloralWhite ForestGreen Fuchsia Gainsboro GhostWhite Gold GoldenRod
      \ Gray Grey Green GreenYellow HoneyDew HotPink IndianRed Indigo Ivory Khaki Lavender
      \ LavenderBlush LawnGreen LemonChiffon LightBlue LightCoral LightCyan LightGoldenRodYellow
      \ LightGray LightGrey LightGreen LightPink LightSalmon LightSeaGreen LightSkyBlue LightSlateGray
      \ LightSlateGrey LightSteelBlue LightYellow Lime LimeGreen Linen Magenta Maroon MediumAquaMarine
      \ MediumBlue MediumOrchid MediumPurple MediumSeaGreen MediumSlateBlue MediumSpringGreen
      \ MediumTurquoise MediumVioletRed MidnightBlue MintCream MistyRose Moccasin NavajoWhite Navy
      \ OldLace Olive OliveDrab Orange OrangeRed Orchid PaleGoldenRod PaleGreen PaleTurquoise
      \ PaleVioletRed PapayaWhip PeachPuff Peru Pink Plum PowderBlue Purple RebeccaPurple Red
      \ RosyBrown RoyalBlue SaddleBrown Salmon SandyBrown SeaGreen SeaShell Sienna Silver SkyBlue
      \ SlateBlue SlateGray SlateGrey Snow SpringGreen SteelBlue Tan Teal Thistle Tomato Turquoise
      \ Violet Wheat White WhiteSmoke Yellow YellowGreen transparent[] "uses `[]` to escape keyword

syn cluster rasiColors        add=rasiHexColor,rasiRGBColor,rasiHSLColor,rasiCMYKColor,rasiNamedColor
syn cluster rasiColors        add=rasiInvHexColor,rasiInvRGBColor,rasiInvHSLColor,rasiInvCMYKColor

syn cluster rasiPropertyVals  add=@rasiColors
" }}}

" Text-Style {{{
syn keyword rasiTextStyle contained bold italic underline strikethrough none

syn cluster rasiPropertyVals  add=rasiTextStyle
" }}}

" Line-Style {{{
syn keyword rasiLineStyle contained dash solid

syn cluster rasiPropertyVals  add=rasiLineStyle
" }}}

" Distance {{{
syn match rasiDistanceUnit    display contained '\(px\|em\|ch\|%\|mm\)'

syn match rasiInvDistance     display contained '[+-]\?\d\+\.\d\+\(px\|mm\)'
syn match rasiDistance        display contained transparent '[-+]\?\d\+\(px\|mm\)' contains=rasiDistanceUnit,rasiNumber
syn match rasiDistance        display contained transparent '[+-]\?\d\+\(\.\d\+\)\?\(em\|ch\|%\)' contains=rasiDistanceUnit,rasiNumber

syn keyword rasiDistanceCalc  contained calc nextgroup=rasiDistanceCalcBody
syn region rasiDistanceCalcBody display contained start=+(+ end=+)+ contains=rasiDistanceCalcOp,rasiDistance,rasiInvDistance
syn match rasiDistanceCalcOp  display contained '\(+\|-\|/\|\*\|%\|min\|max\)'

syn cluster rasiPropertyVals  add=rasiInvDistance,rasiDistance,rasiDistanceCalc
" }}}

" Position {{{
syn keyword rasiPosition    contained center east north west south

syn cluster rasiPropertyVals  add=rasiPosition
" }}}

" Orientation {{{
syn keyword rasiOrientation   contained horizontal vertical

syn cluster rasiPropertyVals  add=rasiOrientation
" }}}

" Cursor {{{
syn keyword rasiCursor        contained default pointer text

syn cluster rasiPropertyVals  add=rasiCursor
" }}}

" Keyword List {{{
syn region rasiKeywordList    contained start=+\[+ end=+\]+ contains=rasiPropertyIdRef

syn cluster rasiPropertyVals  add=rasiKeywordList
" }}}

" Inherit {{{
syn keyword rasiInherit       contained inherit children

syn cluster rasiPropertyVals  add=rasiInherit
" }}}

syn match rasiGlobalImport    display '^\s*@\(import\|theme\)' nextgroup=rasiString skipwhite

" Section {{{
" syn region rasiSection transparent start='^[^{]\+{'me=e-1 end='}' contains=rasiSectionOpenning,rasiSectionContent
syn match rasiSectionOpenning transparent '^[^{]\+{'me=e-1 contains=rasiGlobalSection,rasiWidgetName,rasiGlobalMedia nextgroup=rasiThemeSectionContent
" syn match rasiThemeInnerSectionOpenning transparent '^[^:${]\+{'me=e-1 contains=rasiWidgetName nextgroup=rasiThemeInnerSectionContent contained

syn match rasiGlobalMedia     display contained '^\s*@media' nextgroup=rasiInvMediaBody,rasiMediaBody skipwhite
syn match rasiInvMediaBody    display contained '([^)]*)'
syn match rasiMediaBody       display contained '(\s*[a-z-]\+\s*:\s*\d\+\(px\|mm\)\?\s*)' contains=rasiMediaK,rasiNumber,rasiDistance
syn keyword rasiMediaK        contained min-width max-width min-height max-height min-aspect-ratio max-aspect-ratio monitor-id

syn match rasiGlobalSection   display contained '^*'
syn match rasiWidgetName      display contained '[a-zA-Z0-9-]\+' nextgroup=rasiVisibleMod skipwhite

syn keyword rasiVisibleMod    contained normal selected alternate nextgroup=rasiVisibleMod,rasiStateWrapper skipwhite
syn match rasiStateWrapper    display contained transparent '\.\(normal\|active\|urgent\)' contains=rasiState
syn keyword rasiState         contained normal active urgent


syn region  rasiThemeSectionContent transparent start="{" end="}" contains=rasiProperty,rasiComment,rasiCommentL,rasiSectionOpenning contained
" syn region  rasiThemeInnerSectionContent transparent start="{" end="}" contains=rasiProperty,rasiComment,rasiCommentL,rasiThemeInnerSectionOpenning contained

syn match rasiProperty transparent '^\s*\S\+\s*:.*;\s*$' keepend contained contains=rasiPropertyId,rasiInvPropertyId,rasiPropertyVal,rasiComment,rasiCommentL
syn match rasiInvPropertyId '^\([^:]\&[^/]\{2}\)*:'me=e-1 contained
syn match rasiPropertyId  '^\s*[0-9a-zA-Z-]\+\s*:'me=e-1 contained
syn match rasiInvPropertyVal ':[^;];\s*\S\+\s*$'ms=s+1,hs=s+1
syn match rasiPropertyVal ':\s*[^;]\+;\s*$'ms=s+1,hs=s+1 contained contains=@rasiPropertyVals
" }}}

" Comment {{{
syn cluster rasiCommentGroup  contains=rasiTodo,rasiBadContinuation

syn region rasiCommentL       start="//" skip="\\$" end="$" keepend contains=@rasiCommentGroup,@Spell
syn region rasiComment        start="/\*" end="\*/" contains=@rasiCommentGroup,rasiCommentStartError,@Spell fold extend

syn match rasiCommentError    display '\*/'

syn keyword rasiTodo          contained TODO FIXME XXX NOTE

if exists("rasi_minlines")
  let b:rasi_minlines = rasi_minlines
else
  let b:rasi_minlines = 50
endif
exec "syn sync ccomment rasiComment minlines=" . b:rasi_minlines
" }}}



" Highlighting: {{{
hi def link rasiError           Error

hi def link rasiTodo            Todo
hi def link rasiComment         Comment
hi def link rasiCommentStart    rasiComment
hi def link rasiCommentL        rasiComment
hi def link rasiCommentError    rasiError

hi def link rasiString          String
hi def link rasiNumber          Number
hi def link rasiBool            Boolean

hi def link rasiImageK          Function
hi def link rasiImageScale      Keyword
hi def link rasiImageDirection  Keyword
hi def link rasiImageUnit       Type
hi def link rasiInvImage        rasiError

hi def link rasiHexColor        Number
hi def link rasiColorK          Function
hi def link rasiNamedColor      Number
hi def link rasiInvColor        rasiError
hi def link rasiInvHexColor     rasiInvColor
hi def link rasiInvRGBColor     rasiInvColor
hi def link rasiInvHSLColor     rasiInvColor
hi def link rasiInvCMYKColor    rasiInvColor

hi def link rasiTextStyle       Keyword
hi def link rasiLineStyle       Keyword

hi def link rasiDistanceUnit    Type
hi def link rasiDistanceCalc    Function
hi def link rasiDistanceCalcOp  Operator
hi def link rasiInvDistance     rasiError

hi def link rasiPosition        Keyword
hi def link rasiOrientation     Keyword
hi def link rasiCursor          Keyword

hi def link rasiReference       Identifier
hi def link rasiPropertyIdRef   Identifier
hi def link rasiVarReferenceK   Function
hi def link rasiInvVarReference rasiError

hi def link rasiEnv             Identifier
hi def link rasiEnvRef          Identifier
hi def link rasiEnvVarK         Function
hi def link rasiInvEnv          rasiError
hi def link rasiInvEnvVar       rasiError

hi def link rasiWidgetName      StorageClass
hi def link rasiGlobalSection   StorageClass
hi def link rasiVisibleMod      Type
hi def link rasiState           Tag

hi def link rasiInherit         Identifier

hi def link rasiGlobalImport    Include

hi def link rasiGlobalMedia     Preproc
hi def link rasiMediaK          Keyword
hi def link rasiInvMediaBody    rasiError

hi def link rasiPropertyId      Identifier
hi def link rasiInvProperty     rasiError
hi def link rasiInvPropertyId   rasiError
hi def link rasiInvPropertyVal  rasiError
" }}}

" vim:ts=8
