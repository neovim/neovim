" Vim syntax file
" Language:		NSIS script, for version of NSIS 3.03 and later
" Maintainer:		Ken Takata
" URL:			https://github.com/k-takata/vim-nsis
" Previous Maintainer:	Alex Jakushev <Alex.Jakushev@kemek.lt>
" Last Change:		2018-02-07

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn case ignore


"Pseudo definitions
syn match nsisLine nextgroup=@nsisPseudoStatement skipwhite "^"
syn cluster nsisPseudoStatement	contains=nsisFirstComment,nsisLocalLabel,nsisGlobalLabel
syn cluster nsisPseudoStatement add=nsisDefine,nsisPreCondit,nsisMacro,nsisInclude,nsisSystem
syn cluster nsisPseudoStatement add=nsisAttribute,nsisCompiler,nsisVersionInfo,nsisInstruction,nsisStatement

"COMMENTS (4.1)
syn keyword nsisTodo	todo attention note fixme readme
syn region nsisComment	start="[;#]" end="$" contains=nsisTodo,nsisLineContinuation,@Spell oneline
syn region nsisComment	start=".\@1<=/\*" end="\*/" contains=nsisTodo,@Spell
syn region nsisFirstComment  start="/\*" end="\*/" contained contains=nsisTodo,@Spell skipwhite
			\ nextgroup=@nsisPseudoStatement

syn match nsisLineContinuation	"\\$"

"STRINGS (4.1)
syn region nsisString	start=/"/ end=/"/ contains=@nsisStringItems,@Spell
syn region nsisString	start=/'/ end=/'/ contains=@nsisStringItems,@Spell
syn region nsisString	start=/`/ end=/`/ contains=@nsisStringItems,@Spell

syn cluster nsisStringItems	contains=nsisPreprocSubst,nsisPreprocLangStr,nsisPreprocEnvVar,nsisUserVar,nsisSysVar,nsisRegistry,nsisLineContinuation

"NUMBERS (4.1)
syn match nsisNumber		"\<[1-9]\d*\>"
syn match nsisNumber		"\<0x\x\+\>"
syn match nsisNumber		"\<0\o*\>"

"STRING REPLACEMENT (5.4, 4.9.15.2, 5.3.1)
syn region nsisPreprocSubst	start="\${" end="}" contains=nsisPreprocSubst,nsisPreprocLangStr,nsisPreprocEnvVar
syn region nsisPreprocLangStr	start="\$(" end=")" contains=nsisPreprocSubst,nsisPreprocLangStr,nsisPreprocEnvVar
syn region nsisPreprocEnvVar	start="\$%" end="%" contains=nsisPreprocSubst,nsisPreprocLangStr,nsisPreprocEnvVar

"VARIABLES (4.2.2)
syn match nsisUserVar		"$\d"
syn match nsisUserVar		"$R\d"
syn match nsisSysVar		"$INSTDIR"
syn match nsisSysVar		"$OUTDIR"
syn match nsisSysVar		"$CMDLINE"
syn match nsisSysVar		"$LANGUAGE"
"CONSTANTS (4.2.3)
syn match nsisSysVar		"$PROGRAMFILES"
syn match nsisSysVar		"$PROGRAMFILES32"
syn match nsisSysVar		"$PROGRAMFILES64"
syn match nsisSysVar		"$COMMONFILES"
syn match nsisSysVar		"$COMMONFILES32"
syn match nsisSysVar		"$COMMONFILES64"
syn match nsisSysVar		"$DESKTOP"
syn match nsisSysVar		"$EXEDIR"
syn match nsisSysVar		"$EXEFILE"
syn match nsisSysVar		"$EXEPATH"
syn match nsisSysVar		"${NSISDIR}"
syn match nsisSysVar		"$WINDIR"
syn match nsisSysVar		"$SYSDIR"
syn match nsisSysVar		"$TEMP"
syn match nsisSysVar		"$STARTMENU"
syn match nsisSysVar		"$SMPROGRAMS"
syn match nsisSysVar		"$SMSTARTUP"
syn match nsisSysVar		"$QUICKLAUNCH"
syn match nsisSysVar		"$DOCUMENTS"
syn match nsisSysVar		"$SENDTO"
syn match nsisSysVar		"$RECENT"
syn match nsisSysVar		"$FAVORITES"
syn match nsisSysVar		"$MUSIC"
syn match nsisSysVar		"$PICTURES"
syn match nsisSysVar		"$VIDEOS"
syn match nsisSysVar		"$NETHOOD"
syn match nsisSysVar		"$FONTS"
syn match nsisSysVar		"$TEMPLATES"
syn match nsisSysVar		"$APPDATA"
syn match nsisSysVar		"$LOCALAPPDATA"
syn match nsisSysVar		"$PRINTHOOD"
syn match nsisSysVar		"$INTERNET_CACHE"
syn match nsisSysVar		"$COOKIES"
syn match nsisSysVar		"$HISTORY"
syn match nsisSysVar		"$PROFILE"
syn match nsisSysVar		"$ADMINTOOLS"
syn match nsisSysVar		"$RESOURCES"
syn match nsisSysVar		"$RESOURCES_LOCALIZED"
syn match nsisSysVar		"$CDBURN_AREA"
syn match nsisSysVar		"$HWNDPARENT"
syn match nsisSysVar		"$PLUGINSDIR"
syn match nsisSysVar		"$\\r"
syn match nsisSysVar		"$\\n"
syn match nsisSysVar		"$\\t"
syn match nsisSysVar		"$\$"
syn match nsisSysVar		"$\\["'`]"

