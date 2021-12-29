" Vim syntax file
" Language:     PostScript - all Levels, selectable
" Maintainer:   Mike Williams <mrw@eandem.co.uk>
" Filenames:    *.ps,*.eps
" Last Change:  31st October 2007
" URL:          http://www.eandem.co.uk/mrw/vim
"
" Options Flags:
" postscr_level                 - language level to use for highlighting (1, 2, or 3)
" postscr_display               - include display PS operators
" postscr_ghostscript           - include GS extensions
" postscr_fonts                 - highlight standard font names (a lot for PS 3)
" postscr_encodings             - highlight encoding names (there are a lot)
" postscr_andornot_binary       - highlight and, or, and not as binary operators (not logical)
"
" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" PostScript is case sensitive
syn case match

" Keyword characters - all 7-bit ASCII bar PS delimiters and ws
setlocal iskeyword=33-127,^(,^),^<,^>,^[,^],^{,^},^/,^%

" Yer trusty old TODO highlghter!
syn keyword postscrTodo contained  TODO

" Comment
syn match postscrComment        "%.*$" contains=postscrTodo,@Spell
" DSC comment start line (NB: defines DSC level, not PS level!)
syn match postscrDSCComment    	"^%!PS-Adobe-\d\+\.\d\+\s*.*$"
" DSC comment line (no check on possible comments - another language!)
syn match postscrDSCComment    	"^%%\u\+.*$" contains=@postscrString,@postscrNumber,@Spell
" DSC continuation line (no check that previous line is DSC comment)
syn match  postscrDSCComment    "^%%+ *.*$" contains=@postscrString,@postscrNumber,@Spell

" Names
syn match postscrName           "\k\+"

" Identifiers
syn match postscrIdentifierError "/\{1,2}[[:space:]\[\]{}]"me=e-1
syn match postscrIdentifier     "/\{1,2}\k\+" contains=postscrConstant,postscrBoolean,postscrCustConstant

" Numbers
syn case ignore
" In file hex data - usually complete lines
syn match postscrHex            "^[[:xdigit:]][[:xdigit:][:space:]]*$"
"syn match postscrHex            "\<\x\{2,}\>"
" Integers
syn match postscrInteger        "\<[+-]\=\d\+\>"
" Radix
syn match postscrRadix          "\d\+#\x\+\>"
" Reals - upper and lower case e is allowed
syn match postscrFloat          "[+-]\=\d\+\.\>"
syn match postscrFloat          "[+-]\=\d\+\.\d*\(e[+-]\=\d\+\)\=\>"
syn match postscrFloat          "[+-]\=\.\d\+\(e[+-]\=\d\+\)\=\>"
syn match postscrFloat          "[+-]\=\d\+e[+-]\=\d\+\>"
syn cluster postscrNumber       contains=postscrInteger,postscrRadix,postscrFloat
syn case match

" Escaped characters
syn match postscrSpecialChar    contained "\\[nrtbf\\()]"
syn match postscrSpecialCharError contained "\\[^nrtbf\\()]"he=e-1
" Escaped octal characters
syn match postscrSpecialChar    contained "\\\o\{1,3}"

" Strings
" ASCII strings
syn region postscrASCIIString   start=+(+ end=+)+ skip=+([^)]*)+ contains=postscrSpecialChar,postscrSpecialCharError,@Spell
syn match postscrASCIIStringError ")"
" Hex strings
syn match postscrHexCharError   contained "[^<>[:xdigit:][:space:]]"
syn region postscrHexString     start=+<\($\|[^<]\)+ end=+>+ contains=postscrHexCharError
syn match postscrHexString      "<>"
" ASCII85 strings
syn match postscrASCII85CharError contained "[^<>\~!-uz[:space:]]"
syn region postscrASCII85String start=+<\~+ end=+\~>+ contains=postscrASCII85CharError
syn cluster postscrString       contains=postscrASCIIString,postscrHexString,postscrASCII85String


" Set default highlighting to level 2 - most common at the moment
if !exists("postscr_level")
  let postscr_level = 2
endif


" PS level 1 operators - common to all levels (well ...)

" Stack operators
syn keyword postscrOperator     pop exch dup copy index roll clear count mark cleartomark counttomark

" Math operators
syn keyword postscrMathOperator add div idiv mod mul sub abs neg ceiling floor round truncate sqrt atan cos
syn keyword postscrMathOperator sin exp ln log rand srand rrand

" Array operators
syn match postscrOperator       "[\[\]{}]"
syn keyword postscrOperator     array length get put getinterval putinterval astore aload copy
syn keyword postscrRepeat       forall

" Dictionary operators
syn keyword postscrOperator     dict maxlength begin end def load store known where currentdict
syn keyword postscrOperator     countdictstack dictstack cleardictstack internaldict
syn keyword postscrConstant     $error systemdict userdict statusdict errordict

" String operators
syn keyword postscrOperator     string anchorsearch search token

" Logic operators
syn keyword postscrLogicalOperator eq ne ge gt le lt and not or
if exists("postscr_andornot_binaryop")
  syn keyword postscrBinaryOperator and or not
else
  syn keyword postscrLogicalOperator and not or
endif
syn keyword postscrBinaryOperator xor bitshift
syn keyword postscrBoolean      true false

" PS Type names
syn keyword postscrConstant     arraytype booleantype conditiontype dicttype filetype fonttype gstatetype
syn keyword postscrConstant     integertype locktype marktype nametype nulltype operatortype
syn keyword postscrConstant     packedarraytype realtype savetype stringtype

" Control operators
syn keyword postscrConditional  if ifelse
syn keyword postscrRepeat       for repeat loop
syn keyword postscrOperator     exec exit stop stopped countexecstack execstack quit
syn keyword postscrProcedure    start

" Object operators
syn keyword postscrOperator     type cvlit cvx xcheck executeonly noaccess readonly rcheck wcheck cvi cvn cvr
syn keyword postscrOperator     cvrs cvs

" File operators
syn keyword postscrOperator     file closefile read write readhexstring writehexstring readstring writestring
syn keyword postscrOperator     bytesavailable flush flushfile resetfile status run currentfile print
syn keyword postscrOperator     stack pstack readline deletefile setfileposition fileposition renamefile
syn keyword postscrRepeat       filenameforall
syn keyword postscrProcedure    = ==

