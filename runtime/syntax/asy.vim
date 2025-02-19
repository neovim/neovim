" Vim syntax file
" Language:     Asymptote
" Maintainer:   Avid Seeker <avidseeker7@protonmail.com>
"               Andy Hammerlindl
" Last Change:  2022 Jan 05

" Hacked together from Bram Moolenaar's C syntax file, and Claudio Fleiner's
" Java syntax file.

if exists("b:current_syntax")
  finish
endif

" useful C/C++/Java keywords
syn keyword     asyStatement     break return continue unravel
syn keyword     asyConditional   if else
syn keyword     asyRepeat        while for do
syn keyword     asyExternal      access from import include
syn keyword     asyOperator      new operator

" basic asymptote keywords
syn keyword     asyConstant      VERSION
syn keyword     asyConstant      true false default infinity inf nan
syn keyword     asyConstant      null nullframe nullpath nullpen
syn keyword     asyConstant      intMin intMax realMin realMax
syn keyword     asyConstant      realEpsilon realDigits
syn keyword     asyPathSpec      and cycle controls tension atleast curl
syn keyword     asyStorageClass  static public restricted private explicit
syn keyword     asyStructure     struct typedef
syn keyword     asyType          void bool bool3 int real string file
syn keyword     asyType          pair triple transform guide path pen frame
syn keyword     asyType          picture