"LABELS (4.3)
syn match nsisLocalLabel	contained "[^-+!$0-9;#. \t/*][^ \t:;#]*:\ze\%($\|[ \t;#]\|\/\*\)"
syn match nsisGlobalLabel	contained "\.[^-+!$0-9;# \t/*][^ \t:;#]*:\ze\%($\|[ \t;#]\|\/\*\)"

"CONSTANTS
syn keyword nsisBoolean		contained true false
syn keyword nsisOnOff		contained on off

syn keyword nsisRegistry	contained HKCR HKLM HKCU HKU HKCC HKDD HKPD SHCTX
syn keyword nsisRegistry	contained HKCR32 HKCR64 HKCU32 HKCU64 HKLM32 HKLM64
syn keyword nsisRegistry	contained HKEY_CLASSES_ROOT HKEY_LOCAL_MACHINE HKEY_CURRENT_USER HKEY_USERS
syn keyword nsisRegistry	contained HKEY_CLASSES_ROOT32 HKEY_CLASSES_ROOT64
syn keyword nsisRegistry	contained HKEY_CURRENT_USER32 HKEY_CURRENT_USER64
syn keyword nsisRegistry	contained HKEY_LOCAL_MACHINE32 HKEY_LOCAL_MACHINE64
syn keyword nsisRegistry	contained HKEY_CURRENT_CONFIG HKEY_DYN_DATA HKEY_PERFORMANCE_DATA
syn keyword nsisRegistry	contained SHELL_CONTEXT


" common options
syn cluster nsisAnyOpt		contains=nsisComment,nsisLineContinuation,nsisPreprocSubst,nsisPreprocLangStr,nsisPreprocEnvVar,nsisUserVar,nsisSysVar,nsisString,nsisNumber
syn region nsisBooleanOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisBoolean
syn region nsisOnOffOpt		contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisOnOff
syn region nsisLangOpt		contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisLangKwd
syn match nsisLangKwd		contained "/LANG\>"
syn region nsisFontOpt		contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisFontKwd
syn match nsisFontKwd		contained "/\%(ITALIC\|UNDERLINE\|STRIKE\)\>"

"STATEMENTS - pages (4.5)
syn keyword nsisStatement	contained Page UninstPage nextgroup=nsisPageOpt skipwhite
syn region nsisPageOpt		contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisPageKwd
syn keyword nsisPageKwd		contained custom license components directory instfiles uninstConfirm
syn match nsisPageKwd		contained "/ENABLECANCEL\>"

syn keyword nsisStatement	contained PageEx nextgroup=nsisPageExOpt skipwhite
syn region nsisPageExOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisPageExKwd
syn match nsisPageExKwd		contained "\<\%(un\.\)\?\%(custom\|license\|components\|directory\|instfiles\|uninstConfirm\)\>"

syn keyword nsisStatement	contained PageExEnd PageCallbacks

"STATEMENTS - sections (4.6.1)
syn keyword nsisStatement	contained AddSize SectionEnd SectionGroupEnd

syn keyword nsisStatement	contained Section nextgroup=nsisSectionOpt skipwhite
syn region nsisSectionOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisSectionKwd
syn match nsisSectionKwd	contained "/o\>"

syn keyword nsisStatement	contained SectionIn nextgroup=nsisSectionInOpt skipwhite
syn region nsisSectionInOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisSectionInKwd
syn keyword nsisSectionInKwd	contained RO

syn keyword nsisStatement	contained SectionGroup nextgroup=nsisSectionGroupOpt skipwhite
syn region nsisSectionGroupOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisSectionGroupKwd
syn match nsisSectionGroupKwd	contained "/e\>"

"STATEMENTS - functions (4.7.1)
syn keyword nsisStatement	contained Function FunctionEnd