" VM operators
syn keyword postscrOperator     save restore

" Misc operators
syn keyword postscrOperator     bind null usertime executive echo realtime
syn keyword postscrConstant     product revision serialnumber version
syn keyword postscrProcedure    prompt

" GState operators
syn keyword postscrOperator     gsave grestore grestoreall initgraphics setlinewidth setlinecap currentgray
syn keyword postscrOperator     currentlinejoin setmiterlimit currentmiterlimit setdash currentdash setgray
syn keyword postscrOperator     sethsbcolor currenthsbcolor setrgbcolor currentrgbcolor currentlinewidth
syn keyword postscrOperator     currentlinecap setlinejoin setcmykcolor currentcmykcolor

" Device gstate operators
syn keyword postscrOperator     setscreen currentscreen settransfer currenttransfer setflat currentflat
syn keyword postscrOperator     currentblackgeneration setblackgeneration setundercolorremoval
syn keyword postscrOperator     setcolorscreen currentcolorscreen setcolortransfer currentcolortransfer
syn keyword postscrOperator     currentundercolorremoval

" Matrix operators
syn keyword postscrOperator     matrix initmatrix identmatrix defaultmatrix currentmatrix setmatrix translate
syn keyword postscrOperator     concat concatmatrix transform dtransform itransform idtransform invertmatrix
syn keyword postscrOperator     scale rotate

" Path operators
syn keyword postscrOperator     newpath currentpoint moveto rmoveto lineto rlineto arc arcn arcto curveto
syn keyword postscrOperator     closepath flattenpath reversepath strokepath charpath clippath pathbbox
syn keyword postscrOperator     initclip clip eoclip rcurveto
syn keyword postscrRepeat       pathforall

" Painting operators
syn keyword postscrOperator     erasepage fill eofill stroke image imagemask colorimage

" Device operators
syn keyword postscrOperator     showpage copypage nulldevice

" Character operators
syn keyword postscrProcedure    findfont
syn keyword postscrConstant     FontDirectory ISOLatin1Encoding StandardEncoding
syn keyword postscrOperator     definefont scalefont makefont setfont currentfont show ashow
syn keyword postscrOperator     stringwidth kshow setcachedevice
syn keyword postscrOperator     setcharwidth widthshow awidthshow findencoding cshow rootfont setcachedevice2

" Interpreter operators
syn keyword postscrOperator     vmstatus cachestatus setcachelimit

" PS constants
syn keyword postscrConstant     contained Gray Red Green Blue All None DeviceGray DeviceRGB

" PS Filters
syn keyword postscrConstant     contained ASCIIHexDecode ASCIIHexEncode ASCII85Decode ASCII85Encode LZWDecode
syn keyword postscrConstant     contained RunLengthDecode RunLengthEncode SubFileDecode NullEncode
syn keyword postscrConstant     contained GIFDecode PNGDecode LZWEncode

" PS JPEG filter dictionary entries
syn keyword postscrConstant     contained DCTEncode DCTDecode Colors HSamples VSamples QuantTables QFactor
syn keyword postscrConstant     contained HuffTables ColorTransform

" PS CCITT filter dictionary entries
syn keyword postscrConstant     contained CCITTFaxEncode CCITTFaxDecode Uncompressed K EndOfLine
syn keyword postscrConstant     contained Columns Rows EndOfBlock Blacks1 DamagedRowsBeforeError
syn keyword postscrConstant     contained EncodedByteAlign

" PS Form dictionary entries
syn keyword postscrConstant     contained FormType XUID BBox Matrix PaintProc Implementation

" PS Errors
syn keyword postscrProcedure    handleerror
syn keyword postscrConstant     contained  configurationerror dictfull dictstackunderflow dictstackoverflow
syn keyword postscrConstant     contained  execstackoverflow interrupt invalidaccess
syn keyword postscrConstant     contained  invalidcontext invalidexit invalidfileaccess invalidfont
syn keyword postscrConstant     contained  invalidid invalidrestore ioerror limitcheck nocurrentpoint
syn keyword postscrConstant     contained  rangecheck stackoverflow stackunderflow syntaxerror timeout
syn keyword postscrConstant     contained  typecheck undefined undefinedfilename undefinedresource
syn keyword postscrConstant     contained  undefinedresult unmatchedmark unregistered VMerror

if exists("postscr_fonts")
" Font names
  syn keyword postscrConstant   contained Symbol Times-Roman Times-Italic Times-Bold Times-BoldItalic
  syn keyword postscrConstant   contained Helvetica Helvetica-Oblique Helvetica-Bold Helvetica-BoldOblique
  syn keyword postscrConstant   contained Courier Courier-Oblique Courier-Bold Courier-BoldOblique
endif


if exists("postscr_display")
" Display PS only operators
  syn keyword postscrOperator   currentcontext fork join detach lock monitor condition wait notify yield
  syn keyword postscrOperator   viewclip eoviewclip rectviewclip initviewclip viewclippath deviceinfo
  syn keyword postscrOperator   sethalftonephase currenthalftonephase wtranslation defineusername
endif

" PS Character encoding names
if exists("postscr_encodings")
" Common encoding names
  syn keyword postscrConstant   contained .notdef

" Standard and ISO encoding names
  syn keyword postscrConstant   contained space exclam quotedbl numbersign dollar percent ampersand quoteright
  syn keyword postscrConstant   contained parenleft parenright asterisk plus comma hyphen period slash zero
  syn keyword postscrConstant   contained one two three four five six seven eight nine colon semicolon less
  syn keyword postscrConstant   contained equal greater question at
  syn keyword postscrConstant   contained bracketleft backslash bracketright asciicircum underscore quoteleft
  syn keyword postscrConstant   contained braceleft bar braceright asciitilde
  syn keyword postscrConstant   contained exclamdown cent sterling fraction yen florin section currency
  syn keyword postscrConstant   contained quotesingle quotedblleft guillemotleft guilsinglleft guilsinglright
  syn keyword postscrConstant   contained fi fl endash dagger daggerdbl periodcentered paragraph bullet
  syn keyword postscrConstant   contained quotesinglbase quotedblbase quotedblright guillemotright ellipsis
  syn keyword postscrConstant   contained perthousand questiondown grave acute circumflex tilde macron breve
  syn keyword postscrConstant   contained dotaccent dieresis ring cedilla hungarumlaut ogonek caron emdash
  syn keyword postscrConstant   contained AE ordfeminine Lslash Oslash OE ordmasculine ae dotlessi lslash
  syn keyword postscrConstant   contained oslash oe germandbls
