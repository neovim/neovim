" Vim syntax file
" Language:	NSIS script, for version of NSIS 1.91 and later
" Maintainer:	Alex Jakushev <Alex.Jakushev@kemek.lt>
" Last Change:	2004 May 12

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn case ignore


"COMMENTS
syn keyword nsisTodo	todo attention note fixme readme
syn region nsisComment	start=";"  end="$" contains=nsisTodo
syn region nsisComment	start="#"  end="$" contains=nsisTodo

"LABELS
syn match nsisLocalLabel	"\a\S\{-}:"
syn match nsisGlobalLabel	"\.\S\{-1,}:"

"PREPROCESSOR
syn match nsisPreprocSubst	"${.\{-}}"
syn match nsisDefine		"!define\>"
syn match nsisDefine		"!undef\>"
syn match nsisPreCondit		"!ifdef\>"
syn match nsisPreCondit		"!ifndef\>"
syn match nsisPreCondit		"!endif\>"
syn match nsisPreCondit		"!else\>"
syn match nsisMacro		"!macro\>"
syn match nsisMacro		"!macroend\>"
syn match nsisMacro		"!insertmacro\>"

"COMPILER UTILITY
syn match nsisInclude		"!include\>"
syn match nsisSystem		"!cd\>"
syn match nsisSystem		"!system\>"
syn match nsisSystem		"!packhdr\>"

"VARIABLES
syn match nsisUserVar		"$\d"
syn match nsisUserVar		"$R\d"
syn match nsisSysVar		"$INSTDIR"
syn match nsisSysVar		"$OUTDIR"
syn match nsisSysVar		"$CMDLINE"
syn match nsisSysVar		"$PROGRAMFILES"
syn match nsisSysVar		"$DESKTOP"
syn match nsisSysVar		"$EXEDIR"
syn match nsisSysVar		"$WINDIR"
syn match nsisSysVar		"$SYSDIR"
syn match nsisSysVar		"$TEMP"
syn match nsisSysVar		"$STARTMENU"
syn match nsisSysVar		"$SMPROGRAMS"
syn match nsisSysVar		"$SMSTARTUP"
syn match nsisSysVar		"$QUICKLAUNCH"
syn match nsisSysVar		"$HWNDPARENT"
syn match nsisSysVar		"$\\r"
syn match nsisSysVar		"$\\n"
syn match nsisSysVar		"$\$"

"STRINGS
syn region nsisString	start=/"/ skip=/'\|`/ end=/"/ contains=nsisPreprocSubst,nsisUserVar,nsisSysVar,nsisRegistry
syn region nsisString	start=/'/ skip=/"\|`/ end=/'/ contains=nsisPreprocSubst,nsisUserVar,nsisSysVar,nsisRegistry
syn region nsisString	start=/`/ skip=/"\|'/ end=/`/ contains=nsisPreprocSubst,nsisUserVar,nsisSysVar,nsisRegistry

"CONSTANTS
syn keyword nsisBoolean		true false on off

syn keyword nsisAttribOptions	hide show nevershow auto force try ifnewer normal silent silentlog
syn keyword nsisAttribOptions	smooth colored SET CUR END RO none listonly textonly both current all
syn keyword nsisAttribOptions	zlib bzip2 lzma

syn match nsisAttribOptions	'\/NOCUSTOM'
syn match nsisAttribOptions	'\/CUSTOMSTRING'
syn match nsisAttribOptions	'\/COMPONENTSONLYONCUSTOM'
syn match nsisAttribOptions	'\/windows'
syn match nsisAttribOptions	'\/r'
syn match nsisAttribOptions	'\/oname'
syn match nsisAttribOptions	'\/REBOOTOK'
syn match nsisAttribOptions	'\/SILENT'
syn match nsisAttribOptions	'\/FILESONLY'
syn match nsisAttribOptions	'\/SHORT'

syn keyword nsisExecShell	SW_SHOWNORMAL SW_SHOWMAXIMIZED SW_SHOWMINIMIZED

syn keyword nsisRegistry	HKCR HKLM HKCU HKU HKCC HKDD HKPD
syn keyword nsisRegistry	HKEY_CLASSES_ROOT HKEY_LOCAL_MACHINE HKEY_CURRENT_USER HKEY_USERS
syn keyword nsisRegistry	HKEY_CURRENT_CONFIG HKEY_DYN_DATA HKEY_PERFORMANCE_DATA