"STATEMENTS - LogicLib.nsh
syn match nsisStatement		"${If}"
syn match nsisStatement		"${IfNot}"
syn match nsisStatement		"${Unless}"
syn match nsisStatement		"${ElseIf}"
syn match nsisStatement		"${ElseIfNot}"
syn match nsisStatement		"${ElseUnless}"
syn match nsisStatement		"${Else}"
syn match nsisStatement		"${EndIf}"
syn match nsisStatement		"${EndUnless}"
syn match nsisStatement		"${AndIf}"
syn match nsisStatement		"${AndIfNot}"
syn match nsisStatement		"${AndUnless}"
syn match nsisStatement		"${OrIf}"
syn match nsisStatement		"${OrIfNot}"
syn match nsisStatement		"${OrUnless}"
syn match nsisStatement		"${IfThen}"
syn match nsisStatement		"${IfNotThen}"
syn match nsisStatement		"${||\?}" nextgroup=@nsisPseudoStatement skipwhite
syn match nsisStatement		"${IfCmd}" nextgroup=@nsisPseudoStatement skipwhite
syn match nsisStatement		"${Select}"
syn match nsisStatement		"${Case}"
syn match nsisStatement		"${Case[2-5]}"
syn match nsisStatement		"${CaseElse}"
syn match nsisStatement		"${Default}"
syn match nsisStatement		"${EndSelect}"
syn match nsisStatement		"${Switch}"
syn match nsisStatement		"${EndSwitch}"
syn match nsisStatement		"${Break}"
syn match nsisStatement		"${Do}"
syn match nsisStatement		"${DoWhile}"
syn match nsisStatement		"${DoUntil}"
syn match nsisStatement		"${ExitDo}"
syn match nsisStatement		"${Continue}"
syn match nsisStatement		"${Loop}"
syn match nsisStatement		"${LoopWhile}"
syn match nsisStatement		"${LoopUntil}"
syn match nsisStatement		"${For}"
syn match nsisStatement		"${ForEach}"
syn match nsisStatement		"${ExitFor}"
syn match nsisStatement		"${Next}"
"STATEMENTS - Memento.nsh
syn match nsisStatement		"${MementoSection}"
syn match nsisStatement		"${MementoSectionEnd}"


"USER VARIABLES (4.2.1)
syn keyword nsisInstruction	contained Var nextgroup=nsisVarOpt skipwhite
syn region nsisVarOpt		contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisVarKwd
syn match nsisVarKwd		contained "/GLOBAL\>"

"INSTALLER ATTRIBUTES (4.8.1)
syn keyword nsisAttribute	contained Caption ChangeUI CheckBitmap CompletedText ComponentText
syn keyword nsisAttribute	contained DetailsButtonText DirText DirVar
syn keyword nsisAttribute	contained FileErrorText Icon InstallButtonText
syn keyword nsisAttribute	contained InstallDir InstProgressFlags
syn keyword nsisAttribute	contained LicenseData LicenseText
syn keyword nsisAttribute	contained MiscButtonText Name OutFile
syn keyword nsisAttribute	contained SpaceTexts SubCaption UninstallButtonText UninstallCaption
syn keyword nsisAttribute	contained UninstallIcon UninstallSubCaption UninstallText

syn keyword nsisAttribute	contained AddBrandingImage nextgroup=nsisAddBrandingImageOpt skipwhite
syn region nsisAddBrandingImageOpt  contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisAddBrandingImageKwd
syn keyword nsisAddBrandingImageKwd contained left right top bottom width height

syn keyword nsisAttribute	contained nextgroup=nsisBooleanOpt skipwhite
			\ AllowRootDirInstall AutoCloseWindow

syn keyword nsisAttribute	contained BGFont nextgroup=nsisFontOpt skipwhite

syn keyword nsisAttribute	contained BGGradient nextgroup=nsisBGGradientOpt skipwhite
syn region nsisBGGradientOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisBGGradientKwd
syn keyword nsisBGGradientKwd	contained off

syn keyword nsisAttribute	contained BrandingText nextgroup=nsisBrandingTextOpt skipwhite
syn region nsisBrandingTextOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisBrandingTextKwd
syn match nsisBrandingTextKwd	contained "/TRIM\%(LEFT\|RIGHT\|CENTER\)\>"

syn keyword nsisAttribute	contained CRCCheck nextgroup=nsisCRCCheckOpt skipwhite
syn region nsisCRCCheckOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisCRCCheckKwd
syn keyword nsisCRCCheckKwd	contained on off force

syn keyword nsisAttribute	contained DirVerify nextgroup=nsisDirVerifyOpt skipwhite
syn region nsisDirVerifyOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisDirVerifyKwd
syn keyword nsisDirVerifyKwd	contained auto leave

syn keyword nsisAttribute	contained InstallColors nextgroup=nsisInstallColorsOpt skipwhite
syn region nsisInstallColorsOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisInstallColorsKwd
syn match nsisInstallColorsKwd	contained "/windows\>"

syn keyword nsisAttribute	contained InstallDirRegKey nextgroup=nsisRegistryOpt skipwhite

syn keyword nsisAttribute	contained InstType nextgroup=nsisInstTypeOpt skipwhite
syn region nsisInstTypeOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisInstTypeKwd
syn match nsisInstTypeKwd	contained "/\%(NOCUSTOM\|CUSTOMSTRING\|COMPONENTSONLYONCUSTOM\)\>"

syn keyword nsisAttribute	contained LicenseBkColor nextgroup=nsisLicenseBkColorOpt skipwhite
syn region nsisLicenseBkColorOpt contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisLicenseBkColorKwd
syn match nsisLicenseBkColorKwd  contained "/\%(gray\|windows\)\>"