" The following are valid names, but are used as short procedure names in generated PS!
" a b c d e f g h i j k l m n o p q r s t u v w x y z
" A B C D E F G H I J K L M N O P Q R S T U V W X Y Z

" Symbol encoding names
  syn keyword postscrConstant   contained universal existential suchthat asteriskmath minus
  syn keyword postscrConstant   contained congruent Alpha Beta Chi Delta Epsilon Phi Gamma Eta Iota theta1
  syn keyword postscrConstant   contained Kappa Lambda Mu Nu Omicron Pi Theta Rho Sigma Tau Upsilon sigma1
  syn keyword postscrConstant   contained Omega Xi Psi Zeta therefore perpendicular
  syn keyword postscrConstant   contained radicalex alpha beta chi delta epsilon phi gamma eta iota phi1
  syn keyword postscrConstant   contained kappa lambda mu nu omicron pi theta rho sigma tau upsilon omega1
  syn keyword postscrConstant   contained Upsilon1 minute lessequal infinity club diamond heart spade
  syn keyword postscrConstant   contained arrowboth arrowleft arrowup arrowright arrowdown degree plusminus
  syn keyword postscrConstant   contained second greaterequal multiply proportional partialdiff divide
  syn keyword postscrConstant   contained notequal equivalence approxequal arrowvertex arrowhorizex
  syn keyword postscrConstant   contained aleph Ifraktur Rfraktur weierstrass circlemultiply circleplus
  syn keyword postscrConstant   contained emptyset intersection union propersuperset reflexsuperset notsubset
  syn keyword postscrConstant   contained propersubset reflexsubset element notelement angle gradient
  syn keyword postscrConstant   contained registerserif copyrightserif trademarkserif radical dotmath
  syn keyword postscrConstant   contained logicalnot logicaland logicalor arrowdblboth arrowdblleft arrowdblup
  syn keyword postscrConstant   contained arrowdblright arrowdbldown omega xi psi zeta similar carriagereturn
  syn keyword postscrConstant   contained lozenge angleleft registersans copyrightsans trademarksans summation
  syn keyword postscrConstant   contained parenlefttp parenleftex parenleftbt bracketlefttp bracketleftex
  syn keyword postscrConstant   contained bracketleftbt bracelefttp braceleftmid braceleftbt braceex euro
  syn keyword postscrConstant   contained angleright integral integraltp integralex integralbt parenrighttp
  syn keyword postscrConstant   contained parenrightex parenrightbt bracketrighttp bracketrightex
  syn keyword postscrConstant   contained bracketrightbt bracerighttp bracerightmid bracerightbt

" ISO Latin1 encoding names
  syn keyword postscrConstant   contained brokenbar copyright registered twosuperior threesuperior
  syn keyword postscrConstant   contained onesuperior onequarter onehalf threequarters
  syn keyword postscrConstant   contained Agrave Aacute Acircumflex Atilde Adieresis Aring Ccedilla Egrave
  syn keyword postscrConstant   contained Eacute Ecircumflex Edieresis Igrave Iacute Icircumflex Idieresis
  syn keyword postscrConstant   contained Eth Ntilde Ograve Oacute Ocircumflex Otilde Odieresis Ugrave Uacute
  syn keyword postscrConstant   contained Ucircumflex Udieresis Yacute Thorn
  syn keyword postscrConstant   contained agrave aacute acircumflex atilde adieresis aring ccedilla egrave
  syn keyword postscrConstant   contained eacute ecircumflex edieresis igrave iacute icircumflex idieresis
  syn keyword postscrConstant   contained eth ntilde ograve oacute ocircumflex otilde odieresis ugrave uacute
  syn keyword postscrConstant   contained ucircumflex udieresis yacute thorn ydieresis
  syn keyword postscrConstant   contained zcaron exclamsmall Hungarumlautsmall dollaroldstyle dollarsuperior
  syn keyword postscrConstant   contained ampersandsmall Acutesmall parenleftsuperior parenrightsuperior
  syn keyword postscrConstant   contained twodotenleader onedotenleader zerooldstyle oneoldstyle twooldstyle
  syn keyword postscrConstant   contained threeoldstyle fouroldstyle fiveoldstyle sixoldstyle sevenoldstyle
  syn keyword postscrConstant   contained eightoldstyle nineoldstyle commasuperior
  syn keyword postscrConstant   contained threequartersemdash periodsuperior questionsmall asuperior bsuperior
  syn keyword postscrConstant   contained centsuperior dsuperior esuperior isuperior lsuperior msuperior
  syn keyword postscrConstant   contained nsuperior osuperior rsuperior ssuperior tsuperior ff ffi ffl
  syn keyword postscrConstant   contained parenleftinferior parenrightinferior Circumflexsmall hyphensuperior
  syn keyword postscrConstant   contained Gravesmall Asmall Bsmall Csmall Dsmall Esmall Fsmall Gsmall Hsmall
  syn keyword postscrConstant   contained Ismall Jsmall Ksmall Lsmall Msmall Nsmall Osmall Psmall Qsmall
  syn keyword postscrConstant   contained Rsmall Ssmall Tsmall Usmall Vsmall Wsmall Xsmall Ysmall Zsmall
  syn keyword postscrConstant   contained colonmonetary onefitted rupiah Tildesmall exclamdownsmall
  syn keyword postscrConstant   contained centoldstyle Lslashsmall Scaronsmall Zcaronsmall Dieresissmall
  syn keyword postscrConstant   contained Brevesmall Caronsmall Dotaccentsmall Macronsmall figuredash
  syn keyword postscrConstant   contained hypheninferior Ogoneksmall Ringsmall Cedillasmall questiondownsmall
  syn keyword postscrConstant   contained oneeighth threeeighths fiveeighths seveneighths onethird twothirds
  syn keyword postscrConstant   contained zerosuperior foursuperior fivesuperior sixsuperior sevensuperior
  syn keyword postscrConstant   contained eightsuperior ninesuperior zeroinferior oneinferior twoinferior
  syn keyword postscrConstant   contained threeinferior fourinferior fiveinferior sixinferior seveninferior
  syn keyword postscrConstant   contained eightinferior nineinferior centinferior dollarinferior periodinferior
  syn keyword postscrConstant   contained commainferior Agravesmall Aacutesmall Acircumflexsmall
  syn keyword postscrConstant   contained Atildesmall Adieresissmall Aringsmall AEsmall Ccedillasmall
  syn keyword postscrConstant   contained Egravesmall Eacutesmall Ecircumflexsmall Edieresissmall Igravesmall
  syn keyword postscrConstant   contained Iacutesmall Icircumflexsmall Idieresissmall Ethsmall Ntildesmall
  syn keyword postscrConstant   contained Ogravesmall Oacutesmall Ocircumflexsmall Otildesmall Odieresissmall
  syn keyword postscrConstant   contained OEsmall Oslashsmall Ugravesmall Uacutesmall Ucircumflexsmall
  syn keyword postscrConstant   contained Udieresissmall Yacutesmall Thornsmall Ydieresissmall Black Bold Book
  syn keyword postscrConstant   contained Light Medium Regular Roman Semibold