" module specific keywords
if exists("asy_syn_plain")
  syn keyword   asyConstant      currentpicture currentpen defaultpen
  syn keyword   asyConstant      inch inches cm mm bp pt up down right left
  syn keyword   asyConstant      E NE N NW W SW S SE
  syn keyword   asyConstant      ENE NNE NNW WNW WSW SSW SSE ESE
  syn keyword   asyConstant      I pi twopi
  syn keyword   asyConstant      CCW CW
  syn keyword   asyConstant      undefined sqrtEpsilon Align mantissaBits
  syn keyword   asyConstant      identity zeroTransform invert
  syn keyword   asyConstant      stdin stdout
  syn keyword   asyConstant      unitsquare unitcircle circleprecision
  syn keyword   asyConstant      solid dotted Dotted dashed dashdotted
  syn keyword   asyConstant      longdashed longdashdotted
  syn keyword   asyConstant      squarecap roundcap extendcap
  syn keyword   asyConstant      miterjoin roundjoin beveljoin
  syn keyword   asyConstant      zerowinding evenodd basealign nobasealign
  syn keyword   asyConstant      black white gray red green blue Cyan Magenta
  syn keyword   asyConstant      Yellow Black cyan magenta yellow palered
  syn keyword   asyConstant      palegreen paleblue palecyan palemagenta
  syn keyword   asyConstant      paleyellow palegray lightred lightgreen
  syn keyword   asyConstant      lightblue lightcyan lightmagenta lightyellow
  syn keyword   asyConstant      lightgray mediumred mediumgreen mediumblue
  syn keyword   asyConstant      mediumcyan mediummagenta mediumyellow
  syn keyword   asyConstant      mediumgray heavyred heavygreen heavyblue
  syn keyword   asyConstant      heavycyan heavymagenta lightolive heavygray
  syn keyword   asyConstant      deepred deepgreen deepblue deepcyan
  syn keyword   asyConstant      deepmagenta deepyellow deepgray darkred
  syn keyword   asyConstant      darkgreen darkblue darkcyan darkmagenta
  syn keyword   asyConstant      darkolive darkgray orange fuchsia chartreuse
  syn keyword   asyConstant      springgreen purple royalblue salmon brown
  syn keyword   asyConstant      olive darkbrown pink palegrey lightgrey
  syn keyword   asyConstant      mediumgrey grey heavygrey deepgrey darkgrey

  if exists("asy_syn_texcolors")
    syn keyword asyConstant      GreenYellow Yellow Goldenrod Dandelion
    syn keyword asyConstant      Apricot Peach Melon YellowOrange Orange
    syn keyword asyConstant      BurntOrange Bittersweet RedOrange Mahogany
    syn keyword asyConstant      Maroon BrickRed Red OrangeRed RubineRed
    syn keyword asyConstant      WildStrawberry Salmon CarnationPink Magenta
    syn keyword asyConstant      VioletRed Rhodamine Mulberry RedViolet
    syn keyword asyConstant      Fuchsia Lavender Thistle Orchid DarkOrchid
    syn keyword asyConstant      Purple Plum Violet RoyalPurple BlueViolet
    syn keyword asyConstant      Periwinkle CadetBlue CornflowerBlue
    syn keyword asyConstant      MidnightBlue NavyBlue RoyalBlue Blue
    syn keyword asyConstant      Cerulean Cyan ProcessBlue SkyBlue Turquoise
    syn keyword asyConstant      TealBlue Aquamarine BlueGreen Emerald
    syn keyword asyConstant      JungleGreen SeaGreen Green ForestGreen
    syn keyword asyConstant      PineGreen LimeGreen YellowGreen SpringGreen
    syn keyword asyConstant      OliveGreen RawSienna Sepia Brown Tan Gray
    syn keyword asyConstant      Black White
  endif

  if exists("asy_syn_x11colors")
    syn keyword asyConstant      AliceBlue AntiqueWhite Aqua Aquamarine Azure
    syn keyword asyConstant      Beige Bisque Black BlanchedAlmond Blue
    syn keyword asyConstant      BlueViolet Brown BurlyWood CadetBlue
    syn keyword asyConstant      Chartreuse Chocolate Coral CornflowerBlue
    syn keyword asyConstant      Cornsilk Crimson Cyan DarkBlue DarkCyan
    syn keyword asyConstant      DarkGoldenrod DarkGray DarkGreen DarkKhaki
    syn keyword asyConstant      DarkMagenta DarkOliveGreen DarkOrange
    syn keyword asyConstant      DarkOrchid DarkRed DarkSalmon DarkSeaGreen
    syn keyword asyConstant      DarkSlateBlue DarkSlateGray DarkTurquoise
    syn keyword asyConstant      DarkViolet DeepPink DeepSkyBlue DimGray
    syn keyword asyConstant      DodgerBlue FireBrick FloralWhite ForestGreen
    syn keyword asyConstant      Fuchsia Gainsboro GhostWhite Gold Goldenrod
    syn keyword asyConstant      Gray Green GreenYellow Honeydew HotPink
    syn keyword asyConstant      IndianRed Indigo Ivory Khaki Lavender
    syn keyword asyConstant      LavenderBlush LawnGreen LemonChiffon
    syn keyword asyConstant      LightBlue LightCoral LightCyan
    syn keyword asyConstant      LightGoldenrodYellow LightGreen LightGrey
    syn keyword asyConstant      LightPink LightSalmon LightSeaGreen
    syn keyword asyConstant      LightSkyBlue LightSlateGray LightSteelBlue
    syn keyword asyConstant      LightYellow Lime LimeGreen Linen Magenta
    syn keyword asyConstant      Maroon MediumAquamarine MediumBlue
    syn keyword asyConstant      MediumOrchid MediumPurple MediumSeaGreen
    syn keyword asyConstant      MediumSlateBlue MediumSpringGreen
    syn keyword asyConstant      MediumTurquoise MediumVioletRed MidnightBlue
    syn keyword asyConstant      MintCream MistyRose Moccasin NavajoWhite
    syn keyword asyConstant      Navy OldLace Olive OliveDrab Orange
    syn keyword asyConstant      OrangeRed Orchid PaleGoldenrod PaleGreen
    syn keyword asyConstant      PaleTurquoise PaleVioletRed PapayaWhip
    syn keyword asyConstant      PeachPuff Peru Pink Plum PowderBlue Purple
    syn keyword asyConstant      Red RosyBrown RoyalBlue SaddleBrown Salmon
    syn keyword asyConstant      SandyBrown SeaGreen Seashell Sienna Silver
    syn keyword asyConstant      SkyBlue SlateBlue SlateGray Snow SpringGreen
    syn keyword asyConstant      SteelBlue Tan Teal Thistle Tomato Turquoise
    syn keyword asyConstant      Violet Wheat White WhiteSmoke Yellow
    syn keyword asyConstant      YellowGreen
  endif

  if exists("asy_syn_three")
    syn keyword asyType          path3 guide3 transform3
    syn keyword asyType          projection light material patch surface tube
    syn keyword asyConstant      currentprojection currentlight defaultrender
    syn keyword asyConstant      identity4 O X Y Z
    syn keyword asyConstant      nolight nullpens
    syn keyword asyConstant      unitsphere unithemisphere unitplane octant1
    syn keyword asyConstant      unitcone unitsolidcone unitcube unitcylinder
    syn keyword asyConstant      unitdisk unittube
  endif
endif