syn keyword nsisAttribute	contained LicenseForceSelection nextgroup=nsisLicenseForceSelectionOpt skipwhite
syn region nsisLicenseForceSelectionOpt  contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisLicenseForceSelectionKwd
syn keyword nsisLicenseForceSelectionKwd contained checkbox radiobuttons off

syn keyword nsisAttribute	contained ManifestDPIAware nextgroup=nsisManifestDPIAwareOpt skipwhite
syn region nsisManifestDPIAwareOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisManifestDPIAwareKwd
syn keyword nsisManifestDPIAwareKwd	contained notset true false

syn keyword nsisAttribute	contained ManifestSupportedOS nextgroup=nsisManifestSupportedOSOpt skipwhite
syn region nsisManifestSupportedOSOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisManifestSupportedOSKwd
syn match nsisManifestSupportedOSKwd	contained "\<\%(none\|all\|WinVista\|Win7\|Win8\|Win8\.1\|Win10\)\>"

syn keyword nsisAttribute	contained RequestExecutionLevel nextgroup=nsisRequestExecutionLevelOpt skipwhite
syn region nsisRequestExecutionLevelOpt  contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisRequestExecutionLevelKwd
syn keyword nsisRequestExecutionLevelKwd contained none user highest admin

syn keyword nsisAttribute	contained SetFont nextgroup=nsisLangOpt skipwhite

syn keyword nsisAttribute	contained nextgroup=nsisShowInstDetailsOpt skipwhite
			\ ShowInstDetails ShowUninstDetails
syn region nsisShowInstDetailsOpt  contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisShowInstDetailsKwd
syn keyword nsisShowInstDetailsKwd contained hide show nevershow

syn keyword nsisAttribute	contained SilentInstall nextgroup=nsisSilentInstallOpt skipwhite
syn region nsisSilentInstallOpt	 contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisSilentInstallKwd
syn keyword nsisSilentInstallKwd contained normal silent silentlog

syn keyword nsisAttribute	contained SilentUnInstall nextgroup=nsisSilentUnInstallOpt skipwhite
syn region nsisSilentUnInstallOpt  contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisSilentUnInstallKwd
syn keyword nsisSilentUnInstallKwd contained normal silent

syn keyword nsisAttribute	contained nextgroup=nsisOnOffOpt skipwhite
			\ WindowIcon XPStyle

"COMPILER FLAGS (4.8.2)
syn keyword nsisCompiler	contained nextgroup=nsisOnOffOpt skipwhite
			\ AllowSkipFiles SetDatablockOptimize SetDateSave

syn keyword nsisCompiler	contained FileBufSize SetCompressorDictSize

syn keyword nsisCompiler	contained SetCompress nextgroup=nsisSetCompressOpt skipwhite
syn region nsisSetCompressOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisSetCompressKwd
syn keyword nsisSetCompressKwd  contained auto force off

syn keyword nsisCompiler	contained SetCompressor nextgroup=nsisSetCompressorOpt skipwhite
syn region nsisSetCompressorOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisSetCompressorKwd
syn keyword nsisSetCompressorKwd  contained zlib bzip2 lzma
syn match nsisSetCompressorKwd	contained "/\%(SOLID\|FINAL\)"

syn keyword nsisCompiler	contained SetOverwrite nextgroup=nsisSetOverwriteOpt skipwhite
syn region nsisSetOverwriteOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisSetOverwriteKwd
syn keyword nsisSetOverwriteKwd	contained on off try ifnewer ifdiff lastused

syn keyword nsisCompiler	contained Unicode nextgroup=nsisBooleanOpt skipwhite

"VERSION INFORMATION (4.8.3)
syn keyword nsisVersionInfo	contained VIAddVersionKey nextgroup=nsisLangOpt skipwhite

syn keyword nsisVersionInfo	contained VIProductVersion VIFileVersion


"FUNCTIONS - basic (4.9.1)
syn keyword nsisInstruction	contained Delete Rename nextgroup=nsisDeleteOpt skipwhite
syn region nsisDeleteOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisDeleteKwd
syn match nsisDeleteKwd		contained "/REBOOTOK\>"

syn keyword nsisInstruction	contained Exec ExecWait SetOutPath

syn keyword nsisInstruction	contained ExecShell ExecShellWait nextgroup=nsisExecShellOpt skipwhite
syn region nsisExecShellOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisExecShellKwd
syn keyword nsisExecShellKwd	contained SW_SHOWDEFAULT SW_SHOWNORMAL SW_SHOWMAXIMIZED SW_SHOWMINIMIZED SW_HIDE
syn match nsisExecShellKwd	contained "/INVOKEIDLIST\>"

syn keyword nsisInstruction	contained File nextgroup=nsisFileOpt skipwhite
syn region nsisFileOpt		contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisFileKwd
syn match nsisFileKwd		contained "/\%(nonfatal\|[arx]\|oname\)\>"