" Sundry standard and expert encoding names
  syn keyword postscrConstant   contained trademark Scaron Ydieresis Zcaron scaron softhyphen overscore
  syn keyword postscrConstant   contained graybox Sacute Tcaron Zacute sacute tcaron zacute Aogonek Scedilla
  syn keyword postscrConstant   contained Zdotaccent aogonek scedilla Lcaron lcaron zdotaccent Racute Abreve
  syn keyword postscrConstant   contained Lacute Cacute Ccaron Eogonek Ecaron Dcaron Dcroat Nacute Ncaron
  syn keyword postscrConstant   contained Ohungarumlaut Rcaron Uring Uhungarumlaut Tcommaaccent racute abreve
  syn keyword postscrConstant   contained lacute cacute ccaron eogonek ecaron dcaron dcroat nacute ncaron
  syn keyword postscrConstant   contained ohungarumlaut rcaron uring uhungarumlaut tcommaaccent Gbreve
  syn keyword postscrConstant   contained Idotaccent gbreve blank apple
endif


" By default level 3 includes all level 2 operators
if postscr_level == 2 || postscr_level == 3
" Dictionary operators
  syn match postscrL2Operator     "\(<<\|>>\)"
  syn keyword postscrL2Operator   undef
  syn keyword postscrConstant   globaldict shareddict

" Device operators
  syn keyword postscrL2Operator   setpagedevice currentpagedevice

" Path operators
  syn keyword postscrL2Operator   rectclip setbbox uappend ucache upath ustrokepath arct

" Painting operators
  syn keyword postscrL2Operator   rectfill rectstroke ufill ueofill ustroke

" Array operators
  syn keyword postscrL2Operator   currentpacking setpacking packedarray

" Misc operators
  syn keyword postscrL2Operator   languagelevel

" Insideness operators
  syn keyword postscrL2Operator   infill ineofill instroke inufill inueofill inustroke

" GState operators
  syn keyword postscrL2Operator   gstate setgstate currentgstate setcolor
  syn keyword postscrL2Operator   setcolorspace currentcolorspace setstrokeadjust currentstrokeadjust
  syn keyword postscrL2Operator   currentcolor

" Device gstate operators
  syn keyword postscrL2Operator   sethalftone currenthalftone setoverprint currentoverprint
  syn keyword postscrL2Operator   setcolorrendering currentcolorrendering

" Character operators
  syn keyword postscrL2Constant   GlobalFontDirectory SharedFontDirectory
  syn keyword postscrL2Operator   glyphshow selectfont
  syn keyword postscrL2Operator   addglyph undefinefont xshow xyshow yshow

" Pattern operators
  syn keyword postscrL2Operator   makepattern setpattern execform

" Resource operators
  syn keyword postscrL2Operator   defineresource undefineresource findresource resourcestatus
  syn keyword postscrL2Repeat     resourceforall

" File operators
  syn keyword postscrL2Operator   filter printobject writeobject setobjectformat currentobjectformat

" VM operators
  syn keyword postscrL2Operator   currentshared setshared defineuserobject execuserobject undefineuserobject
  syn keyword postscrL2Operator   gcheck scheck startjob currentglobal setglobal
  syn keyword postscrConstant   UserObjects

" Interpreter operators
  syn keyword postscrL2Operator   setucacheparams setvmthreshold ucachestatus setsystemparams
  syn keyword postscrL2Operator   setuserparams currentuserparams setcacheparams currentcacheparams
  syn keyword postscrL2Operator   currentdevparams setdevparams vmreclaim currentsystemparams

" PS2 constants
  syn keyword postscrConstant   contained DeviceCMYK Pattern Indexed Separation Cyan Magenta Yellow Black
  syn keyword postscrConstant   contained CIEBasedA CIEBasedABC CIEBasedDEF CIEBasedDEFG

" PS2 $error dictionary entries
  syn keyword postscrConstant   contained newerror errorname command errorinfo ostack estack dstack
  syn keyword postscrConstant   contained recordstacks binary

" PS2 Category dictionary
  syn keyword postscrConstant   contained DefineResource UndefineResource FindResource ResourceStatus
  syn keyword postscrConstant   contained ResourceForAll Category InstanceType ResourceFileName

" PS2 Category names
  syn keyword postscrConstant   contained Font Encoding Form Pattern ProcSet ColorSpace Halftone
  syn keyword postscrConstant   contained ColorRendering Filter ColorSpaceFamily Emulator IODevice
  syn keyword postscrConstant   contained ColorRenderingType FMapType FontType FormType HalftoneType
  syn keyword postscrConstant   contained ImageType PatternType Category Generic

