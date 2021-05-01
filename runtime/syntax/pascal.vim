" Vim syntax file
" Language:	Pascal
" Version: 2.8
" Last Change:	2004/10/17 17:47:30
" Maintainer:  Xavier Crégut <xavier.cregut@enseeiht.fr>
" Previous Maintainer:	Mario Eusebio <bio@dq.fct.unl.pt>

" Contributors: Tim Chase <tchase@csc.com>,
"	Stas Grabois <stsi@vtrails.com>,
"	Mazen NEIFER <mazen.neifer.2001@supaero.fr>,
"	Klaus Hast <Klaus.Hast@arcor.net>,
"	Austin Ziegler <austin@halostatue.ca>,
"	Markus Koenig <markus@stber-koenig.de>

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif


syn case ignore
syn sync lines=250

syn keyword pascalBoolean	true false
syn keyword pascalConditional	if else then
syn keyword pascalConstant	nil maxint
syn keyword pascalLabel		case goto label
syn keyword pascalOperator	and div downto in mod not of or packed with
syn keyword pascalRepeat	do for do repeat while to until
syn keyword pascalStatement	procedure function
syn keyword pascalStatement	program begin end const var type
syn keyword pascalStruct	record
syn keyword pascalType		array boolean char integer file pointer real set
syn keyword pascalType		string text variant


    " 20011222az: Added new items.
syn keyword pascalTodo contained	TODO FIXME XXX DEBUG NOTE

    " 20010723az: When wanted, highlight the trailing whitespace -- this is
    " based on c_space_errors; to enable, use "pascal_space_errors".
if exists("pascal_space_errors")
    if !exists("pascal_no_trail_space_error")
        syn match pascalSpaceError "\s\+$"
    endif
    if !exists("pascal_no_tab_space_error")
        syn match pascalSpaceError " \+\t"me=e-1
    endif
endif



" String
if !exists("pascal_one_line_string")
  syn region  pascalString matchgroup=pascalString start=+'+ end=+'+ contains=pascalStringEscape
  if exists("pascal_gpc")
    syn region  pascalString matchgroup=pascalString start=+"+ end=+"+ contains=pascalStringEscapeGPC
  else
    syn region  pascalStringError matchgroup=pascalStringError start=+"+ end=+"+ contains=pascalStringEscape
  endif
else
  "wrong strings
  syn region  pascalStringError matchgroup=pascalStringError start=+'+ end=+'+ end=+$+ contains=pascalStringEscape
  if exists("pascal_gpc")
    syn region  pascalStringError matchgroup=pascalStringError start=+"+ end=+"+ end=+$+ contains=pascalStringEscapeGPC
  else
    syn region  pascalStringError matchgroup=pascalStringError start=+"+ end=+"+ end=+$+ contains=pascalStringEscape
  endif

  "right strings
  syn region  pascalString matchgroup=pascalString start=+'+ end=+'+ oneline contains=pascalStringEscape
  " To see the start and end of strings:
  " syn region  pascalString matchgroup=pascalStringError start=+'+ end=+'+ oneline contains=pascalStringEscape
  if exists("pascal_gpc")
    syn region  pascalString matchgroup=pascalString start=+"+ end=+"+ oneline contains=pascalStringEscapeGPC
  else
    syn region  pascalStringError matchgroup=pascalStringError start=+"+ end=+"+ oneline contains=pascalStringEscape
  endif
end
syn match   pascalStringEscape		contained "''"
syn match   pascalStringEscapeGPC	contained '""'


" syn match   pascalIdentifier		"\<[a-zA-Z_][a-zA-Z0-9_]*\>"


if exists("pascal_symbol_operator")
  syn match   pascalSymbolOperator      "[+\-/*=]"
  syn match   pascalSymbolOperator      "[<>]=\="
  syn match   pascalSymbolOperator      "<>"
  syn match   pascalSymbolOperator      ":="
  syn match   pascalSymbolOperator      "[()]"
  syn match   pascalSymbolOperator      "\.\."
  syn match   pascalSymbolOperator       "[\^.]"
  syn match   pascalMatrixDelimiter	"[][]"
  "if you prefer you can highlight the range
  "syn match  pascalMatrixDelimiter	"[\d\+\.\.\d\+]"
endif