" string constants
syn region asyCString start=+'+ end=+'+ skip=+\\\\\|\\'+ contains=asyCSpecial
syn match  asyCSpecial display contained +\\\(['"?\\abfnrtv]\|\o\{1,3}\)+
syn match  asyCSpecial display contained +\\\(x[0-9A-F]\{1,2\}\|$\)+
" double quoted strings only special character is \"
syn region asyString   start=+"+ end=+"+ skip=+\\\\\|\\"+ contains=asySpecial
syn match  asySpecial  display contained +\(\\\)\@1<!\(\\\\\)*\zs\\"+


" number constants
syn match  asyNumbers     display transparent "\<\d\|\.\d"
                        \ contains=asyNumber,asyNumberError
syn match  asyNumber      display contained "\d*\.\=\d*\(e[-+]\=\d\+\)\="
" highlight number constants with two '.' or with '.' after an 'e'
syn match  asyNumberError display contained "\d*\.\(\d\|e[-+]\=\)*\.[0-9.]*"
syn match  asyNumberError display contained "\d*e[-+]\=\d*\.[0-9.]*"
syn match  asyNumberError display contained "\d*e[-+]\=\(e[-+]\=\)*\.[0-9.]*"


" comments and comment strings
syn keyword  asyTodo            contained TODO FIXME XXX
syn sync     ccomment           asyComment minlines=15
if exists("asy_comment_strings")
  " A comment can contain asyString, asyCString, and asyNumber. But a "*/"
  " inside a asy*String in a asyComment DOES end the comment!  So we need to
  " use a special type of asy*String: asyComment*String, which also ends on
  " "*/", and sees a "*" at the start of the line as comment again.
  " Unfortunately this doesn't very well work for // type of comments :-(
  syn match  asyCommentSkip     contained "^\s*\*\($\|\s\+\)"
  syn region asyCommentString   contained start=+"+ skip=+\\\\\|\\"+ end=+"+
                              \ end=+\*/+me=s-1
                              \ contains=asySpecial,asyCommentSkip
  syn region asyCommentCString  contained start=+'+ skip=+\\\\\|\\'+ end=+'+
                              \ end=+\*/+me=s-1
                              \ contains=asyCSpecial,asyCommentSkip
  syn region asyCommentLString  contained start=+"+ skip=+\\\\\|\\"+ end=+"+
                              \ end="$" contains=asySpecial
  syn region asyCommentLCString contained start=+'+ skip=+\\\\\|\\'+ end=+'+
                              \ end="$" contains=asyCSpecial
  syn region asyCommentL        start="//" skip="\\$" end="$" keepend
                              \ contains=asyTodo,asyCommentLString,
                              \ asyCommentLCString,asyNumbers
  syn region asyComment         matchgroup=asyComment start="/\*" end="\*/"
                              \ contains=asyTodo,asyCommentStartError,
                              \ asyCommentString,asyCommentCString,asyNumbers
else
  syn region asyCommentL        start="//" skip="\\$" end="$" keepend
                              \ contains=asyTodo
  syn region asyComment         matchgroup=asyComment start="/\*" end="\*/"
                              \ contains=asyTodo,asyCommentStartError
endif

" highlight common errors when starting/ending C comments
syn match    asyCommentError      display "\*/"
syn match    asyCommentStartError display "/\*"me=e-1 contained


" delimiter matching errors
syn region asyCurly      transparent start='{'  end='}'
                       \ contains=TOP,asyCurlyError
syn region asyBrack      transparent start='\[' end='\]' matchgroup=asyError
                       \ end=';' contains=TOP,asyBrackError
syn region asyParen      transparent start='('  end=')'  matchgroup=asyError
                       \ end=';' contains=TOP,asyParenError
syn match  asyCurlyError display '}'
syn match  asyBrackError display '\]'
syn match  asyParenError display ')'
" for (;;) constructs are exceptions that allow ; inside parenthesis
syn region asyParen      transparent matchgroup=asyParen
                       \ start='\(for\s*\)\@<=(' end=')'
                       \ contains=TOP,asyParenError

" Define the default highlighting.
hi def link asyCommentL             asyComment
hi def link asyConditional          Conditional
hi def link asyRepeat               Repeat
hi def link asyNumber               Number
hi def link asyNumberError          asyError
hi def link asyCurlyError           asyError
hi def link asyBracketError         asyError
hi def link asyParenError           asyError
hi def link asyCommentError         asyError
hi def link asyCommentStartError    asyError
hi def link asyOperator             Operator
hi def link asyStructure            Structure
hi def link asyStorageClass         StorageClass
hi def link asyExternal             Include
hi def link asyDefine               Macro
hi def link asyError                Error
hi def link asyStatement            Statement
hi def link asyType                 Type
hi def link asyConstant             Constant
hi def link asyCommentString        asyString
hi def link asyCommentCString       asyString
hi def link asyCommentLString       asyString
hi def link asyCommentLCString      asyString
hi def link asyCommentSkip          asyComment
hi def link asyString               String
hi def link asyCString              String
hi def link asyComment              Comment
hi def link asySpecial              SpecialChar
hi def link asyCSpecial             SpecialChar
hi def link asyTodo                 Todo
hi def link asyPathSpec             Statement

let b:current_syntax = "asy"