" PS2 pagedevice dictionary entries
  syn keyword postscrConstant   contained PageSize MediaColor MediaWeight MediaType InputAttributes ManualFeed
  syn keyword postscrConstant   contained OutputType OutputAttributes NumCopies Collate Duplex Tumble
  syn keyword postscrConstant   contained Separations HWResolution Margins NegativePrint MirrorPrint
  syn keyword postscrConstant   contained CutMedia AdvanceMedia AdvanceDistance ImagingBBox
  syn keyword postscrConstant   contained Policies Install BeginPage EndPage PolicyNotFound PolicyReport
  syn keyword postscrConstant   contained ManualSize OutputFaceUp Jog
  syn keyword postscrConstant   contained Bind BindDetails Booklet BookletDetails CollateDetails
  syn keyword postscrConstant   contained DeviceRenderingInfo ExitJamRecovery Fold FoldDetails Laminate
  syn keyword postscrConstant   contained ManualFeedTimeout Orientation OutputPage
  syn keyword postscrConstant   contained PostRenderingEnhance PostRenderingEnhanceDetails
  syn keyword postscrConstant   contained PreRenderingEnhance PreRenderingEnhanceDetails
  syn keyword postscrConstant   contained Signature SlipSheet Staple StapleDetails Trim
  syn keyword postscrConstant   contained ProofSet REValue PrintQuality ValuesPerColorComponent AntiAlias

" PS2 PDL resource entries
  syn keyword postscrConstant   contained Selector LanguageFamily LanguageVersion

" PS2 halftone dictionary entries
  syn keyword postscrConstant   contained HalftoneType HalftoneName
  syn keyword postscrConstant   contained AccurateScreens ActualAngle Xsquare Ysquare AccurateFrequency
  syn keyword postscrConstant   contained Frequency SpotFunction Angle Width Height Thresholds
  syn keyword postscrConstant   contained RedFrequency RedSpotFunction RedAngle RedWidth RedHeight
  syn keyword postscrConstant   contained GreenFrequency GreenSpotFunction GreenAngle GreenWidth GreenHeight
  syn keyword postscrConstant   contained BlueFrequency BlueSpotFunction BlueAngle BlueWidth BlueHeight
  syn keyword postscrConstant   contained GrayFrequency GrayAngle GraySpotFunction GrayWidth GrayHeight
  syn keyword postscrConstant   contained GrayThresholds BlueThresholds GreenThresholds RedThresholds
  syn keyword postscrConstant   contained TransferFunction

" PS2 CSR dictionaries
  syn keyword postscrConstant   contained RangeA DecodeA MatrixA RangeABC DecodeABC MatrixABC BlackPoint
  syn keyword postscrConstant   contained RangeLMN DecodeLMN MatrixLMN WhitePoint RangeDEF DecodeDEF RangeHIJ
  syn keyword postscrConstant   contained RangeDEFG DecodeDEFG RangeHIJK Table

" PS2 CRD dictionaries
  syn keyword postscrConstant   contained ColorRenderingType EncodeLMB EncodeABC RangePQR MatrixPQR
  syn keyword postscrConstant   contained AbsoluteColorimetric RelativeColorimetric Saturation Perceptual
  syn keyword postscrConstant   contained TransformPQR RenderTable

" PS2 Pattern dictionary
  syn keyword postscrConstant   contained PatternType PaintType TilingType XStep YStep

" PS2 Image dictionary
  syn keyword postscrConstant   contained ImageType ImageMatrix MultipleDataSources DataSource
  syn keyword postscrConstant   contained BitsPerComponent Decode Interpolate

" PS2 Font dictionaries
  syn keyword postscrConstant   contained FontType FontMatrix FontName FontInfo LanguageLevel WMode Encoding
  syn keyword postscrConstant   contained UniqueID StrokeWidth Metrics Metrics2 CDevProc CharStrings Private
  syn keyword postscrConstant   contained FullName Notice version ItalicAngle isFixedPitch UnderlinePosition
  syn keyword postscrConstant   contained FMapType Encoding FDepVector PrefEnc EscChar ShiftOut ShiftIn
  syn keyword postscrConstant   contained WeightVector Blend $Blend CIDFontType sfnts CIDSystemInfo CodeMap
  syn keyword postscrConstant   contained CMap CIDFontName CIDSystemInfo UIDBase CIDDevProc CIDCount
  syn keyword postscrConstant   contained CIDMapOffset FDArray FDBytes GDBytes GlyphData GlyphDictionary
  syn keyword postscrConstant   contained SDBytes SubrMapOffset SubrCount BuildGlyph CIDMap FID MIDVector
  syn keyword postscrConstant   contained Ordering Registry Supplement CMapName CMapVersion UIDOffset
  syn keyword postscrConstant   contained SubsVector UnderlineThickness FamilyName FontBBox CurMID
  syn keyword postscrConstant   contained Weight

" PS2 User parameters
  syn keyword postscrConstant   contained MaxFontItem MinFontCompress MaxUPathItem MaxFormItem MaxPatternItem
  syn keyword postscrConstant   contained MaxScreenItem MaxOpStack MaxDictStack MaxExecStack MaxLocalVM
  syn keyword postscrConstant   contained VMReclaim VMThreshold

" PS2 System parameters
  syn keyword postscrConstant   contained SystemParamsPassword StartJobPassword BuildTime ByteOrder RealFormat
  syn keyword postscrConstant   contained MaxFontCache CurFontCache MaxOutlineCache CurOutlineCache
  syn keyword postscrConstant   contained MaxUPathCache CurUPathCache MaxFormCache CurFormCache
  syn keyword postscrConstant   contained MaxPatternCache CurPatternCache MaxScreenStorage CurScreenStorage
  syn keyword postscrConstant   contained MaxDisplayList CurDisplayList

" PS2 LZW Filters
  syn keyword postscrConstant   contained Predictor

" Paper Size operators
  syn keyword postscrL2Operator   letter lettersmall legal ledger 11x17 a4 a3 a4small b5 note

" Paper Tray operators
  syn keyword postscrL2Operator   lettertray legaltray ledgertray a3tray a4tray b5tray 11x17tray

" SCC compatibility operators
  syn keyword postscrL2Operator   sccbatch sccinteractive setsccbatch setsccinteractive

" Page duplexing operators
  syn keyword postscrL2Operator   duplexmode firstside newsheet setduplexmode settumble tumble

" Device compatibility operators
  syn keyword postscrL2Operator   devdismount devformat devmount devstatus
  syn keyword postscrL2Repeat     devforall

" Imagesetter compatibility operators
  syn keyword postscrL2Operator   accuratescreens checkscreen pagemargin pageparams setaccuratescreens setpage
  syn keyword postscrL2Operator   setpagemargin setpageparams