syn keyword nsisFileAttrib	NORMAL ARCHIVE HIDDEN OFFLINE READONLY SYSTEM TEMPORARY
syn keyword nsisFileAttrib	FILE_ATTRIBUTE_NORMAL FILE_ATTRIBUTE_ARCHIVE FILE_ATTRIBUTE_HIDDEN
syn keyword nsisFileAttrib	FILE_ATTRIBUTE_OFFLINE FILE_ATTRIBUTE_READONLY FILE_ATTRIBUTE_SYSTEM
syn keyword nsisFileAttrib	FILE_ATTRIBUTE_TEMPORARY

syn keyword nsisMessageBox	MB_OK MB_OKCANCEL MB_ABORTRETRYIGNORE MB_RETRYCANCEL MB_YESNO MB_YESNOCANCEL
syn keyword nsisMessageBox	MB_ICONEXCLAMATION MB_ICONINFORMATION MB_ICONQUESTION MB_ICONSTOP
syn keyword nsisMessageBox	MB_TOPMOST MB_SETFOREGROUND MB_RIGHT
syn keyword nsisMessageBox	MB_DEFBUTTON1 MB_DEFBUTTON2 MB_DEFBUTTON3 MB_DEFBUTTON4
syn keyword nsisMessageBox	IDABORT IDCANCEL IDIGNORE IDNO IDOK IDRETRY IDYES

syn match nsisNumber		"\<[^0]\d*\>"
syn match nsisNumber		"\<0x\x\+\>"
syn match nsisNumber		"\<0\o*\>"


"INSTALLER ATTRIBUTES - General installer configuration
syn keyword nsisAttribute	OutFile Name Caption SubCaption BrandingText Icon
syn keyword nsisAttribute	WindowIcon BGGradient SilentInstall SilentUnInstall
syn keyword nsisAttribute	CRCCheck MiscButtonText InstallButtonText FileErrorText

"INSTALLER ATTRIBUTES - Install directory configuration
syn keyword nsisAttribute	InstallDir InstallDirRegKey

"INSTALLER ATTRIBUTES - License page configuration
syn keyword nsisAttribute	LicenseText LicenseData

"INSTALLER ATTRIBUTES - Component page configuration
syn keyword nsisAttribute	ComponentText InstType EnabledBitmap DisabledBitmap SpaceTexts

"INSTALLER ATTRIBUTES - Directory page configuration
syn keyword nsisAttribute	DirShow DirText AllowRootDirInstall

"INSTALLER ATTRIBUTES - Install page configuration
syn keyword nsisAttribute	InstallColors InstProgressFlags AutoCloseWindow
syn keyword nsisAttribute	ShowInstDetails DetailsButtonText CompletedText

"INSTALLER ATTRIBUTES - Uninstall configuration
syn keyword nsisAttribute	UninstallText UninstallIcon UninstallCaption
syn keyword nsisAttribute	UninstallSubCaption ShowUninstDetails UninstallButtonText

"COMPILER ATTRIBUTES
syn keyword nsisCompiler	SetOverwrite SetCompress SetCompressor SetDatablockOptimize SetDateSave


"FUNCTIONS - general purpose
syn keyword nsisInstruction	SetOutPath File Exec ExecWait ExecShell
syn keyword nsisInstruction	Rename Delete RMDir

"FUNCTIONS - registry & ini
syn keyword nsisInstruction	WriteRegStr WriteRegExpandStr WriteRegDWORD WriteRegBin
syn keyword nsisInstruction	WriteINIStr ReadRegStr ReadRegDWORD ReadINIStr ReadEnvStr
syn keyword nsisInstruction	ExpandEnvStrings DeleteRegValue DeleteRegKey EnumRegKey
syn keyword nsisInstruction	EnumRegValue DeleteINISec DeleteINIStr

"FUNCTIONS - general purpose, advanced
syn keyword nsisInstruction	CreateDirectory CopyFiles SetFileAttributes CreateShortCut
syn keyword nsisInstruction	GetFullPathName SearchPath GetTempFileName CallInstDLL
syn keyword nsisInstruction	RegDLL UnRegDLL GetDLLVersion GetDLLVersionLocal
syn keyword nsisInstruction	GetFileTime GetFileTimeLocal