syn match  pascalNumber		"-\=\<\d\+\>"
syn match  pascalFloat		"-\=\<\d\+\.\d\+\>"
syn match  pascalFloat		"-\=\<\d\+\.\d\+[eE]-\=\d\+\>"
syn match  pascalHexNumber	"\$[0-9a-fA-F]\+\>"

if exists("pascal_no_tabs")
  syn match pascalShowTab "\t"
endif

syn region pascalComment	start="(\*\|{"  end="\*)\|}" contains=pascalTodo,pascalSpaceError


if !exists("pascal_no_functions")
  " array functions
  syn keyword pascalFunction	pack unpack

  " memory function
  syn keyword pascalFunction	Dispose New

  " math functions
  syn keyword pascalFunction	Abs Arctan Cos Exp Ln Sin Sqr Sqrt

  " file functions
  syn keyword pascalFunction	Eof Eoln Write Writeln
  syn keyword pascalPredefined	Input Output

  if exists("pascal_traditional")
    " These functions do not seem to be defined in Turbo Pascal
    syn keyword pascalFunction	Get Page Put 
  endif

  " ordinal functions
  syn keyword pascalFunction	Odd Pred Succ

  " transfert functions
  syn keyword pascalFunction	Chr Ord Round Trunc
endif


if !exists("pascal_traditional")

  syn keyword pascalStatement	constructor destructor implementation inherited
  syn keyword pascalStatement	interface unit uses
  syn keyword pascalModifier	absolute assembler external far forward inline
  syn keyword pascalModifier	interrupt near virtual 
  syn keyword pascalAcces	private public 
  syn keyword pascalStruct	object 
  syn keyword pascalOperator	shl shr xor

  syn region pascalPreProc	start="(\*\$"  end="\*)" contains=pascalTodo
  syn region pascalPreProc	start="{\$"  end="}"

  syn region  pascalAsm		matchgroup=pascalAsmKey start="\<asm\>" end="\<end\>" contains=pascalComment,pascalPreProc

  syn keyword pascalType	ShortInt LongInt Byte Word
  syn keyword pascalType	ByteBool WordBool LongBool
  syn keyword pascalType	Cardinal LongWord
  syn keyword pascalType	Single Double Extended Comp
  syn keyword pascalType	PChar


  if !exists ("pascal_fpc")
    syn keyword pascalPredefined	Result
  endif

  if exists("pascal_fpc")
    syn region pascalComment        start="//" end="$" contains=pascalTodo,pascalSpaceError
    syn keyword pascalStatement	fail otherwise operator
    syn keyword pascalDirective	popstack
    syn keyword pascalPredefined self
    syn keyword pascalType	ShortString AnsiString WideString
  endif

  if exists("pascal_gpc")
    syn keyword pascalType	SmallInt
    syn keyword pascalType	AnsiChar
    syn keyword pascalType	PAnsiChar
  endif

  if exists("pascal_delphi")
    syn region pascalComment	start="//"  end="$" contains=pascalTodo,pascalSpaceError
    syn keyword pascalType	SmallInt Int64
    syn keyword pascalType	Real48 Currency
    syn keyword pascalType	AnsiChar WideChar
    syn keyword pascalType	ShortString AnsiString WideString
    syn keyword pascalType	PAnsiChar PWideChar
    syn match  pascalFloat	"-\=\<\d\+\.\d\+[dD]-\=\d\+\>"
    syn match  pascalStringEscape	contained "#[12][0-9]\=[0-9]\="
    syn keyword pascalStruct	class dispinterface
    syn keyword pascalException	try except raise at on finally
    syn keyword pascalStatement	out
    syn keyword pascalStatement	library package 
    syn keyword pascalStatement	initialization finalization uses exports
    syn keyword pascalStatement	property out resourcestring threadvar
    syn keyword pascalModifier	contains
    syn keyword pascalModifier	overridden reintroduce abstract
    syn keyword pascalModifier	override export dynamic name message
    syn keyword pascalModifier	dispid index stored default nodefault readonly
    syn keyword pascalModifier	writeonly implements overload requires resident
    syn keyword pascalAcces	protected published automated
    syn keyword pascalDirective	register pascal cvar cdecl stdcall safecall
    syn keyword pascalOperator	as is
  endif

  if exists("pascal_no_functions")
    "syn keyword pascalModifier	read write
    "may confuse with Read and Write functions.  Not easy to handle.
  else
    " control flow functions
    syn keyword pascalFunction	Break Continue Exit Halt RunError

    " ordinal functions
    syn keyword pascalFunction	Dec Inc High Low

    " math functions
    syn keyword pascalFunction	Frac Int Pi

    " string functions
    syn keyword pascalFunction	Concat Copy Delete Insert Length Pos Str Val

    " memory function
    syn keyword pascalFunction	FreeMem GetMem MaxAvail MemAvail

    " pointer and address functions
    syn keyword pascalFunction	Addr Assigned CSeg DSeg Ofs Ptr Seg SPtr SSeg

    " misc functions
    syn keyword pascalFunction	Exclude FillChar Hi Include Lo Move ParamCount
    syn keyword pascalFunction	ParamStr Random Randomize SizeOf Swap TypeOf
    syn keyword pascalFunction	UpCase

    " predefined variables
    syn keyword pascalPredefined ErrorAddr ExitCode ExitProc FileMode FreeList
    syn keyword pascalPredefined FreeZero HeapEnd HeapError HeapOrg HeapPtr
    syn keyword pascalPredefined InOutRes OvrCodeList OvrDebugPtr OvrDosHandle
    syn keyword pascalPredefined OvrEmsHandle OvrHeapEnd OvrHeapOrg OvrHeapPtr
    syn keyword pascalPredefined OvrHeapSize OvrLoadList PrefixSeg RandSeed
    syn keyword pascalPredefined SaveInt00 SaveInt02 SaveInt1B SaveInt21
    syn keyword pascalPredefined SaveInt23 SaveInt24 SaveInt34 SaveInt35
    syn keyword pascalPredefined SaveInt36 SaveInt37 SaveInt38 SaveInt39
    syn keyword pascalPredefined SaveInt3A SaveInt3B SaveInt3C SaveInt3D
    syn keyword pascalPredefined SaveInt3E SaveInt3F SaveInt75 SegA000 SegB000
    syn keyword pascalPredefined SegB800 SelectorInc StackLimit Test8087

    " file functions
    syn keyword pascalFunction	Append Assign BlockRead BlockWrite ChDir Close
    syn keyword pascalFunction	Erase FilePos FileSize Flush GetDir IOResult
    syn keyword pascalFunction	MkDir Read Readln Rename Reset Rewrite RmDir
    syn keyword pascalFunction	Seek SeekEof SeekEoln SetTextBuf Truncate

    " crt unit
    syn keyword pascalFunction	AssignCrt ClrEol ClrScr Delay DelLine GotoXY
    syn keyword pascalFunction	HighVideo InsLine KeyPressed LowVideo NormVideo
    syn keyword pascalFunction	NoSound ReadKey Sound TextBackground TextColor
    syn keyword pascalFunction	TextMode WhereX WhereY Window
    syn keyword pascalPredefined CheckBreak CheckEOF CheckSnow DirectVideo
    syn keyword pascalPredefined LastMode TextAttr WindMin WindMax
    syn keyword pascalFunction BigCursor CursorOff CursorOn
    syn keyword pascalConstant Black Blue Green Cyan Red Magenta Brown
    syn keyword pascalConstant LightGray DarkGray LightBlue LightGreen
    syn keyword pascalConstant LightCyan LightRed LightMagenta Yellow White
    syn keyword pascalConstant Blink ScreenWidth ScreenHeight bw40
    syn keyword pascalConstant co40 bw80 co80 mono
    syn keyword pascalPredefined TextChar 

    " DOS unit
    syn keyword pascalFunction	AddDisk DiskFree DiskSize DosExitCode DosVersion
    syn keyword pascalFunction	EnvCount EnvStr Exec Expand FindClose FindFirst
    syn keyword pascalFunction	FindNext FSearch FSplit GetCBreak GetDate
    syn keyword pascalFunction	GetEnv GetFAttr GetFTime GetIntVec GetTime
    syn keyword pascalFunction	GetVerify Intr Keep MSDos PackTime SetCBreak
    syn keyword pascalFunction	SetDate SetFAttr SetFTime SetIntVec SetTime
    syn keyword pascalFunction	SetVerify SwapVectors UnPackTime
    syn keyword pascalConstant	FCarry FParity FAuxiliary FZero FSign FOverflow
    syn keyword pascalConstant	Hidden Sysfile VolumeId Directory Archive
    syn keyword pascalConstant	AnyFile fmClosed fmInput fmOutput fmInout
    syn keyword pascalConstant	TextRecNameLength TextRecBufSize
    syn keyword pascalType	ComStr PathStr DirStr NameStr ExtStr SearchRec
    syn keyword pascalType	FileRec TextBuf TextRec Registers DateTime
    syn keyword pascalPredefined DosError

    "Graph Unit
    syn keyword pascalFunction	Arc Bar Bar3D Circle ClearDevice ClearViewPort
    syn keyword pascalFunction	CloseGraph DetectGraph DrawPoly Ellipse
    syn keyword pascalFunction	FillEllipse FillPoly FloodFill GetArcCoords
    syn keyword pascalFunction	GetAspectRatio GetBkColor GetColor
    syn keyword pascalFunction	GetDefaultPalette GetDriverName GetFillPattern
    syn keyword pascalFunction	GetFillSettings GetGraphMode GetImage
    syn keyword pascalFunction	GetLineSettings GetMaxColor GetMaxMode GetMaxX
    syn keyword pascalFunction	GetMaxY GetModeName GetModeRange GetPalette
    syn keyword pascalFunction	GetPaletteSize GetPixel GetTextSettings
    syn keyword pascalFunction	GetViewSettings GetX GetY GraphDefaults
    syn keyword pascalFunction	GraphErrorMsg GraphResult ImageSize InitGraph
    syn keyword pascalFunction	InstallUserDriver InstallUserFont Line LineRel
    syn keyword pascalFunction	LineTo MoveRel MoveTo OutText OutTextXY
    syn keyword pascalFunction	PieSlice PutImage PutPixel Rectangle
    syn keyword pascalFunction	RegisterBGIDriver RegisterBGIFont
    syn keyword pascalFunction	RestoreCRTMode Sector SetActivePage
    syn keyword pascalFunction	SetAllPallette SetAspectRatio SetBkColor
    syn keyword pascalFunction	SetColor SetFillPattern SetFillStyle
    syn keyword pascalFunction	SetGraphBufSize SetGraphMode SetLineStyle
    syn keyword pascalFunction	SetPalette SetRGBPalette SetTextJustify
    syn keyword pascalFunction	SetTextStyle SetUserCharSize SetViewPort
    syn keyword pascalFunction	SetVisualPage SetWriteMode TextHeight TextWidth
    syn keyword pascalType	ArcCoordsType FillPatternType FillSettingsType
    syn keyword pascalType	LineSettingsType PaletteType PointType
    syn keyword pascalType	TextSettingsType ViewPortType

    " string functions
    syn keyword pascalFunction	StrAlloc StrBufSize StrCat StrComp StrCopy
    syn keyword pascalFunction	StrDispose StrECopy StrEnd StrFmt StrIComp
    syn keyword pascalFunction	StrLCat StrLComp StrLCopy StrLen StrLFmt
    syn keyword pascalFunction	StrLIComp StrLower StrMove StrNew StrPas
    syn keyword pascalFunction	StrPCopy StrPLCopy StrPos StrRScan StrScan
    syn keyword pascalFunction	StrUpper
  endif