" Misc compatibility operators
  syn keyword postscrL2Operator   appletalktype buildtime byteorder checkpassword defaulttimeouts diskonline
  syn keyword postscrL2Operator   diskstatus manualfeed manualfeedtimeout margins mirrorprint pagecount
  syn keyword postscrL2Operator   pagestackorder printername processcolors sethardwareiomode setjobtimeout
  syn keyword postscrL2Operator   setpagestockorder setprintername setresolution doprinterrors dostartpage
  syn keyword postscrL2Operator   hardwareiomode initializedisk jobname jobtimeout ramsize realformat resolution
  syn keyword postscrL2Operator   setdefaulttimeouts setdoprinterrors setdostartpage setdosysstart
  syn keyword postscrL2Operator   setuserdiskpercent softwareiomode userdiskpercent waittimeout
  syn keyword postscrL2Operator   setsoftwareiomode dosysstart emulate setmargins setmirrorprint

endif " PS2 highlighting

if postscr_level == 3
" Shading operators
  syn keyword postscrL3Operator setsmoothness currentsmoothness shfill

" Clip operators
  syn keyword postscrL3Operator clipsave cliprestore

" Pagedevive operators
  syn keyword postscrL3Operator setpage setpageparams

" Device gstate operators
  syn keyword postscrL3Operator findcolorrendering

" Font operators
  syn keyword postscrL3Operator composefont

" PS LL3 Output device resource entries
  syn keyword postscrConstant   contained DeviceN TrappingDetailsType

" PS LL3 pagdevice dictionary entries
  syn keyword postscrConstant   contained DeferredMediaSelection ImageShift InsertSheet LeadingEdge MaxSeparations
  syn keyword postscrConstant   contained MediaClass MediaPosition OutputDevice PageDeviceName PageOffset ProcessColorModel
  syn keyword postscrConstant   contained RollFedMedia SeparationColorNames SeparationOrder Trapping TrappingDetails
  syn keyword postscrConstant   contained TraySwitch UseCIEColor
  syn keyword postscrConstant   contained ColorantDetails ColorantName ColorantType NeutralDensity TrappingOrder
  syn keyword postscrConstant   contained ColorantSetName

" PS LL3 trapping dictionary entries
  syn keyword postscrConstant   contained BlackColorLimit BlackDensityLimit BlackWidth ColorantZoneDetails
  syn keyword postscrConstant   contained SlidingTrapLimit StepLimit TrapColorScaling TrapSetName TrapWidth
  syn keyword postscrConstant   contained ImageResolution ImageToObjectTrapping ImageTrapPlacement
  syn keyword postscrConstant   contained StepLimit TrapColorScaling Enabled ImageInternalTrapping

" PS LL3 filters and entries
  syn keyword postscrConstant   contained ReusableStreamDecode CloseSource CloseTarget UnitSize LowBitFirst
  syn keyword postscrConstant   contained FlateEncode FlateDecode DecodeParams Intent AsyncRead

" PS LL3 halftone dictionary entries
  syn keyword postscrConstant   contained Height2 Width2

" PS LL3 function dictionary entries
  syn keyword postscrConstant   contained FunctionType Domain Range Order BitsPerSample Encode Size C0 C1 N
  syn keyword postscrConstant   contained Functions Bounds

" PS LL3 image dictionary entries
  syn keyword postscrConstant   contained InterleaveType MaskDict DataDict MaskColor

" PS LL3 Pattern and shading dictionary entries
  syn keyword postscrConstant   contained Shading ShadingType Background ColorSpace Coords Extend Function
  syn keyword postscrConstant   contained VerticesPerRow BitsPerCoordinate BitsPerFlag

" PS LL3 image dictionary entries
  syn keyword postscrConstant   contained XOrigin YOrigin UnpaintedPath PixelCopy

" PS LL3 colorrendering procedures
  syn keyword postscrProcedure  GetHalftoneName GetPageDeviceName GetSubstituteCRD

" PS LL3 CIDInit procedures
  syn keyword postscrProcedure  beginbfchar beginbfrange begincidchar begincidrange begincmap begincodespacerange
  syn keyword postscrProcedure  beginnotdefchar beginnotdefrange beginrearrangedfont beginusematrix
  syn keyword postscrProcedure  endbfchar endbfrange endcidchar endcidrange endcmap endcodespacerange
  syn keyword postscrProcedure  endnotdefchar endnotdefrange endrearrangedfont endusematrix
  syn keyword postscrProcedure  StartData usefont usecmp

" PS LL3 Trapping procedures
  syn keyword postscrProcedure  settrapparams currenttrapparams settrapzone

" PS LL3 BitmapFontInit procedures
  syn keyword postscrProcedure  removeall removeglyphs