"FUNCTIONS - Branching, flow control, error checking, user interaction, etc instructions
syn keyword nsisInstruction	Goto Call Return IfErrors ClearErrors SetErrors FindWindow
syn keyword nsisInstruction	SendMessage IsWindow IfFileExists MessageBox StrCmp
syn keyword nsisInstruction	IntCmp IntCmpU Abort Quit GetFunctionAddress GetLabelAddress
syn keyword nsisInstruction	GetCurrentAddress

"FUNCTIONS - File and directory i/o instructions
syn keyword nsisInstruction	FindFirst FindNext FindClose FileOpen FileClose FileRead
syn keyword nsisInstruction	FileWrite FileReadByte FileWriteByte FileSeek

"FUNCTIONS - Misc instructions
syn keyword nsisInstruction	SetDetailsView SetDetailsPrint SetAutoClose DetailPrint
syn keyword nsisInstruction	Sleep BringToFront HideWindow SetShellVarContext

"FUNCTIONS - String manipulation support
syn keyword nsisInstruction	StrCpy StrLen

"FUNCTIONS - Stack support
syn keyword nsisInstruction	Push Pop Exch

"FUNCTIONS - Integer manipulation support
syn keyword nsisInstruction	IntOp IntFmt

"FUNCTIONS - Rebooting support
syn keyword nsisInstruction	Reboot IfRebootFlag SetRebootFlag

"FUNCTIONS - Uninstaller instructions
syn keyword nsisInstruction	WriteUninstaller

"FUNCTIONS - Install logging instructions
syn keyword nsisInstruction	LogSet LogText

"FUNCTIONS - Section management instructions
syn keyword nsisInstruction	SectionSetFlags SectionGetFlags SectionSetText
syn keyword nsisInstruction	SectionGetText


"SPECIAL FUNCTIONS - install
syn match nsisCallback		"\.onInit"
syn match nsisCallback		"\.onUserAbort"
syn match nsisCallback		"\.onInstSuccess"
syn match nsisCallback		"\.onInstFailed"
syn match nsisCallback		"\.onVerifyInstDir"
syn match nsisCallback		"\.onNextPage"
syn match nsisCallback		"\.onPrevPage"
syn match nsisCallback		"\.onSelChange"

"SPECIAL FUNCTIONS - uninstall
syn match nsisCallback		"un\.onInit"
syn match nsisCallback		"un\.onUserAbort"
syn match nsisCallback		"un\.onInstSuccess"
syn match nsisCallback		"un\.onInstFailed"
syn match nsisCallback		"un\.onVerifyInstDir"
syn match nsisCallback		"un\.onNextPage"


"STATEMENTS - sections
syn keyword nsisStatement	Section SectionIn SectionEnd SectionDivider
syn keyword nsisStatement	AddSize

"STATEMENTS - functions
syn keyword nsisStatement	Function FunctionEnd

"STATEMENTS - pages
syn keyword nsisStatement	Page UninstPage PageEx PageExEnc PageCallbacks


"ERROR
syn keyword nsisError		UninstallExeName


" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_nsis_syn_inits")

  if version < 508
    let did_nsys_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif


  HiLink nsisInstruction		Function
  HiLink nsisComment			Comment
  HiLink nsisLocalLabel			Label
  HiLink nsisGlobalLabel		Label
  HiLink nsisStatement			Statement
  HiLink nsisString			String
  HiLink nsisBoolean			Boolean
  HiLink nsisAttribOptions		Constant
  HiLink nsisExecShell			Constant
  HiLink nsisFileAttrib			Constant
  HiLink nsisMessageBox			Constant
  HiLink nsisRegistry			Identifier
  HiLink nsisNumber			Number
  HiLink nsisError			Error
  HiLink nsisUserVar			Identifier
  HiLink nsisSysVar			Identifier
  HiLink nsisAttribute			Type
  HiLink nsisCompiler			Type
  HiLink nsisTodo			Todo
  HiLink nsisCallback			Operator
  " preprocessor commands
  HiLink nsisPreprocSubst		PreProc
  HiLink nsisDefine			Define
  HiLink nsisMacro			Macro
  HiLink nsisPreCondit			PreCondit
  HiLink nsisInclude			Include
  HiLink nsisSystem			PreProc

  delcommand HiLink
endif

let b:current_syntax = "nsis"