syn keyword nsisInstruction	contained ReserveFile nextgroup=nsisReserveFileOpt skipwhite
syn region nsisReserveFileOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisReserveFileKwd
syn match nsisReserveFileKwd	contained "/\%(nonfatal\|[rx]\|plugin\)\>"

syn keyword nsisInstruction	contained RMDir nextgroup=nsisRMDirOpt skipwhite
syn region nsisRMDirOpt		contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisRMDirKwd
syn match nsisRMDirKwd		contained "/\%(REBOOTOK\|r\)\>"


"FUNCTIONS - registry & ini (4.9.2)
syn keyword nsisInstruction	contained DeleteINISec DeleteINIStr FlushINI ReadINIStr WriteINIStr
syn keyword nsisInstruction	contained ExpandEnvStrings ReadEnvStr

syn keyword nsisInstruction	contained DeleteRegKey nextgroup=nsisDeleteRegKeyOpt skipwhite
syn region nsisDeleteRegKeyOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisDeleteRegKeyKwd,nsisRegistry
syn match nsisDeleteRegKeyKwd	contained "/ifempty\>"

syn keyword nsisInstruction	contained nextgroup=nsisRegistryOpt skipwhite
			\ DeleteRegValue EnumRegKey EnumRegValue ReadRegDWORD ReadRegStr WriteRegBin WriteRegDWORD WriteRegExpandStr WriteRegStr
syn region nsisRegistryOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisRegistry

syn keyword nsisInstruction	contained WriteRegMultiStr nextgroup=nsisWriteRegMultiStrOpt skipwhite
syn region nsisWriteRegMultiStrOpt contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisRegistry,nsisWriteRegMultiStrKwd
syn match nsisWriteRegMultiStrKwd  contained "/REGEDIT5\>"

syn keyword nsisInstruction	contained SetRegView nextgroup=nsisSetRegViewOpt skipwhite
syn region nsisSetRegViewOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisSetRegViewKwd
syn keyword nsisSetRegViewKwd	contained default lastused

"FUNCTIONS - general purpose (4.9.3)
syn keyword nsisInstruction	contained CallInstDLL CreateDirectory GetDLLVersion
syn keyword nsisInstruction	contained GetDLLVersionLocal GetFileTime GetFileTimeLocal
syn keyword nsisInstruction	contained GetTempFileName SearchPath RegDLL UnRegDLL

syn keyword nsisInstruction	contained CopyFiles nextgroup=nsisCopyFilesOpt skipwhite
syn region nsisCopyFilesOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisCopyFilesKwd
syn match nsisCopyFilesKwd	contained "/\%(SILENT\|FILESONLY\)\>"

syn keyword nsisInstruction	contained CreateShortcut nextgroup=nsisCreateShortcutOpt skipwhite
syn region nsisCreateShortcutOpt contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisCreateShortcutKwd
syn match nsisCreateShortcutKwd	 contained "/NoWorkingDir\>"

syn keyword nsisInstruction	contained GetFullPathName nextgroup=nsisGetFullPathNameOpt skipwhite
syn region nsisGetFullPathNameOpt contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisGetFullPathNameKwd
syn match nsisGetFullPathNameKwd  contained "/SHORT\>"

syn keyword nsisInstruction	contained SetFileAttributes nextgroup=nsisSetFileAttributesOpt skipwhite
syn region nsisSetFileAttributesOpt  contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisFileAttrib
syn keyword nsisFileAttrib	contained NORMAL ARCHIVE HIDDEN OFFLINE READONLY SYSTEM TEMPORARY
syn keyword nsisFileAttrib	contained FILE_ATTRIBUTE_NORMAL FILE_ATTRIBUTE_ARCHIVE FILE_ATTRIBUTE_HIDDEN
syn keyword nsisFileAttrib	contained FILE_ATTRIBUTE_OFFLINE FILE_ATTRIBUTE_READONLY FILE_ATTRIBUTE_SYSTEM
syn keyword nsisFileAttrib	contained FILE_ATTRIBUTE_TEMPORARY

"FUNCTIONS - Flow Control (4.9.4)
syn keyword nsisInstruction	contained Abort Call ClearErrors GetCurrentAddress
syn keyword nsisInstruction	contained GetFunctionAddress GetLabelAddress Goto
syn keyword nsisInstruction	contained IfAbort IfErrors IfFileExists IfRebootFlag IfSilent
syn keyword nsisInstruction	contained IntCmp IntCmpU Int64Cmp Int64CmpU IntPtrCmp IntPtrCmpU
syn keyword nsisInstruction	contained Return Quit SetErrors StrCmp StrCmpS