" PS LL3 Font names
  if exists("postscr_fonts")
    syn keyword postscrConstant contained AlbertusMT AlbertusMT-Italic AlbertusMT-Light Apple-Chancery Apple-ChanceryCE
    syn keyword postscrConstant contained AntiqueOlive-Roman AntiqueOlive-Italic AntiqueOlive-Bold AntiqueOlive-Compact
    syn keyword postscrConstant contained AntiqueOliveCE-Roman AntiqueOliveCE-Italic AntiqueOliveCE-Bold AntiqueOliveCE-Compact
    syn keyword postscrConstant contained ArialMT Arial-ItalicMT Arial-LightMT Arial-BoldMT Arial-BoldItalicMT
    syn keyword postscrConstant contained ArialCE ArialCE-Italic ArialCE-Light ArialCE-Bold ArialCE-BoldItalic
    syn keyword postscrConstant contained AvantGarde-Book AvantGarde-BookOblique AvantGarde-Demi AvantGarde-DemiOblique
    syn keyword postscrConstant contained AvantGardeCE-Book AvantGardeCE-BookOblique AvantGardeCE-Demi AvantGardeCE-DemiOblique
    syn keyword postscrConstant contained Bodoni Bodoni-Italic Bodoni-Bold Bodoni-BoldItalic Bodoni-Poster Bodoni-PosterCompressed
    syn keyword postscrConstant contained BodoniCE BodoniCE-Italic BodoniCE-Bold BodoniCE-BoldItalic BodoniCE-Poster BodoniCE-PosterCompressed
    syn keyword postscrConstant contained Bookman-Light Bookman-LightItalic Bookman-Demi Bookman-DemiItalic
    syn keyword postscrConstant contained BookmanCE-Light BookmanCE-LightItalic BookmanCE-Demi BookmanCE-DemiItalic
    syn keyword postscrConstant contained Carta Chicago ChicagoCE Clarendon Clarendon-Light Clarendon-Bold
    syn keyword postscrConstant contained ClarendonCE ClarendonCE-Light ClarendonCE-Bold CooperBlack CooperBlack-Italic
    syn keyword postscrConstant contained Copperplate-ThirtyTwoBC CopperPlate-ThirtyThreeBC Coronet-Regular CoronetCE-Regular
    syn keyword postscrConstant contained CourierCE CourierCE-Oblique CourierCE-Bold CourierCE-BoldOblique
    syn keyword postscrConstant contained Eurostile Eurostile-Bold Eurostile-ExtendedTwo Eurostile-BoldExtendedTwo
    syn keyword postscrConstant contained Eurostile EurostileCE-Bold EurostileCE-ExtendedTwo EurostileCE-BoldExtendedTwo
    syn keyword postscrConstant contained Geneva GenevaCE GillSans GillSans-Italic GillSans-Bold GillSans-BoldItalic GillSans-BoldCondensed
    syn keyword postscrConstant contained GillSans-Light GillSans-LightItalic GillSans-ExtraBold
    syn keyword postscrConstant contained GillSansCE-Roman GillSansCE-Italic GillSansCE-Bold GillSansCE-BoldItalic GillSansCE-BoldCondensed
    syn keyword postscrConstant contained GillSansCE-Light GillSansCE-LightItalic GillSansCE-ExtraBold
    syn keyword postscrConstant contained Goudy Goudy-Italic Goudy-Bold Goudy-BoldItalic Goudy-ExtraBould
    syn keyword postscrConstant contained HelveticaCE HelveticaCE-Oblique HelveticaCE-Bold HelveticaCE-BoldOblique
    syn keyword postscrConstant contained Helvetica-Condensed Helvetica-Condensed-Oblique Helvetica-Condensed-Bold Helvetica-Condensed-BoldObl
    syn keyword postscrConstant contained HelveticaCE-Condensed HelveticaCE-Condensed-Oblique HelveticaCE-Condensed-Bold
    syn keyword postscrConstant contained HelveticaCE-Condensed-BoldObl Helvetica-Narrow Helvetica-Narrow-Oblique Helvetica-Narrow-Bold
    syn keyword postscrConstant contained Helvetica-Narrow-BoldOblique HelveticaCE-Narrow HelveticaCE-Narrow-Oblique HelveticaCE-Narrow-Bold
    syn keyword postscrConstant contained HelveticaCE-Narrow-BoldOblique HoeflerText-Regular HoeflerText-Italic HoeflerText-Black
    syn keyword postscrConstant contained HoeflerText-BlackItalic HoeflerText-Ornaments HoeflerTextCE-Regular HoeflerTextCE-Italic
    syn keyword postscrConstant contained HoeflerTextCE-Black HoeflerTextCE-BlackItalic
    syn keyword postscrConstant contained JoannaMT JoannaMT-Italic JoannaMT-Bold JoannaMT-BoldItalic
    syn keyword postscrConstant contained JoannaMTCE JoannaMTCE-Italic JoannaMTCE-Bold JoannaMTCE-BoldItalic
    syn keyword postscrConstant contained LetterGothic LetterGothic-Slanted LetterGothic-Bold LetterGothic-BoldSlanted
    syn keyword postscrConstant contained LetterGothicCE LetterGothicCE-Slanted LetterGothicCE-Bold LetterGothicCE-BoldSlanted
    syn keyword postscrConstant contained LubalinGraph-Book LubalinGraph-BookOblique LubalinGraph-Demi LubalinGraph-DemiOblique
    syn keyword postscrConstant contained LubalinGraphCE-Book LubalinGraphCE-BookOblique LubalinGraphCE-Demi LubalinGraphCE-DemiOblique
    syn keyword postscrConstant contained Marigold Monaco MonacoCE MonaLisa-Recut Oxford Symbol Tekton
    syn keyword postscrConstant contained NewCennturySchlbk-Roman NewCenturySchlbk-Italic NewCenturySchlbk-Bold NewCenturySchlbk-BoldItalic
    syn keyword postscrConstant contained NewCenturySchlbkCE-Roman NewCenturySchlbkCE-Italic NewCenturySchlbkCE-Bold
    syn keyword postscrConstant contained NewCenturySchlbkCE-BoldItalic NewYork NewYorkCE
    syn keyword postscrConstant contained Optima Optima-Italic Optima-Bold Optima-BoldItalic
    syn keyword postscrConstant contained OptimaCE OptimaCE-Italic OptimaCE-Bold OptimaCE-BoldItalic
    syn keyword postscrConstant contained Palatino-Roman Palatino-Italic Palatino-Bold Palatino-BoldItalic
    syn keyword postscrConstant contained PalatinoCE-Roman PalatinoCE-Italic PalatinoCE-Bold PalatinoCE-BoldItalic
    syn keyword postscrConstant contained StempelGaramond-Roman StempelGaramond-Italic StempelGaramond-Bold StempelGaramond-BoldItalic
    syn keyword postscrConstant contained StempelGaramondCE-Roman StempelGaramondCE-Italic StempelGaramondCE-Bold StempelGaramondCE-BoldItalic
    syn keyword postscrConstant contained TimesCE-Roman TimesCE-Italic TimesCE-Bold TimesCE-BoldItalic
    syn keyword postscrConstant contained TimesNewRomanPSMT TimesNewRomanPS-ItalicMT TimesNewRomanPS-BoldMT TimesNewRomanPS-BoldItalicMT
    syn keyword postscrConstant contained TimesNewRomanCE TimesNewRomanCE-Italic TimesNewRomanCE-Bold TimesNewRomanCE-BoldItalic
    syn keyword postscrConstant contained Univers Univers-Oblique Univers-Bold Univers-BoldOblique
    syn keyword postscrConstant contained UniversCE-Medium UniversCE-Oblique UniversCE-Bold UniversCE-BoldOblique
    syn keyword postscrConstant contained Univers-Light Univers-LightOblique UniversCE-Light UniversCE-LightOblique
    syn keyword postscrConstant contained Univers-Condensed Univers-CondensedOblique Univers-CondensedBold Univers-CondensedBoldOblique
    syn keyword postscrConstant contained UniversCE-Condensed UniversCE-CondensedOblique UniversCE-CondensedBold UniversCE-CondensedBoldOblique
    syn keyword postscrConstant contained Univers-Extended Univers-ExtendedObl Univers-BoldExt Univers-BoldExtObl
    syn keyword postscrConstant contained UniversCE-Extended UniversCE-ExtendedObl UniversCE-BoldExt UniversCE-BoldExtObl
    syn keyword postscrConstant contained Wingdings-Regular ZapfChancery-MediumItalic ZapfChanceryCE-MediumItalic ZapfDingBats
  endif " Font names