endif

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link pascalAcces		pascalStatement
hi def link pascalBoolean		Boolean
hi def link pascalComment		Comment
hi def link pascalConditional	Conditional
hi def link pascalConstant		Constant
hi def link pascalDelimiter	Identifier
hi def link pascalDirective	pascalStatement
hi def link pascalException	Exception
hi def link pascalFloat		Float
hi def link pascalFunction		Function
hi def link pascalLabel		Label
hi def link pascalMatrixDelimiter	Identifier
hi def link pascalModifier		Type
hi def link pascalNumber		Number
hi def link pascalOperator		Operator
hi def link pascalPredefined	pascalStatement
hi def link pascalPreProc		PreProc
hi def link pascalRepeat		Repeat
hi def link pascalSpaceError	Error
hi def link pascalStatement	Statement
hi def link pascalString		String
hi def link pascalStringEscape	Special
hi def link pascalStringEscapeGPC	Special
hi def link pascalStringError	Error
hi def link pascalStruct		pascalStatement
hi def link pascalSymbolOperator	pascalOperator
hi def link pascalTodo		Todo
hi def link pascalType		Type
hi def link pascalUnclassified	pascalStatement
"  hi def link pascalAsm		Assembler
hi def link pascalError		Error
hi def link pascalAsmKey		pascalStatement
hi def link pascalShowTab		Error



let b:current_syntax = "pascal"

" vim: ts=8 sw=2