syn keyword nsisInstruction	contained MessageBox nextgroup=nsisMessageBoxOpt skipwhite
syn region nsisMessageBoxOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisMessageBox
syn keyword nsisMessageBox	contained MB_OK MB_OKCANCEL MB_ABORTRETRYIGNORE MB_RETRYCANCEL MB_YESNO MB_YESNOCANCEL
syn keyword nsisMessageBox	contained MB_ICONEXCLAMATION MB_ICONINFORMATION MB_ICONQUESTION MB_ICONSTOP MB_USERICON
syn keyword nsisMessageBox	contained MB_TOPMOST MB_SETFOREGROUND MB_RIGHT MB_RTLREADING
syn keyword nsisMessageBox	contained MB_DEFBUTTON1 MB_DEFBUTTON2 MB_DEFBUTTON3 MB_DEFBUTTON4
syn keyword nsisMessageBox	contained IDABORT IDCANCEL IDIGNORE IDNO IDOK IDRETRY IDYES
syn match nsisMessageBox	contained "/SD\>"

"FUNCTIONS - File and directory i/o instructions (4.9.5)
syn keyword nsisInstruction	contained FileClose FileOpen FileRead FileReadUTF16LE
syn keyword nsisInstruction	contained FileReadByte FileReadWord FileSeek FileWrite
syn keyword nsisInstruction	contained FileWriteByte FileWriteWord
syn keyword nsisInstruction	contained FindClose FindFirst FindNext

syn keyword nsisInstruction	contained FileWriteUTF16LE nextgroup=nsisFileWriteUTF16LEOpt skipwhite
syn region nsisFileWriteUTF16LEOpt contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisFileWriteUTF16LEKwd
syn match nsisFileWriteUTF16LEKwd  contained "/BOM\>"

"FUNCTIONS - Uninstaller instructions (4.9.6)
syn keyword nsisInstruction	contained WriteUninstaller

"FUNCTIONS - Misc instructions (4.9.7)
syn keyword nsisInstruction	contained GetErrorLevel GetInstDirError InitPluginsDir Nop
syn keyword nsisInstruction	contained SetErrorLevel Sleep

syn keyword nsisInstruction	contained SetShellVarContext nextgroup=nsisSetShellVarContextOpt skipwhite
syn region nsisSetShellVarContextOpt  contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisSetShellVarContextKwd
syn keyword nsisSetShellVarContextKwd contained current all

"FUNCTIONS - String manipulation support (4.9.8)
syn keyword nsisInstruction	contained StrCpy StrLen

"FUNCTIONS - Stack support (4.9.9)
syn keyword nsisInstruction	contained Exch Push Pop

"FUNCTIONS - Integer manipulation support (4.9.10)
syn keyword nsisInstruction	contained IntFmt Int64Fmt IntOp IntPtrOp

"FUNCTIONS - Rebooting support (4.9.11)
syn keyword nsisInstruction	contained Reboot SetRebootFlag

"FUNCTIONS - Install logging instructions (4.9.12)
syn keyword nsisInstruction	contained LogSet nextgroup=nsisOnOffOpt skipwhite
syn keyword nsisInstruction	contained LogText

"FUNCTIONS - Section management instructions (4.9.13)
syn keyword nsisInstruction	contained SectionSetFlags SectionGetFlags SectionSetText
syn keyword nsisInstruction	contained SectionGetText SectionSetInstTypes SectionGetInstTypes
syn keyword nsisInstruction	contained SectionSetSize SectionGetSize SetCurInstType GetCurInstType
syn keyword nsisInstruction	contained InstTypeSetText InstTypeGetText

"FUNCTIONS - User Interface Instructions (4.9.14)
syn keyword nsisInstruction	contained BringToFront DetailPrint EnableWindow
syn keyword nsisInstruction	contained FindWindow GetDlgItem HideWindow IsWindow
syn keyword nsisInstruction	contained ShowWindow

syn keyword nsisInstruction	contained CreateFont nextgroup=nsisFontOpt skipwhite

syn keyword nsisInstruction	contained nextgroup=nsisBooleanOpt skipwhite
			\ LockWindow SetAutoClose

syn keyword nsisInstruction	contained SendMessage nextgroup=nsisSendMessageOpt skipwhite
syn region nsisSendMessageOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisSendMessageKwd
syn match nsisSendMessageKwd	contained "/TIMEOUT\>"

syn keyword nsisInstruction	contained SetBrandingImage nextgroup=nsisSetBrandingImageOpt skipwhite
syn region nsisSetBrandingImageOpt contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisSetBrandingImageKwd
syn match nsisSetBrandingImageKwd  contained "/\%(IMGID\|RESIZETOFIT\)\>"

syn keyword nsisInstruction	contained SetDetailsView nextgroup=nsisSetDetailsViewOpt skipwhite
syn region nsisSetDetailsViewOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisSetDetailsViewKwd
syn keyword nsisSetDetailsViewKwd	contained show hide

syn keyword nsisInstruction	contained SetDetailsPrint nextgroup=nsisSetDetailsPrintOpt skipwhite
syn region nsisSetDetailsPrintOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisSetDetailsPrintKwd
syn keyword nsisSetDetailsPrintKwd	contained none listonly textonly both lastused