endif " PS LL3 highlighting


if exists("postscr_ghostscript")
  " GS gstate operators
  syn keyword postscrGSOperator   .setaccuratecurves .currentaccuratecurves .setclipoutside
  syn keyword postscrGSOperator   .setdashadapt .currentdashadapt .setdefaultmatrix .setdotlength
  syn keyword postscrGSOperator   .currentdotlength .setfilladjust2 .currentfilladjust2
  syn keyword postscrGSOperator   .currentclipoutside .setcurvejoin .currentcurvejoin
  syn keyword postscrGSOperator   .setblendmode .currentblendmode .setopacityalpha .currentopacityalpha .setshapealpha .currentshapealpha
  syn keyword postscrGSOperator   .setlimitclamp .currentlimitclamp .setoverprintmode .currentoverprintmode

  " GS path operators
  syn keyword postscrGSOperator   .dashpath .rectappend

  " GS painting operators
  syn keyword postscrGSOperator   .setrasterop .currentrasterop .setsourcetransparent
  syn keyword postscrGSOperator   .settexturetransparent .currenttexturetransparent
  syn keyword postscrGSOperator   .currentsourcetransparent

  " GS character operators
  syn keyword postscrGSOperator   .charboxpath .type1execchar %Type1BuildChar %Type1BuildGlyph

  " GS mathematical operators
  syn keyword postscrGSMathOperator arccos arcsin

  " GS dictionary operators
  syn keyword postscrGSOperator   .dicttomark .forceput .forceundef .knownget .setmaxlength

  " GS byte and string operators
  syn keyword postscrGSOperator   .type1encrypt .type1decrypt
  syn keyword postscrGSOperator   .bytestring .namestring .stringmatch

  " GS relational operators (seem like math ones to me!)
  syn keyword postscrGSMathOperator max min

  " GS file operators
  syn keyword postscrGSOperator   findlibfile unread writeppmfile
  syn keyword postscrGSOperator   .filename .fileposition .peekstring .unread

  " GS vm operators
  syn keyword postscrGSOperator   .forgetsave

  " GS device operators
  syn keyword postscrGSOperator   copydevice .getdevice makeimagedevice makewordimagedevice copyscanlines
  syn keyword postscrGSOperator   setdevice currentdevice getdeviceprops putdeviceprops flushpage
  syn keyword postscrGSOperator   finddevice findprotodevice .getbitsrect

  " GS misc operators
  syn keyword postscrGSOperator   getenv .makeoperator .setdebug .oserrno .oserror .execn

  " GS rendering stack operators
  syn keyword postscrGSOperator   .begintransparencygroup .discardtransparencygroup .endtransparencygroup
  syn keyword postscrGSOperator   .begintransparencymask .discardtransparencymask .endtransparencymask .inittransparencymask
  syn keyword postscrGSOperator   .settextknockout .currenttextknockout

  " GS filters
  syn keyword postscrConstant   contained BCPEncode BCPDecode eexecEncode eexecDecode PCXDecode
  syn keyword postscrConstant   contained PixelDifferenceEncode PixelDifferenceDecode
  syn keyword postscrConstant   contained PNGPredictorDecode TBCPEncode TBCPDecode zlibEncode
  syn keyword postscrConstant   contained zlibDecode PNGPredictorEncode PFBDecode
  syn keyword postscrConstant   contained MD5Encode

  " GS filter keys
  syn keyword postscrConstant   contained InitialCodeLength FirstBitLowOrder BlockData DecodedByteAlign

  " GS device parameters
  syn keyword postscrConstant   contained BitsPerPixel .HWMargins HWSize Name GrayValues
  syn keyword postscrConstant   contained ColorValues TextAlphaBits GraphicsAlphaBits BufferSpace
  syn keyword postscrConstant   contained OpenOutputFile PageCount BandHeight BandWidth BandBufferSpace
  syn keyword postscrConstant   contained ViewerPreProcess GreenValues BlueValues OutputFile
  syn keyword postscrConstant   contained MaxBitmap RedValues

endif " GhostScript highlighting

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link postscrComment         Comment

hi def link postscrConstant        Constant
hi def link postscrString          String
hi def link postscrASCIIString     postscrString
hi def link postscrHexString       postscrString
hi def link postscrASCII85String   postscrString
hi def link postscrNumber          Number
hi def link postscrInteger         postscrNumber
hi def link postscrHex             postscrNumber
hi def link postscrRadix           postscrNumber
hi def link postscrFloat           Float
hi def link postscrBoolean         Boolean

hi def link postscrIdentifier      Identifier
hi def link postscrProcedure       Function

hi def link postscrName            Statement
hi def link postscrConditional     Conditional
hi def link postscrRepeat          Repeat
hi def link postscrL2Repeat        postscrRepeat
hi def link postscrOperator        Operator
hi def link postscrL1Operator      postscrOperator
hi def link postscrL2Operator      postscrOperator
hi def link postscrL3Operator      postscrOperator
hi def link postscrMathOperator    postscrOperator
hi def link postscrLogicalOperator postscrOperator
hi def link postscrBinaryOperator  postscrOperator

hi def link postscrDSCComment      SpecialComment
hi def link postscrSpecialChar     SpecialChar

hi def link postscrTodo            Todo

hi def link postscrError           Error
hi def link postscrSpecialCharError postscrError
hi def link postscrASCII85CharError postscrError
hi def link postscrHexCharError    postscrError
hi def link postscrASCIIStringError postscrError
hi def link postscrIdentifierError postscrError

if exists("postscr_ghostscript")
hi def link postscrGSOperator      postscrOperator
hi def link postscrGSMathOperator  postscrMathOperator
else
hi def link postscrGSOperator      postscrError
hi def link postscrGSMathOperator  postscrError
endif


let b:current_syntax = "postscr"

" vim: ts=8