syn keyword nsisInstruction	contained SetCtlColors nextgroup=nsisSetCtlColorsOpt skipwhite
syn region nsisSetCtlColorsOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisSetCtlColorsKwd
syn match nsisSetCtlColorsKwd	contained "/BRANDING\>"

syn keyword nsisInstruction	contained SetSilent nextgroup=nsisSetSilentOpt skipwhite
syn region nsisSetSilentOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisSetSilentKwd
syn keyword nsisSetSilentKwd	contained silent normal


"FUNCTIONS - Multiple Languages Instructions (4.9.15)
syn keyword nsisInstruction	contained LoadLanguageFile LangString LicenseLangString


"SPECIAL FUNCTIONS - install (4.7.2.1)
syn match nsisCallback		"\.onGUIInit"
syn match nsisCallback		"\.onInit"
syn match nsisCallback		"\.onInstFailed"
syn match nsisCallback		"\.onInstSuccess"
syn match nsisCallback		"\.onGUIEnd"
syn match nsisCallback		"\.onMouseOverSection"
syn match nsisCallback		"\.onRebootFailed"
syn match nsisCallback		"\.onSelChange"
syn match nsisCallback		"\.onUserAbort"
syn match nsisCallback		"\.onVerifyInstDir"

"SPECIAL FUNCTIONS - uninstall (4.7.2.2)
syn match nsisCallback		"un\.onGUIInit"
syn match nsisCallback		"un\.onInit"
syn match nsisCallback		"un\.onUninstFailed"
syn match nsisCallback		"un\.onUninstSuccess"
syn match nsisCallback		"un\.onGUIEnd"
syn match nsisCallback		"un\.onRebootFailed"
syn match nsisCallback		"un\.onSelChange"
syn match nsisCallback		"un\.onUserAbort"


"COMPILER UTILITY (5.1)
syn match nsisInclude		contained "!include\>" nextgroup=nsisIncludeOpt skipwhite
syn region nsisIncludeOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisIncludeKwd
syn match nsisIncludeKwd	contained "/\%(NONFATAL\|CHARSET\)\>"

syn match nsisSystem		contained "!addincludedir\>"

syn match nsisSystem		contained "!addplugindir\>" nextgroup=nsisAddplugindirOpt skipwhite
syn region nsisAddplugindirOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisAddplugindirKwd
syn match nsisAddplugindirKwd	contained "/\%(x86-ansi\|x86-unicode\)\>"

syn match nsisSystem		contained "!appendfile\>" nextgroup=nsisAppendfileOpt skipwhite
syn region nsisAppendfileOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisAppendfileKwd
syn match nsisAppendfileKwd	contained "/\%(CHARSET\|RawNL\)\>"

syn match nsisSystem		contained "!cd\>"

syn match nsisSystem		contained "!delfile\>" nextgroup=nsisDelfileOpt skipwhite
syn region nsisDelfileOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisDelfileKwd
syn match nsisDelfileKwd	contained "/nonfatal\>"

syn match nsisSystem		contained "!echo\>"
syn match nsisSystem		contained "!error\>"
syn match nsisSystem		contained "!execute\>"
syn match nsisSystem		contained "!makensis\>"
syn match nsisSystem		contained "!packhdr\>"
syn match nsisSystem		contained "!finalize\>"
syn match nsisSystem		contained "!system\>"
syn match nsisSystem		contained "!tempfile\>"
syn match nsisSystem		contained "!getdllversion\>"
syn match nsisSystem		contained "!gettlbversion\>"
syn match nsisSystem		contained "!warning\>"

syn match nsisSystem		contained "!pragma\>" nextgroup=nsisPragmaOpt skipwhite
syn region nsisPragmaOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisPragmaKwd
syn keyword nsisPragmaKwd	contained enable disable default push pop

syn match nsisSystem		contained "!verbose\>" nextgroup=nsisVerboseOpt skipwhite
syn region nsisVerboseOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisVerboseKwd
syn keyword nsisVerboseKwd	contained push pop

"PREPROCESSOR (5.4)
syn match nsisDefine		contained "!define\>" nextgroup=nsisDefineOpt skipwhite
syn region nsisDefineOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisDefineKwd
syn match nsisDefineKwd		contained "/\%(ifndef\|redef\|date\|utcdate\|math\|file\)\>"

syn match nsisDefine		contained "!undef\>"
syn match nsisPreCondit		contained "!ifdef\>"
syn match nsisPreCondit		contained "!ifndef\>"

syn match nsisPreCondit		contained "!if\>" nextgroup=nsisIfOpt skipwhite
syn region nsisIfOpt		contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisIfKwd
syn match nsisIfKwd		contained "/FileExists\>"

syn match nsisPreCondit		contained "!ifmacrodef\>"
syn match nsisPreCondit		contained "!ifmacrondef\>"
syn match nsisPreCondit		contained "!else\>"
syn match nsisPreCondit		contained "!endif\>"
syn match nsisMacro		contained "!insertmacro\>"
syn match nsisMacro		contained "!macro\>"
syn match nsisMacro		contained "!macroend\>"
syn match nsisMacro		contained "!macroundef\>"

syn match nsisMacro		contained "!searchparse\>" nextgroup=nsisSearchparseOpt skipwhite
syn region nsisSearchparseOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisSearchparseKwd
syn match nsisSearchparseKwd	contained "/\%(ignorecase\|noerrors\|file\)\>"

syn match nsisMacro		contained "!searchreplace\>" nextgroup=nsisSearchreplaceOpt skipwhite
syn region nsisSearchreplaceOpt	contained start="" end="$" transparent keepend contains=@nsisAnyOpt,nsisSearchreplaceKwd
syn match nsisSearchreplaceKwd	contained "/ignorecase\>"



" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link nsisInstruction		Function
hi def link nsisComment			Comment
hi def link nsisFirstComment		Comment
hi def link nsisLocalLabel		Label
hi def link nsisGlobalLabel		Label
hi def link nsisStatement		Statement
hi def link nsisString			String
hi def link nsisBoolean			Boolean
hi def link nsisOnOff			Boolean
hi def link nsisFontKwd			Constant
hi def link nsisLangKwd			Constant
hi def link nsisPageKwd			Constant
hi def link nsisPageExKwd		Constant
hi def link nsisSectionKwd		Constant
hi def link nsisSectionInKwd		Constant
hi def link nsisSectionGroupKwd		Constant
hi def link nsisVarKwd			Constant
hi def link nsisAddBrandingImageKwd	Constant
hi def link nsisBGGradientKwd		Constant
hi def link nsisBrandingTextKwd		Constant
hi def link nsisCRCCheckKwd		Constant
hi def link nsisDirVerifyKwd		Constant
hi def link nsisInstallColorsKwd	Constant
hi def link nsisInstTypeKwd		Constant
hi def link nsisLicenseBkColorKwd	Constant
hi def link nsisLicenseForceSelectionKwd Constant
hi def link nsisManifestDPIAwareKwd	Constant
hi def link nsisManifestSupportedOSKwd	Constant
hi def link nsisRequestExecutionLevelKwd Constant
hi def link nsisShowInstDetailsKwd	Constant
hi def link nsisSilentInstallKwd	Constant
hi def link nsisSilentUnInstallKwd	Constant
hi def link nsisSetCompressKwd		Constant
hi def link nsisSetCompressorKwd	Constant
hi def link nsisSetOverwriteKwd		Constant
hi def link nsisDeleteKwd		Constant
hi def link nsisExecShellKwd		Constant
hi def link nsisFileKwd			Constant
hi def link nsisReserveFileKwd		Constant
hi def link nsisRMDirKwd		Constant
hi def link nsisDeleteRegKeyKwd		Constant
hi def link nsisWriteRegMultiStrKwd	Constant
hi def link nsisSetRegViewKwd		Constant
hi def link nsisCopyFilesKwd		Constant
hi def link nsisCreateShortcutKwd	Constant
hi def link nsisGetFullPathNameKwd	Constant
hi def link nsisFileAttrib		Constant
hi def link nsisMessageBox		Constant
hi def link nsisFileWriteUTF16LEKwd	Constant
hi def link nsisSetShellVarContextKwd	Constant
hi def link nsisSendMessageKwd		Constant
hi def link nsisSetBrandingImageKwd	Constant
hi def link nsisSetDetailsViewKwd	Constant
hi def link nsisSetDetailsPrintKwd	Constant
hi def link nsisSetCtlColorsKwd		Constant
hi def link nsisSetSilentKwd		Constant
hi def link nsisRegistry		Identifier
hi def link nsisNumber			Number
hi def link nsisError			Error
hi def link nsisUserVar			Identifier
hi def link nsisSysVar			Identifier
hi def link nsisAttribute		Type
hi def link nsisCompiler		Type
hi def link nsisVersionInfo		Type
hi def link nsisTodo			Todo
hi def link nsisCallback		Identifier
" preprocessor commands
hi def link nsisPreprocSubst		PreProc
hi def link nsisPreprocLangStr		PreProc
hi def link nsisPreprocEnvVar		PreProc
hi def link nsisDefine			Define
hi def link nsisMacro			Macro
hi def link nsisPreCondit		PreCondit
hi def link nsisInclude			Include
hi def link nsisSystem			PreProc
hi def link nsisLineContinuation	Special
hi def link nsisIncludeKwd		Constant
hi def link nsisAddplugindirKwd		Constant
hi def link nsisAppendfileKwd		Constant
hi def link nsisDelfileKwd		Constant
hi def link nsisPragmaKwd		Constant
hi def link nsisVerboseKwd		Constant
hi def link nsisDefineKwd		Constant
hi def link nsisIfKwd			Constant
hi def link nsisSearchparseKwd		Constant
hi def link nsisSearchreplaceKwd	Constant


let b:current_syntax = "nsis"

let &cpo = s:cpo_save
unlet s:cpo_save
