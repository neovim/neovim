" Vim syntax file
"
" Language:	AutoIt v3 (http://www.autoitscript.com/autoit3/)
" Maintainer:	Jared Breland <jbreland@legroom.net>
" Authored By:	Riccardo Casini <ric@libero.it>
" Script URL:	http://www.vim.org/scripts/script.php?script_id=1239
" ChangeLog:	Please visit the script URL for detailed change information
" 		Included change from #970.

" Quit when a syntax file was already loaded.
if exists("b:current_syntax")
  finish
endif
let s:keepcpo= &cpo
set cpo&vim

let b:current_syntax = "autoit"

" AutoIt is not case dependent
syn case ignore

" Definitions for AutoIt reserved keywords
syn keyword autoitKeyword Default False True
syn keyword autoitKeyword Const Dim Global Local ReDim
syn keyword autoitKeyword If Else ElseIf Then EndIf
syn keyword autoitKeyword Select Switch Case EndSelect EndSwitch
syn keyword autoitKeyword Enum For In To Step Next
syn keyword autoitKeyword With While EndWith Wend Do Until
syn keyword autoitKeyword ContinueCase ContinueLoop ExitLoop Exit

" inside script inclusion and global options
syn match autoitIncluded display contained "<[^>]*>"
syn match autoitInclude	display "^\s*#\s*include\>\s*["<]"
	\ contains=autoitIncluded,autoitString
syn match autoitInclude "^\s*#include-once\>"
syn match autoitInclude "^\s*#NoTrayIcon\>"
syn match autoitInclude "^\s*#RequireAdmin\>"

" user-defined functions
syn keyword autoitKeyword Func ByRef EndFunc Return OnAutoItStart OnAutoItExit

" built-in functions
" environment management
syn keyword autoitFunction ClipGet ClipPut EnvGet EnvSet EnvUpdate MemGetStats
" file, directory, and disk management
syn keyword autoitFunction ConsoleRead ConsoleWrite ConsoleWriteError
syn keyword autoitFunction DirCopy DirCreate DirGetSize DirMove DirRemove
syn keyword autoitFunction DriveGetDrive DriveGetFileSystem DriveGetLabel
	\ DriveGetSerial DriveGetType DriveMapAdd DriveMapDel DriveMapGet
	\ DriveSetLabel DriveSpaceFree DriveSpaceTotal DriveStatus
syn keyword autoitFunction FileChangeDir FileClose FileCopy FileCreateNTFSLink
	\ FileCreateShortcut FileDelete FileExists FileFindFirstFile
	\ FileFindNextFile FileGetAttrib FileGetLongName FileGetShortcut
	\ FileGetShortName FileGetSize FileGetTime FileGetVersion FileInstall
	\ FileMove FileOpen FileOpenDialog FileRead FileReadLine FileRecycle
	\ FileRecycleEmpty FileSaveDialog FileSelectFolder FileSetAttrib
	\ FileSetTime FileWrite FileWriteLine
syn keyword autoitFunction IniDelete IniRead IniReadSection IniReadSectionNames
	\ IniRenameSection IniWrite IniWriteSection
syn keyword autoitFunction StderrRead StdinWrite StdoutRead
" graphic and sound
syn keyword autoitFunction Beep PixelChecksum PixelGetColor PixelSearch
	\ SoundPlay SoundSetWaveVolume
" gui reference
syn keyword autoitFunction GUICreate GUIDelete GUICtrlGetHandle GUICtrlGetState
	\ GUICtrlRead GUICtrlRecvMsg GUICtrlSendMsg GUICtrlSendToDummy
	\ GUIGetCursorInfo GUIGetMsg GUIRegisterMsg GUIStartGroup GUISwitch
syn keyword autoitFunction GUICtrlCreateAvi GUICtrlCreateButton
	\ GUICtrlCreateCheckbox GUICtrlCreateCombo GUICtrlCreateContextMenu
	\ GUICtrlCreateDate GUICtrlCreateDummy GUICtrlCreateEdit
	\ GUICtrlCreateGraphic GUICtrlCreateGroup GUICtrlCreateIcon
	\ GUICtrlCreateInput GUICtrlCreateLabel GUICtrlCreateList
	\ GUICtrlCreateListView GUICtrlCreateListViewItem GUICtrlCreateMenu
	\ GUICtrlCreateMenuItem GUICtrlCreateMonthCal GUICtrlCreateObj
	\ GUICtrlCreatePic GUICtrlCreateProgress GUICtrlCreateRadio
	\ GUICtrlCreateSlider GUICtrlCreateTab GUICtrlCreateTabItem
	\ GUICtrlCreateTreeView GUICtrlCreateTreeViewItem
	\ GUICtrlCreateUpDown GUICtrlDelete
syn keyword autoitFunction GUICtrlRegisterListViewSort GUICtrlSetBkColor
	\ GUICtrlSetColor GUICtrlSetCursor GUICtrlSetData GUICtrlSetFont
	\ GUICtrlSetGraphic GUICtrlSetImage GUICtrlSetLimit GUICtrlSetOnEvent
	\ GUICtrlSetPos GUICtrlSetResizing GUICtrlSetState GUICtrlSetStyle
	\ GUICtrlSetTip
syn keyword autoitFunction GUISetBkColor GUISetCoord GUISetCursor GUISetFont
	\ GUISetHelp GUISetIcon GUISetOnEvent GUISetState
" keyboard control
syn keyword autoitFunction HotKeySet Send
" math
syn keyword autoitFunction Abs ACos ASin ATan BitAND BitNOT BitOR BitRotate
	\ BitShift BitXOR Cos Ceiling Exp Floor Log Mod Random Round Sin Sqrt
	\ SRandom Tan
" message boxes and dialogs
syn keyword autoitFunction InputBox MsgBox ProgressOff ProgressOn ProgressSet
	\ SplashImageOn SplashOff SplashTextOn ToolTip
" miscellaneous
syn keyword autoitFunction AdlibDisable AdlibEnable AutoItSetOption
	\ AutoItWinGetTitle AutoItWinSetTitle BlockInput Break Call CDTray
	\ Execute Opt SetError SetExtended
" mouse control
syn keyword autoitFunction MouseClick MouseClickDrag MouseDown MouseGetCursor
	\ MouseGetPos MouseMove MouseUp MouseWheel
" network
syn keyword autoitFunction FtpSetProxy HttpSetProxy InetGet InetGetSize Ping
	\ TCPAccept TCPCloseSocket TCPConnect TCPListen TCPNameToIp TCPRecv
	\ TCPSend TCPShutDown TCPStartup UDPBind UDPCloseSocket UDPOpen UDPRecv
	\ UDPSend UDPShutdown UDPStartup
" obj/com reference
syn keyword autoitFunction ObjCreate ObjEvent ObjGet ObjName
" process management
syn keyword autoitFunction DllCall DllClose DllOpen DllStructCreate
	\ DllStructGetData DllStructGetPtr DllStructGetSize DllStructSetData
	\ ProcessClose ProcessExists ProcessSetPriority ProcessList ProcessWait
	\ ProcessWaitClose Run RunAsSet RunWait ShellExecute ShellExecuteWait
	\ Shutdown
	" removed from 3.2.0 docs - PluginClose PluginOpen
" registry management
syn keyword autoitFunction RegDelete RegEnumKey RegEnumVal RegRead RegWrite
" string management
syn keyword autoitFunction StringAddCR StringFormat StringInStr StringIsAlNum
	\ StringIsAlpha StringIsASCII StringIsDigit StringIsFloat StringIsInt
	\ StringIsLower StringIsSpace StringIsUpper StringIsXDigit StringLeft
	\ StringLen StringLower StringMid StringRegExp StringRegExpReplace
	\ StringReplace StringRight StringSplit StringStripCR StringStripWS
	\ StringTrimLeft StringTrimRight StringUpper
" timer and delay
syn keyword autoitFunction Sleep TimerInit TimerDiff
" tray
syn keyword autoitFunction TrayCreateItem TrayCreateMenu TrayItemDelete
	\ TrayItemGetHandle TrayItemGetState TrayItemGetText TrayItemSetOnEvent
	\ TrayItemSetState TrayItemSetText TrayGetMsg TraySetClick TraySetIcon
	\ TraySetOnEvent TraySetPauseIcon TraySetState TraySetToolTip TrayTip
" variables and conversions
syn keyword autoitFunction Asc Assign Binary Chr Dec Eval Hex HWnd Int IsAdmin
	\ IsArray IsBinaryString IsBool IsDeclared IsDllStruct IsFloat IsHWnd
	\ IsInt IsKeyword IsNumber IsObj IsString Number String UBound
" window management
syn keyword autoitFunction WinActivate WinActive WinClose WinExists WinFlash
	\ WinGetCaretPos WinGetClassList WinGetClientSize WinGetHandle WinGetPos
	\ WinGetProcess WinGetState WinGetText WinGetTitle WinKill WinList
	\ WinMenuSelectItem WinMinimizeAll WinMinimizeAllUndo WinMove
	\ WinSetOnTop WinSetState WinSetTitle WinSetTrans WinWait WinWaitActive
	\ WinWaitClose WinWaitNotActive
syn keyword autoitFunction ControlClick ControlCommand ControlDisable
	\ ControlEnable ControlFocus ControlGetFocus ControlGetHandle
	\ ControlGetPos ControlGetText ControlHide ControlListView ControlMove
	\ ControlSend ControlSetText ControlShow StatusBarGetText

" user defined functions
" array
syn keyword autoitFunction _ArrayAdd _ArrayBinarySearch _ArrayCreate
	\ _ArrayDelete _ArrayDisplay _ArrayInsert _ArrayMax _ArrayMaxIndex
	\ _ArrayMin _ArrayMinIndex _ArrayPop _ArrayPush _ArrayReverse
	\ _ArraySearch _ArraySort _ArraySwap _ArrayToClip _ArrayToString
	\ _ArrayTrim
" color
syn keyword autoitFunction _ColorgetBlue _ColorGetGreen _ColorGetRed
" date
syn keyword autoitFunction _DateAdd _DateDayOfWeek _DateDaysInMonth _DateDiff
	\ _DateIsLeapYear _DateIsValid _DateTimeFormat _DateTimeSplit
	\ _DateToDayOfWeek _ToDayOfWeekISO _DateToDayValue _DayValueToDate _Now
	\ _NowCalc _NowCalcDate _NowDate _NowTime _SetDate _SetTime _TicksToTime
	\ _TimeToTicks _WeekNumberISO
" file
syn keyword autoitFunction _FileCountLines _FileCreate _FileListToArray
	\ _FilePrint _FileReadToArray _FileWriteFromArray _FileWriteLog
	\ _FileWriteToLine _PathFull _PathMake _PathSplit _ReplaceStringInFile
	\ _TempFile
" guicombo
syn keyword autoitFunction _GUICtrlComboAddDir _GUICtrlComboAddString
	\ _GUICtrlComboAutoComplete _GUICtrlComboDeleteString
	\ _GUICtrlComboFindString _GUICtrlComboGetCount _GUICtrlComboGetCurSel
	\ _GUICtrlComboGetDroppedControlRect _GUICtrlComboGetDroppedState
	\ _GUICtrlComboGetDroppedWidth _GUICtrlComboGetEditSel
	\ _GUICtrlComboGetExtendedUI _GUICtrlComboGetHorizontalExtent
	\ _GUICtrlComboGetItemHeight _GUICtrlComboGetLBText
	\ _GUICtrlComboGetLBTextLen _GUICtrlComboGetList _GUICtrlComboGetLocale
	\ _GUICtrlComboGetMinVisible _GUICtrlComboGetTopIndex
	\ _GUICtrlComboInitStorage _GUICtrlComboInsertString
	\ _GUICtrlComboLimitText _GUICtrlComboResetContent
	\ _GUICtrlComboSelectString _GUICtrlComboSetCurSel
	\ _GUICtrlComboSetDroppedWidth _GUICtrlComboSetEditSel
	\ _GUICtrlComboSetExtendedUI _GUICtrlComboSetHorizontalExtent
	\ _GUICtrlComboSetItemHeight _GUICtrlComboSetMinVisible
	\ _GUICtrlComboSetTopIndex _GUICtrlComboShowDropDown
" guiedit
syn keyword autoitFunction _GUICtrlEditCanUndo _GUICtrlEditEmptyUndoBuffer
	\ _GuiCtrlEditFind _GUICtrlEditGetFirstVisibleLine _GUICtrlEditGetLine
	\ _GUICtrlEditGetLineCount _GUICtrlEditGetModify _GUICtrlEditGetRect
	\ _GUICtrlEditGetSel _GUICtrlEditLineFromChar _GUICtrlEditLineIndex
	\ _GUICtrlEditLineLength _GUICtrlEditLineScroll _GUICtrlEditReplaceSel
	\ _GUICtrlEditScroll _GUICtrlEditSetModify _GUICtrlEditSetRect
	\ _GUICtrlEditSetSel _GUICtrlEditUndo
" guiipaddress
syn keyword autoitFunction _GUICtrlIpAddressClear _GUICtrlIpAddressCreate
	\ _GUICtrlIpAddressDelete _GUICtrlIpAddressGet _GUICtrlIpAddressIsBlank
	\ _GUICtrlIpAddressSet _GUICtrlIpAddressSetFocus
	\ _GUICtrlIpAddressSetFont
	\ _GUICtrlIpAddressSetRange _GUICtrlIpAddressShowHide
" guilist
syn keyword autoitFunction _GUICtrlListAddDir _GUICtrlListAddItem
	\ _GUICtrlListClear
	\ _GUICtrlListCount _GUICtrlListDeleteItem _GUICtrlListFindString
	\ _GUICtrlListGetAnchorIndex _GUICtrlListGetCaretIndex
	\ _GUICtrlListGetHorizontalExtent _GUICtrlListGetInfo
	\ _GUICtrlListGetItemRect _GUICtrlListGetLocale _GUICtrlListGetSelCount
	\ _GUICtrlListGetSelItems _GUICtrlListGetSelItemsText
	\ _GUICtrlListGetSelState _GUICtrlListGetText _GUICtrlListGetTextLen
	\ _GUICtrlListGetTopIndex _GUICtrlListInsertItem
	\ _GUICtrlListReplaceString _GUICtrlListSelectedIndex
	\ _GUICtrlListSelectIndex _GUICtrlListSelectString
	\ _GUICtrlListSelItemRange _GUICtrlListSelItemRangeEx
	\ _GUICtrlListSetAnchorIndex _GUICtrlListSetCaretIndex
	\ _GUICtrlListSetHorizontalExtent _GUICtrlListSetLocale
	\ _GUICtrlListSetSel _GUICtrlListSetTopIndex _GUICtrlListSort
	\ _GUICtrlListSwapString
" guilistview
syn keyword autoitFunction _GUICtrlListViewCopyItems
	\ _GUICtrlListViewDeleteAllItems _GUICtrlListViewDeleteColumn
	\ _GUICtrlListViewDeleteItem _GUICtrlListViewDeleteItemsSelected
	\ _GUICtrlListViewEnsureVisible _GUICtrlListViewFindItem
	\ _GUICtrlListViewGetBackColor _GUICtrlListViewGetCallBackMask
	\ _GUICtrlListViewGetCheckedState _GUICtrlListViewGetColumnOrder
	\ _GUICtrlListViewGetColumnWidth _GUICtrlListViewGetCounterPage
	\ _GUICtrlListViewGetCurSel _GUICtrlListViewGetExtendedListViewStyle
	\ _GUICtrlListViewGetHeader _GUICtrlListViewGetHotCursor
	\ _GUICtrlListViewGetHotItem _GUICtrlListViewGetHoverTime
	\ _GUICtrlListViewGetItemCount _GUICtrlListViewGetItemText
	\ _GUICtrlListViewGetItemTextArray _GUICtrlListViewGetNextItem
	\ _GUICtrlListViewGetSelectedCount _GUICtrlListViewGetSelectedIndices
	\ _GUICtrlListViewGetSubItemsCount _GUICtrlListViewGetTopIndex
	\ _GUICtrlListViewGetUnicodeFormat _GUICtrlListViewHideColumn
	\ _GUICtrlListViewInsertColumn _GUICtrlListViewInsertItem
	\ _GUICtrlListViewJustifyColumn _GUICtrlListViewScroll
	\ _GUICtrlListViewSetCheckState _GUICtrlListViewSetColumnHeaderText
	\ _GUICtrlListViewSetColumnOrder _GUICtrlListViewSetColumnWidth
	\ _GUICtrlListViewSetHotItem _GUICtrlListViewSetHoverTime
	\ _GUICtrlListViewSetItemCount _GUICtrlListViewSetItemSelState
	\ _GUICtrlListViewSetItemText _GUICtrlListViewSort
" guimonthcal
syn keyword autoitFunction _GUICtrlMonthCalGet1stDOW _GUICtrlMonthCalGetColor
	\ _GUICtrlMonthCalGetDelta _GUICtrlMonthCalGetMaxSelCount
	\ _GUICtrlMonthCalGetMaxTodayWidth _GUICtrlMonthCalGetMinReqRect
	\ _GUICtrlMonthCalSet1stDOW _GUICtrlMonthCalSetColor
	\ _GUICtrlMonthCalSetDelta _GUICtrlMonthCalSetMaxSelCount
" guislider
syn keyword autoitFunction _GUICtrlSliderClearTics _GUICtrlSliderGetLineSize
	\ _GUICtrlSliderGetNumTics _GUICtrlSliderGetPageSize
	\ _GUICtrlSliderGetPos _GUICtrlSliderGetRangeMax
	\ _GUICtrlSliderGetRangeMin _GUICtrlSliderSetLineSize
	\ _GUICtrlSliderSetPageSize _GUICtrlSliderSetPos
	\ _GUICtrlSliderSetTicFreq
" guistatusbar
syn keyword autoitFunction _GuiCtrlStatusBarCreate
	\ _GUICtrlStatusBarCreateProgress _GUICtrlStatusBarDelete
	\ _GuiCtrlStatusBarGetBorders _GuiCtrlStatusBarGetIcon
	\ _GuiCtrlStatusBarGetParts _GuiCtrlStatusBarGetRect
	\ _GuiCtrlStatusBarGetText _GuiCtrlStatusBarGetTextLength
	\ _GuiCtrlStatusBarGetTip _GuiCtrlStatusBarGetUnicode
	\ _GUICtrlStatusBarIsSimple _GuiCtrlStatusBarResize
	\ _GuiCtrlStatusBarSetBKColor _GuiCtrlStatusBarSetIcon
	\ _GuiCtrlStatusBarSetMinHeight _GUICtrlStatusBarSetParts
	\ _GuiCtrlStatusBarSetSimple _GuiCtrlStatusBarSetText
	\ _GuiCtrlStatusBarSetTip _GuiCtrlStatusBarSetUnicode
	\ _GUICtrlStatusBarShowHide 
" guitab
syn keyword autoitFunction _GUICtrlTabDeleteAllItems _GUICtrlTabDeleteItem
	\ _GUICtrlTabDeselectAll _GUICtrlTabGetCurFocus _GUICtrlTabGetCurSel
	\ _GUICtrlTabGetExtendedStyle _GUICtrlTabGetItemCount
	\ _GUICtrlTabGetItemRect _GUICtrlTabGetRowCount
	\ _GUICtrlTabGetUnicodeFormat _GUICtrlTabHighlightItem
	\ _GUICtrlTabSetCurFocus _GUICtrlTabSetCurSel
	\ _GUICtrlTabSetMinTabWidth _GUICtrlTabSetUnicodeFormat
" guitreeview
syn keyword autoitFunction _GUICtrlTreeViewDeleteAllItems
	\ _GUICtrlTreeViewDeleteItem _GUICtrlTreeViewExpand
	\ _GUICtrlTreeViewGetBkColor _GUICtrlTreeViewGetCount
	\ _GUICtrlTreeViewGetIndent _GUICtrlTreeViewGetLineColor
	\ _GUICtrlTreeViewGetParentHandle _GUICtrlTreeViewGetParentID
	\ _GUICtrlTreeViewGetState _GUICtrlTreeViewGetText
	\ _GUICtrlTreeViewGetTextColor _GUICtrlTreeViewItemGetTree
	\ _GUICtrlTreeViewInsertItem _GUICtrlTreeViewSetBkColor
	\ _GUICtrlTreeViewSetIcon _GUICtrlTreeViewSetIndent
	\ _GUICtrlTreeViewSetLineColor GUICtrlTreeViewSetState
	\ _GUICtrlTreeViewSetText _GUICtrlTreeViewSetTextColor
	\ _GUICtrlTreeViewSort
" ie
syn keyword autoitFunction _IE_Example _IE_Introduction _IE_VersionInfo
	\ _IEAction _IEAttach _IEBodyReadHTML _IEBodyReadText _IEBodyWriteHTML
	\ _IECreate _IECreateEmbedded _IEDocGetObj _IEDocInsertHTML
	\ _IEDocInsertText _IEDocReadHTML _IEDocWriteHTML
	\ _IEErrorHandlerDeRegister _IEErrorHandlerRegister _IEErrorNotify
	\ _IEFormElementCheckboxSelect _IEFormElementGetCollection
	\ _IEFormElementGetObjByName _IEFormElementGetValue
	\ _IEFormElementOptionSelect _IEFormElementRadioSelect
	\ _IEFormElementSetValue _IEFormGetCollection _IEFormGetObjByName
	\ _IEFormImageClick _IEFormReset _IEFormSubmit _IEFrameGetCollection
	\ _IEFrameGetObjByName _IEGetObjByName _IEHeadInsertEventScript
	\ _IEImgClick _IEImgGetCollection _IEIsFrameSet _IELinkClickByIndex
	\ _IELinkClickByText _IELinkGetCollection _IELoadWait _IELoadWaitTimeout
	\ _IENavigate _IEPropertyGet _IEPropertySet _IEQuit
	\ _IETableGetCollection _IETableWriteToArray _IETagNameAllGetCollection
	\  _IETagNameGetCollection
" inet
syn keyword autoitFunction _GetIP _INetExplorerCapable _INetGetSource _INetMail
	\ _INetSmtpMail _TCPIpToName
" math
syn keyword autoitFunction _Degree _MathCheckDiv _Max _Min _Radian
" miscellaneous
syn keyword autoitFunction _ChooseColor _ChooseFont _ClipPutFile _Iif
	\ _IsPressed _MouseTrap _SendMessage _Singleton
" process
syn keyword autoitFunction _ProcessGetName _ProcessGetPriority _RunDOS
" sound
syn keyword autoitFunction _SoundClose _SoundLength _SoundOpen _SoundPause
	\ _SoundPlay _SoundPos _SoundResume _SoundSeek _SoundStatus _SoundStop
" sqlite
syn keyword autoitFunction _SQLite_Changes _SQLite_Close
	\ _SQLite_Display2DResult _SQLite_Encode _SQLite_ErrCode _SQLite_ErrMsg
	\ _SQLite_Escape _SQLite_Exec _SQLite_FetchData _SQLite_FetchNames
	\ _SQLite_GetTable _SQLite_GetTable2D _SQLite_LastInsertRowID
	\ _SQLite_LibVersion _SQLite_Open _SQLite_Query _SQLite_QueryFinalize
	\ _SQLite_QueryReset _SQLite_QuerySingleRow _SQLite_SaveMode
	\ _SQLite_SetTimeout _SQLite_Shutdown _SQLite_SQLiteExe _SQLite_Startup
	\ _SQLite_TotalChanges
" string
syn keyword autoitFunction _HexToString _StringAddComma _StringBetween
	\ _StringEncrypt _StringInsert _StringProper _StringRepeat
	\ _StringReverse _StringToHex
" visa
syn keyword autoitFunction _viClose _viExecCommand _viFindGpib _viGpibBusReset
	\ _viGTL _viOpen _viSetAttribute _viSetTimeout

" read-only macros
syn match autoitBuiltin "@AppData\(Common\)\=Dir"
syn match autoitBuiltin "@AutoItExe"
syn match autoitBuiltin "@AutoItPID"
syn match autoitBuiltin "@AutoItVersion"
syn match autoitBuiltin "@COM_EventObj"
syn match autoitBuiltin "@CommonFilesDir"
syn match autoitBuiltin "@Compiled"
syn match autoitBuiltin "@ComputerName"
syn match autoitBuiltin "@ComSpec"
syn match autoitBuiltin "@CR\(LF\)\="
syn match autoitBuiltin "@Desktop\(Common\)\=Dir"
syn match autoitBuiltin "@DesktopDepth"
syn match autoitBuiltin "@DesktopHeight"
syn match autoitBuiltin "@DesktopRefresh"
syn match autoitBuiltin "@DesktopWidth"
syn match autoitBuiltin "@DocumentsCommonDir"
syn match autoitBuiltin "@Error"
syn match autoitBuiltin "@ExitCode"
syn match autoitBuiltin "@ExitMethod"
syn match autoitBuiltin "@Extended"
syn match autoitBuiltin "@Favorites\(Common\)\=Dir"
syn match autoitBuiltin "@GUI_CtrlId"
syn match autoitBuiltin "@GUI_CtrlHandle"
syn match autoitBuiltin "@GUI_DragId"
syn match autoitBuiltin "@GUI_DragFile"
syn match autoitBuiltin "@GUI_DropId"
syn match autoitBuiltin "@GUI_WinHandle"
syn match autoitBuiltin "@HomeDrive"
syn match autoitBuiltin "@HomePath"
syn match autoitBuiltin "@HomeShare"
syn match autoitBuiltin "@HOUR"
syn match autoitBuiltin "@HotKeyPressed"
syn match autoitBuiltin "@InetGetActive"
syn match autoitBuiltin "@InetGetBytesRead"
syn match autoitBuiltin "@IPAddress[1234]"
syn match autoitBuiltin "@KBLayout"
syn match autoitBuiltin "@LF"
syn match autoitBuiltin "@Logon\(DNS\)\=Domain"
syn match autoitBuiltin "@LogonServer"
syn match autoitBuiltin "@MDAY"
syn match autoitBuiltin "@MIN"
syn match autoitBuiltin "@MON"
syn match autoitBuiltin "@MyDocumentsDir"
syn match autoitBuiltin "@NumParams"
syn match autoitBuiltin "@OSBuild"
syn match autoitBuiltin "@OSLang"
syn match autoitBuiltin "@OSServicePack"
syn match autoitBuiltin "@OSTYPE"
syn match autoitBuiltin "@OSVersion"
syn match autoitBuiltin "@ProcessorArch"
syn match autoitBuiltin "@ProgramFilesDir"
syn match autoitBuiltin "@Programs\(Common\)\=Dir"
syn match autoitBuiltin "@ScriptDir"
syn match autoitBuiltin "@ScriptFullPath"
syn match autoitBuiltin "@ScriptLineNumber"
syn match autoitBuiltin "@ScriptName"
syn match autoitBuiltin "@SEC"
syn match autoitBuiltin "@StartMenu\(Common\)\=Dir"
syn match autoitBuiltin "@Startup\(Common\)\=Dir"
syn match autoitBuiltin "@SW_DISABLE"
syn match autoitBuiltin "@SW_ENABLE"
syn match autoitBuiltin "@SW_HIDE"
syn match autoitBuiltin "@SW_LOCK"
syn match autoitBuiltin "@SW_MAXIMIZE"
syn match autoitBuiltin "@SW_MINIMIZE"
syn match autoitBuiltin "@SW_RESTORE"
syn match autoitBuiltin "@SW_SHOW"
syn match autoitBuiltin "@SW_SHOWDEFAULT"
syn match autoitBuiltin "@SW_SHOWMAXIMIZED"
syn match autoitBuiltin "@SW_SHOWMINIMIZED"
syn match autoitBuiltin "@SW_SHOWMINNOACTIVE"
syn match autoitBuiltin "@SW_SHOWNA"
syn match autoitBuiltin "@SW_SHOWNOACTIVATE"
syn match autoitBuiltin "@SW_SHOWNORMAL"
syn match autoitBuiltin "@SW_UNLOCK"
syn match autoitBuiltin "@SystemDir"
syn match autoitBuiltin "@TAB"
syn match autoitBuiltin "@TempDir"
syn match autoitBuiltin "@TRAY_ID"
syn match autoitBuiltin "@TrayIconFlashing"
syn match autoitBuiltin "@TrayIconVisible"
syn match autoitBuiltin "@UserProfileDir"
syn match autoitBuiltin "@UserName"
syn match autoitBuiltin "@WDAY"
syn match autoitBuiltin "@WindowsDir"
syn match autoitBuiltin "@WorkingDir"
syn match autoitBuiltin "@YDAY"
syn match autoitBuiltin "@YEAR"

"comments and commenting-out
syn match autoitComment ";.*"
"in this way also #ce alone will be highlighted
syn match autoitCommDelimiter "^\s*#comments-start\>"
syn match autoitCommDelimiter "^\s*#cs\>"
syn match autoitCommDelimiter "^\s*#comments-end\>"
syn match autoitCommDelimiter "^\s*#ce\>"
syn region autoitComment
	\ matchgroup=autoitCommDelimiter
	\ start="^\s*#comments-start\>" start="^\s*#cs\>"
	\ end="^\s*#comments-end\>" end="^\s*#ce\>"

"one character operators
syn match autoitOperator "[-+*/&^=<>][^-+*/&^=<>]"me=e-1
"two characters operators
syn match autoitOperator "==[^=]"me=e-1
syn match autoitOperator "<>"
syn match autoitOperator "<="
syn match autoitOperator ">="
syn match autoitOperator "+="
syn match autoitOperator "-="
syn match autoitOperator "*="
syn match autoitOperator "/="
syn match autoitOperator "&="
syn keyword autoitOperator NOT AND OR

syn match autoitParen "(\|)"
syn match autoitBracket "\[\|\]"
syn match autoitComma ","

"numbers must come after operator '-'
"decimal numbers without a dot
syn match autoitNumber "-\=\<\d\+\>"
"hexadecimal numbers without a dot
syn match autoitNumber "-\=\<0x\x\+\>"
"floating point number with dot (inside or at end)

syn match autoitNumber "-\=\<\d\+\.\d*\>"
"floating point number, starting with a dot
syn match autoitNumber "-\=\<\.\d\+\>"
"scientific notation numbers without dots
syn match autoitNumber "-\=\<\d\+e[-+]\=\d\+\>"
"scientific notation numbers with dots
syn match autoitNumber "-\=\<\(\(\d\+\.\d*\)\|\(\.\d\+\)\)\(e[-+]\=\d\+\)\=\>"

"string constants
"we want the escaped quotes marked in red
syn match autoitDoubledSingles +''+ contained
syn match autoitDoubledDoubles +""+ contained
"we want the continuation character marked in red
"(also at the top level, not just contained)
syn match autoitCont "_$"

" send key list - must be defined before autoitStrings
syn match autoitSend "{!}" contained
syn match autoitSend "{#}" contained
syn match autoitSend "{+}" contained
syn match autoitSend "{^}" contained
syn match autoitSend "{{}" contained
syn match autoitSend "{}}" contained
syn match autoitSend "{SPACE}" contained
syn match autoitSend "{ENTER}" contained
syn match autoitSend "{ALT}" contained
syn match autoitSend "{BACKSPACE}" contained
syn match autoitSend "{BS}" contained
syn match autoitSend "{DELETE}" contained
syn match autoitSend "{DEL}" contained
syn match autoitSend "{UP}" contained
syn match autoitSend "{DOWN}" contained
syn match autoitSend "{LEFT}" contained
syn match autoitSend "{RIGHT}" contained
syn match autoitSend "{HOME}" contained
syn match autoitSend "{END}" contained
syn match autoitSend "{ESCAPE}" contained
syn match autoitSend "{ESC}" contained
syn match autoitSend "{INSERT}" contained
syn match autoitSend "{INS}" contained
syn match autoitSend "{PGUP}" contained
syn match autoitSend "{PGDN}" contained
syn match autoitSend "{F1}" contained
syn match autoitSend "{F2}" contained
syn match autoitSend "{F3}" contained
syn match autoitSend "{F4}" contained
syn match autoitSend "{F5}" contained
syn match autoitSend "{F6}" contained
syn match autoitSend "{F7}" contained
syn match autoitSend "{F8}" contained
syn match autoitSend "{F9}" contained
syn match autoitSend "{F10}" contained
syn match autoitSend "{F11}" contained
syn match autoitSend "{F12}" contained
syn match autoitSend "{TAB}" contained
syn match autoitSend "{PRINTSCREEN}" contained
syn match autoitSend "{LWIN}" contained
syn match autoitSend "{RWIN}" contained
syn match autoitSend "{NUMLOCK}" contained
syn match autoitSend "{CTRLBREAK}" contained
syn match autoitSend "{PAUSE}" contained
syn match autoitSend "{CAPSLOCK}" contained
syn match autoitSend "{NUMPAD0}" contained
syn match autoitSend "{NUMPAD1}" contained
syn match autoitSend "{NUMPAD2}" contained
syn match autoitSend "{NUMPAD3}" contained
syn match autoitSend "{NUMPAD4}" contained
syn match autoitSend "{NUMPAD5}" contained
syn match autoitSend "{NUMPAD6}" contained
syn match autoitSend "{NUMPAD7}" contained
syn match autoitSend "{NUMPAD8}" contained
syn match autoitSend "{NUMPAD9}" contained
syn match autoitSend "{NUMPADMULT}" contained
syn match autoitSend "{NUMPADADD}" contained
syn match autoitSend "{NUMPADSUB}" contained
syn match autoitSend "{NUMPADDIV}" contained
syn match autoitSend "{NUMPADDOT}" contained
syn match autoitSend "{NUMPADENTER}" contained
syn match autoitSend "{APPSKEY}" contained
syn match autoitSend "{LALT}" contained
syn match autoitSend "{RALT}" contained
syn match autoitSend "{LCTRL}" contained
syn match autoitSend "{RCTRL}" contained
syn match autoitSend "{LSHIFT}" contained
syn match autoitSend "{RSHIFT}" contained
syn match autoitSend "{SLEEP}" contained
syn match autoitSend "{ALTDOWN}" contained
syn match autoitSend "{SHIFTDOWN}" contained
syn match autoitSend "{CTRLDOWN}" contained
syn match autoitSend "{LWINDOWN}" contained
syn match autoitSend "{RWINDOWN}" contained
syn match autoitSend "{ASC \d\d\d\d}" contained
syn match autoitSend "{BROWSER_BACK}" contained
syn match autoitSend "{BROWSER_FORWARD}" contained
syn match autoitSend "{BROWSER_REFRESH}" contained
syn match autoitSend "{BROWSER_STOP}" contained
syn match autoitSend "{BROWSER_SEARCH}" contained
syn match autoitSend "{BROWSER_FAVORITES}" contained
syn match autoitSend "{BROWSER_HOME}" contained
syn match autoitSend "{VOLUME_MUTE}" contained
syn match autoitSend "{VOLUME_DOWN}" contained
syn match autoitSend "{VOLUME_UP}" contained
syn match autoitSend "{MEDIA_NEXT}" contained
syn match autoitSend "{MEDIA_PREV}" contained
syn match autoitSend "{MEDIA_STOP}" contained
syn match autoitSend "{MEDIA_PLAY_PAUSE}" contained
syn match autoitSend "{LAUNCH_MAIL}" contained
syn match autoitSend "{LAUNCH_MEDIA}" contained
syn match autoitSend "{LAUNCH_APP1}" contained
syn match autoitSend "{LAUNCH_APP2}" contained

"this was tricky!
"we use an oneline region, instead of a match, in order to use skip=
"matchgroup= so start and end quotes are not considered as au3Doubled
"contained
syn region autoitString oneline contains=autoitSend matchgroup=autoitQuote start=+"+
	\ end=+"+ end=+_\n\{1}.*"+
	\ contains=autoitCont,autoitDoubledDoubles skip=+""+
syn region autoitString oneline matchgroup=autoitQuote start=+'+
	\ end=+'+ end=+_\n\{1}.*'+
	\ contains=autoitCont,autoitDoubledSingles skip=+''+

syn match autoitVarSelector "\$"	contained display
syn match autoitVariable "$\w\+" contains=autoitVarSelector

" options - must be defined after autoitStrings
syn match autoitOption "\([\"\']\)CaretCoordMode\1"
syn match autoitOption "\([\"\']\)ColorMode\1"
syn match autoitOption "\([\"\']\)ExpandEnvStrings\1"
syn match autoitOption "\([\"\']\)ExpandVarStrings\1"
syn match autoitOption "\([\"\']\)FtpBinaryMode\1"
syn match autoitOption "\([\"\']\)GUICloseOnEsc\1"
syn match autoitOption "\([\"\']\)GUICoordMode\1"
syn match autoitOption "\([\"\']\)GUIDataSeparatorChar\1"
syn match autoitOption "\([\"\']\)GUIOnEventMode\1"
syn match autoitOption "\([\"\']\)GUIResizeMode\1"
syn match autoitOption "\([\"\']\)GUIEventCompatibilityMode\1"
syn match autoitOption "\([\"\']\)MouseClickDelay\1"
syn match autoitOption "\([\"\']\)MouseClickDownDelay\1"
syn match autoitOption "\([\"\']\)MouseClickDragDelay\1"
syn match autoitOption "\([\"\']\)MouseCoordMode\1"
syn match autoitOption "\([\"\']\)MustDeclareVars\1"
syn match autoitOption "\([\"\']\)OnExitFunc\1"
syn match autoitOption "\([\"\']\)PixelCoordMode\1"
syn match autoitOption "\([\"\']\)RunErrorsFatal\1"
syn match autoitOption "\([\"\']\)SendAttachMode\1"
syn match autoitOption "\([\"\']\)SendCapslockMode\1"
syn match autoitOption "\([\"\']\)SendKeyDelay\1"
syn match autoitOption "\([\"\']\)SendKeyDownDelay\1"
syn match autoitOption "\([\"\']\)TCPTimeout\1"
syn match autoitOption "\([\"\']\)TrayAutoPause\1"
syn match autoitOption "\([\"\']\)TrayIconDebug\1"
syn match autoitOption "\([\"\']\)TrayIconHide\1"
syn match autoitOption "\([\"\']\)TrayMenuMode\1"
syn match autoitOption "\([\"\']\)TrayOnEventMode\1"
syn match autoitOption "\([\"\']\)WinDetectHiddenText\1"
syn match autoitOption "\([\"\']\)WinSearchChildren\1"
syn match autoitOption "\([\"\']\)WinTextMatchMode\1"
syn match autoitOption "\([\"\']\)WinTitleMatchMode\1"
syn match autoitOption "\([\"\']\)WinWaitDelay\1"

" styles - must be defined after autoitVariable
" common
syn match autoitStyle "\$WS_BORDER"
syn match autoitStyle "\$WS_POPUP"
syn match autoitStyle "\$WS_CAPTION"
syn match autoitStyle "\$WS_CLIPCHILDREN"
syn match autoitStyle "\$WS_CLIPSIBLINGS"
syn match autoitStyle "\$WS_DISABLED"
syn match autoitStyle "\$WS_DLGFRAME"
syn match autoitStyle "\$WS_HSCROLL"
syn match autoitStyle "\$WS_MAXIMIZE"
syn match autoitStyle "\$WS_MAXIMIZEBOX"
syn match autoitStyle "\$WS_MINIMIZE"
syn match autoitStyle "\$WS_MINIMIZEBOX"
syn match autoitStyle "\$WS_OVERLAPPED"
syn match autoitStyle "\$WS_OVERLAPPEDWINDOW"
syn match autoitStyle "\$WS_POPUPWINDOW"
syn match autoitStyle "\$WS_SIZEBOX"
syn match autoitStyle "\$WS_SYSMENU"
syn match autoitStyle "\$WS_THICKFRAME"
syn match autoitStyle "\$WS_VSCROLL"
syn match autoitStyle "\$WS_VISIBLE"
syn match autoitStyle "\$WS_CHILD"
syn match autoitStyle "\$WS_GROUP"
syn match autoitStyle "\$WS_TABSTOP"
syn match autoitStyle "\$DS_MODALFRAME"
syn match autoitStyle "\$DS_SETFOREGROUND"
syn match autoitStyle "\$DS_CONTEXTHELP"
" common extended
syn match autoitStyle "\$WS_EX_ACCEPTFILES"
syn match autoitStyle "\$WS_EX_APPWINDOW"
syn match autoitStyle "\$WS_EX_CLIENTEDGE"
syn match autoitStyle "\$WS_EX_CONTEXTHELP"
syn match autoitStyle "\$WS_EX_DLGMODALFRAME"
syn match autoitStyle "\$WS_EX_MDICHILD"
syn match autoitStyle "\$WS_EX_OVERLAPPEDWINDOW"
syn match autoitStyle "\$WS_EX_STATICEDGE"
syn match autoitStyle "\$WS_EX_TOPMOST"
syn match autoitStyle "\$WS_EX_TRANSPARENT"
syn match autoitStyle "\$WS_EX_TOOLWINDOW"
syn match autoitStyle "\$WS_EX_WINDOWEDGE"
syn match autoitStyle "\$WS_EX_LAYERED"
syn match autoitStyle "\$GUI_WS_EX_PARENTDRAG"
" checkbox
syn match autoitStyle "\$BS_3STATE"
syn match autoitStyle "\$BS_AUTO3STATE"
syn match autoitStyle "\$BS_AUTOCHECKBOX"
syn match autoitStyle "\$BS_CHECKBOX"
syn match autoitStyle "\$BS_LEFT"
syn match autoitStyle "\$BS_PUSHLIKE"
syn match autoitStyle "\$BS_RIGHT"
syn match autoitStyle "\$BS_RIGHTBUTTON"
syn match autoitStyle "\$BS_GROUPBOX"
syn match autoitStyle "\$BS_AUTORADIOBUTTON"
" push button
syn match autoitStyle "\$BS_BOTTOM"
syn match autoitStyle "\$BS_CENTER"
syn match autoitStyle "\$BS_DEFPUSHBUTTON"
syn match autoitStyle "\$BS_MULTILINE"
syn match autoitStyle "\$BS_TOP"
syn match autoitStyle "\$BS_VCENTER"
syn match autoitStyle "\$BS_ICON"
syn match autoitStyle "\$BS_BITMAP"
syn match autoitStyle "\$BS_FLAT"
" combo
syn match autoitStyle "\$CBS_AUTOHSCROLL"
syn match autoitStyle "\$CBS_DISABLENOSCROLL"
syn match autoitStyle "\$CBS_DROPDOWN"
syn match autoitStyle "\$CBS_DROPDOWNLIST"
syn match autoitStyle "\$CBS_LOWERCASE"
syn match autoitStyle "\$CBS_NOINTEGRALHEIGHT"
syn match autoitStyle "\$CBS_OEMCONVERT"
syn match autoitStyle "\$CBS_SIMPLE"
syn match autoitStyle "\$CBS_SORT"
syn match autoitStyle "\$CBS_UPPERCASE"
" list
syn match autoitStyle "\$LBS_DISABLENOSCROLL"
syn match autoitStyle "\$LBS_NOINTEGRALHEIGHT"
syn match autoitStyle "\$LBS_NOSEL"
syn match autoitStyle "\$LBS_NOTIFY"
syn match autoitStyle "\$LBS_SORT"
syn match autoitStyle "\$LBS_STANDARD"
syn match autoitStyle "\$LBS_USETABSTOPS"
" edit/input
syn match autoitStyle "\$ES_AUTOHSCROLL"
syn match autoitStyle "\$ES_AUTOVSCROLL"
syn match autoitStyle "\$ES_CENTER"
syn match autoitStyle "\$ES_LOWERCASE"
syn match autoitStyle "\$ES_NOHIDESEL"
syn match autoitStyle "\$ES_NUMBER"
syn match autoitStyle "\$ES_OEMCONVERT"
syn match autoitStyle "\$ES_MULTILINE"
syn match autoitStyle "\$ES_PASSWORD"
syn match autoitStyle "\$ES_READONLY"
syn match autoitStyle "\$ES_RIGHT"
syn match autoitStyle "\$ES_UPPERCASE"
syn match autoitStyle "\$ES_WANTRETURN"
" progress bar
syn match autoitStyle "\$PBS_SMOOTH"
syn match autoitStyle "\$PBS_VERTICAL"
" up-down
syn match autoitStyle "\$UDS_ALIGNLEFT"
syn match autoitStyle "\$UDS_ALIGNRIGHT"
syn match autoitStyle "\$UDS_ARROWKEYS"
syn match autoitStyle "\$UDS_HORZ"
syn match autoitStyle "\$UDS_NOTHOUSANDS"
syn match autoitStyle "\$UDS_WRAP"
" label/static
syn match autoitStyle "\$SS_BLACKFRAME"
syn match autoitStyle "\$SS_BLACKRECT"
syn match autoitStyle "\$SS_CENTER"
syn match autoitStyle "\$SS_CENTERIMAGE"
syn match autoitStyle "\$SS_ETCHEDFRAME"
syn match autoitStyle "\$SS_ETCHEDHORZ"
syn match autoitStyle "\$SS_ETCHEDVERT"
syn match autoitStyle "\$SS_GRAYFRAME"
syn match autoitStyle "\$SS_GRAYRECT"
syn match autoitStyle "\$SS_LEFT"
syn match autoitStyle "\$SS_LEFTNOWORDWRAP"
syn match autoitStyle "\$SS_NOPREFIX"
syn match autoitStyle "\$SS_NOTIFY"
syn match autoitStyle "\$SS_RIGHT"
syn match autoitStyle "\$SS_RIGHTJUST"
syn match autoitStyle "\$SS_SIMPLE"
syn match autoitStyle "\$SS_SUNKEN"
syn match autoitStyle "\$SS_WHITEFRAME"
syn match autoitStyle "\$SS_WHITERECT"
" tab
syn match autoitStyle "\$TCS_SCROLLOPPOSITE"
syn match autoitStyle "\$TCS_BOTTOM"
syn match autoitStyle "\$TCS_RIGHT"
syn match autoitStyle "\$TCS_MULTISELECT"
syn match autoitStyle "\$TCS_FLATBUTTONS"
syn match autoitStyle "\$TCS_FORCEICONLEFT"
syn match autoitStyle "\$TCS_FORCELABELLEFT"
syn match autoitStyle "\$TCS_HOTTRACK"
syn match autoitStyle "\$TCS_VERTICAL"
syn match autoitStyle "\$TCS_TABS"
syn match autoitStyle "\$TCS_BUTTONS"
syn match autoitStyle "\$TCS_SINGLELINE"
syn match autoitStyle "\$TCS_MULTILINE"
syn match autoitStyle "\$TCS_RIGHTJUSTIFY"
syn match autoitStyle "\$TCS_FIXEDWIDTH"
syn match autoitStyle "\$TCS_RAGGEDRIGHT"
syn match autoitStyle "\$TCS_FOCUSONBUTTONDOWN"
syn match autoitStyle "\$TCS_OWNERDRAWFIXED"
syn match autoitStyle "\$TCS_TOOLTIPS"
syn match autoitStyle "\$TCS_FOCUSNEVER"
" avi clip
syn match autoitStyle "\$ACS_AUTOPLAY"
syn match autoitStyle "\$ACS_CENTER"
syn match autoitStyle "\$ACS_TRANSPARENT"
syn match autoitStyle "\$ACS_NONTRANSPARENT"
" date
syn match autoitStyle "\$DTS_UPDOWN"
syn match autoitStyle "\$DTS_SHOWNONE"
syn match autoitStyle "\$DTS_LONGDATEFORMAT"
syn match autoitStyle "\$DTS_TIMEFORMAT"
syn match autoitStyle "\$DTS_RIGHTALIGN"
syn match autoitStyle "\$DTS_SHORTDATEFORMAT"
" monthcal
syn match autoitStyle "\$MCS_NOTODAY"
syn match autoitStyle "\$MCS_NOTODAYCIRCLE"
syn match autoitStyle "\$MCS_WEEKNUMBERS"
" treeview
syn match autoitStyle "\$TVS_HASBUTTONS"
syn match autoitStyle "\$TVS_HASLINES"
syn match autoitStyle "\$TVS_LINESATROOT"
syn match autoitStyle "\$TVS_DISABLEDRAGDROP"
syn match autoitStyle "\$TVS_SHOWSELALWAYS"
syn match autoitStyle "\$TVS_RTLREADING"
syn match autoitStyle "\$TVS_NOTOOLTIPS"
syn match autoitStyle "\$TVS_CHECKBOXES"
syn match autoitStyle "\$TVS_TRACKSELECT"
syn match autoitStyle "\$TVS_SINGLEEXPAND"
syn match autoitStyle "\$TVS_FULLROWSELECT"
syn match autoitStyle "\$TVS_NOSCROLL"
syn match autoitStyle "\$TVS_NONEVENHEIGHT"
" slider
syn match autoitStyle "\$TBS_AUTOTICKS"
syn match autoitStyle "\$TBS_BOTH"
syn match autoitStyle "\$TBS_BOTTOM"
syn match autoitStyle "\$TBS_HORZ"
syn match autoitStyle "\$TBS_VERT"
syn match autoitStyle "\$TBS_NOTHUMB"
syn match autoitStyle "\$TBS_NOTICKS"
syn match autoitStyle "\$TBS_LEFT"
syn match autoitStyle "\$TBS_RIGHT"
syn match autoitStyle "\$TBS_TOP"
" listview
syn match autoitStyle "\$LVS_ICON"
syn match autoitStyle "\$LVS_REPORT"
syn match autoitStyle "\$LVS_SMALLICON"
syn match autoitStyle "\$LVS_LIST"
syn match autoitStyle "\$LVS_EDITLABELS"
syn match autoitStyle "\$LVS_NOCOLUMNHEADER"
syn match autoitStyle "\$LVS_NOSORTHEADER"
syn match autoitStyle "\$LVS_SINGLESEL"
syn match autoitStyle "\$LVS_SHOWSELALWAYS"
syn match autoitStyle "\$LVS_SORTASCENDING"
syn match autoitStyle "\$LVS_SORTDESCENDING"
" listview extended
syn match autoitStyle "\$LVS_EX_FULLROWSELECT"
syn match autoitStyle "\$LVS_EX_GRIDLINES"
syn match autoitStyle "\$LVS_EX_HEADERDRAGDROP"
syn match autoitStyle "\$LVS_EX_TRACKSELECT"
syn match autoitStyle "\$LVS_EX_CHECKBOXES"
syn match autoitStyle "\$LVS_EX_BORDERSELECT"
syn match autoitStyle "\$LVS_EX_DOUBLEBUFFER"
syn match autoitStyle "\$LVS_EX_FLATSB"
syn match autoitStyle "\$LVS_EX_MULTIWORKAREAS"
syn match autoitStyle "\$LVS_EX_SNAPTOGRID"
syn match autoitStyle "\$LVS_EX_SUBITEMIMAGES"

" constants - must be defined after autoitVariable - excludes styles
" constants - autoit options
syn match autoitConst "\$OPT_COORDSRELATIVE"
syn match autoitConst "\$OPT_COORDSABSOLUTE"
syn match autoitConst "\$OPT_COORDSCLIENT"
syn match autoitConst "\$OPT_ERRORSILENT"
syn match autoitConst "\$OPT_ERRORFATAL"
syn match autoitConst "\$OPT_CAPSNOSTORE"
syn match autoitConst "\$OPT_CAPSSTORE"
syn match autoitConst "\$OPT_MATCHSTART"
syn match autoitConst "\$OPT_MATCHANY"
syn match autoitConst "\$OPT_MATCHEXACT"
syn match autoitConst "\$OPT_MATCHADVANCED"
" constants - file
syn match autoitConst "\$FC_NOOVERWRITE"
syn match autoitConst "\$FC_OVERWRITE"
syn match autoitConst "\$FT_MODIFIED"
syn match autoitConst "\$FT_CREATED"
syn match autoitConst "\$FT_ACCESSED"
syn match autoitConst "\$FO_READ"
syn match autoitConst "\$FO_APPEND"
syn match autoitConst "\$FO_OVERWRITE"
syn match autoitConst "\$EOF"
syn match autoitConst "\$FD_FILEMUSTEXIST"
syn match autoitConst "\$FD_PATHMUSTEXIST"
syn match autoitConst "\$FD_MULTISELECT"
syn match autoitConst "\$FD_PROMPTCREATENEW"
syn match autoitConst "\$FD_PROMPTOVERWRITE"
" constants - keyboard
syn match autoitConst "\$KB_SENDSPECIAL"
syn match autoitConst "\$KB_SENDRAW"
syn match autoitConst "\$KB_CAPSOFF"
syn match autoitConst "\$KB_CAPSON"
" constants - message box
syn match autoitConst "\$MB_OK"
syn match autoitConst "\$MB_OKCANCEL"
syn match autoitConst "\$MB_ABORTRETRYIGNORE"
syn match autoitConst "\$MB_YESNOCANCEL"
syn match autoitConst "\$MB_YESNO"
syn match autoitConst "\$MB_RETRYCANCEL"
syn match autoitConst "\$MB_ICONHAND"
syn match autoitConst "\$MB_ICONQUESTION"
syn match autoitConst "\$MB_ICONEXCLAMATION"
syn match autoitConst "\$MB_ICONASTERISK"
syn match autoitConst "\$MB_DEFBUTTON1"
syn match autoitConst "\$MB_DEFBUTTON2"
syn match autoitConst "\$MB_DEFBUTTON3"
syn match autoitConst "\$MB_APPLMODAL"
syn match autoitConst "\$MB_SYSTEMMODAL"
syn match autoitConst "\$MB_TASKMODAL"
syn match autoitConst "\$MB_TOPMOST"
syn match autoitConst "\$MB_RIGHTJUSTIFIED"
syn match autoitConst "\$IDTIMEOUT"
syn match autoitConst "\$IDOK"
syn match autoitConst "\$IDCANCEL"
syn match autoitConst "\$IDABORT"
syn match autoitConst "\$IDRETRY"
syn match autoitConst "\$IDIGNORE"
syn match autoitConst "\$IDYES"
syn match autoitConst "\$IDNO"
syn match autoitConst "\$IDTRYAGAIN"
syn match autoitConst "\$IDCONTINUE"
" constants - progress and splash
syn match autoitConst "\$DLG_NOTITLE"
syn match autoitConst "\$DLG_NOTONTOP"
syn match autoitConst "\$DLG_TEXTLEFT"
syn match autoitConst "\$DLG_TEXTRIGHT"
syn match autoitConst "\$DLG_MOVEABLE"
syn match autoitConst "\$DLG_TEXTVCENTER"
" constants - tray tip
syn match autoitConst "\$TIP_ICONNONE"
syn match autoitConst "\$TIP_ICONASTERISK"
syn match autoitConst "\$TIP_ICONEXCLAMATION"
syn match autoitConst "\$TIP_ICONHAND"
syn match autoitConst "\$TIP_NOSOUND"
" constants - mouse
syn match autoitConst "\$IDC_UNKNOWN"
syn match autoitConst "\$IDC_APPSTARTING"
syn match autoitConst "\$IDC_ARROW"
syn match autoitConst "\$IDC_CROSS"
syn match autoitConst "\$IDC_HELP"
syn match autoitConst "\$IDC_IBEAM"
syn match autoitConst "\$IDC_ICON"
syn match autoitConst "\$IDC_NO"
syn match autoitConst "\$IDC_SIZE"
syn match autoitConst "\$IDC_SIZEALL"
syn match autoitConst "\$IDC_SIZENESW"
syn match autoitConst "\$IDC_SIZENS"
syn match autoitConst "\$IDC_SIZENWSE"
syn match autoitConst "\$IDC_SIZEWE"
syn match autoitConst "\$IDC_UPARROW"
syn match autoitConst "\$IDC_WAIT"
" constants - process
syn match autoitConst "\$SD_LOGOFF"
syn match autoitConst "\$SD_SHUTDOWN"
syn match autoitConst "\$SD_REBOOT"
syn match autoitConst "\$SD_FORCE"
syn match autoitConst "\$SD_POWERDOWN"
" constants - string
syn match autoitConst "\$STR_NOCASESENSE"
syn match autoitConst "\$STR_CASESENSE"
syn match autoitConst "\$STR_STRIPLEADING"
syn match autoitConst "\$STR_STRIPTRAILING"
syn match autoitConst "\$STR_STRIPSPACES"
syn match autoitConst "\$STR_STRIPALL"
" constants - tray
syn match autoitConst "\$TRAY_ITEM_EXIT"
syn match autoitConst "\$TRAY_ITEM_PAUSE"
syn match autoitConst "\$TRAY_ITEM_FIRST"
syn match autoitConst "\$TRAY_CHECKED"
syn match autoitConst "\$TRAY_UNCHECKED"
syn match autoitConst "\$TRAY_ENABLE"
syn match autoitConst "\$TRAY_DISABLE"
syn match autoitConst "\$TRAY_FOCUS"
syn match autoitConst "\$TRAY_DEFAULT"
syn match autoitConst "\$TRAY_EVENT_SHOWICON"
syn match autoitConst "\$TRAY_EVENT_HIDEICON"
syn match autoitConst "\$TRAY_EVENT_FLASHICON"
syn match autoitConst "\$TRAY_EVENT_NOFLASHICON"
syn match autoitConst "\$TRAY_EVENT_PRIMARYDOWN"
syn match autoitConst "\$TRAY_EVENT_PRIMARYUP"
syn match autoitConst "\$TRAY_EVENT_SECONDARYDOWN"
syn match autoitConst "\$TRAY_EVENT_SECONDARYUP"
syn match autoitConst "\$TRAY_EVENT_MOUSEOVER"
syn match autoitConst "\$TRAY_EVENT_MOUSEOUT"
syn match autoitConst "\$TRAY_EVENT_PRIMARYDOUBLE"
syn match autoitConst "\$TRAY_EVENT_SECONDARYDOUBLE"
" constants - stdio
syn match autoitConst "\$STDIN_CHILD"
syn match autoitConst "\$STDOUT_CHILD"
syn match autoitConst "\$STDERR_CHILD"
" constants - color
syn match autoitConst "\$COLOR_BLACK"
syn match autoitConst "\$COLOR_SILVER"
syn match autoitConst "\$COLOR_GRAY"
syn match autoitConst "\$COLOR_WHITE"
syn match autoitConst "\$COLOR_MAROON"
syn match autoitConst "\$COLOR_RED"
syn match autoitConst "\$COLOR_PURPLE"
syn match autoitConst "\$COLOR_FUCHSIA"
syn match autoitConst "\$COLOR_GREEN"
syn match autoitConst "\$COLOR_LIME"
syn match autoitConst "\$COLOR_OLIVE"
syn match autoitConst "\$COLOR_YELLOW"
syn match autoitConst "\$COLOR_NAVY"
syn match autoitConst "\$COLOR_BLUE"
syn match autoitConst "\$COLOR_TEAL"
syn match autoitConst "\$COLOR_AQUA"
" constants - reg value type
syn match autoitConst "\$REG_NONE"
syn match autoitConst "\$REG_SZ"
syn match autoitConst "\$REG_EXPAND_SZ"
syn match autoitConst "\$REG_BINARY"
syn match autoitConst "\$REG_DWORD"
syn match autoitConst "\$REG_DWORD_BIG_ENDIAN"
syn match autoitConst "\$REG_LINK"
syn match autoitConst "\$REG_MULTI_SZ"
syn match autoitConst "\$REG_RESOURCE_LIST"
syn match autoitConst "\$REG_FULL_RESOURCE_DESCRIPTOR"
syn match autoitConst "\$REG_RESOURCE_REQUIREMENTS_LIST"
" guiconstants - events and messages
syn match autoitConst "\$GUI_EVENT_CLOSE"
syn match autoitConst "\$GUI_EVENT_MINIMIZE"
syn match autoitConst "\$GUI_EVENT_RESTORE"
syn match autoitConst "\$GUI_EVENT_MAXIMIZE"
syn match autoitConst "\$GUI_EVENT_PRIMARYDOWN"
syn match autoitConst "\$GUI_EVENT_PRIMARYUP"
syn match autoitConst "\$GUI_EVENT_SECONDARYDOWN"
syn match autoitConst "\$GUI_EVENT_SECONDARYUP"
syn match autoitConst "\$GUI_EVENT_MOUSEMOVE"
syn match autoitConst "\$GUI_EVENT_RESIZED"
syn match autoitConst "\$GUI_EVENT_DROPPED"
syn match autoitConst "\$GUI_RUNDEFMSG"
" guiconstants - state
syn match autoitConst "\$GUI_AVISTOP"
syn match autoitConst "\$GUI_AVISTART"
syn match autoitConst "\$GUI_AVICLOSE"
syn match autoitConst "\$GUI_CHECKED"
syn match autoitConst "\$GUI_INDETERMINATE"
syn match autoitConst "\$GUI_UNCHECKED"
syn match autoitConst "\$GUI_DROPACCEPTED"
syn match autoitConst "\$GUI_DROPNOTACCEPTED"
syn match autoitConst "\$GUI_ACCEPTFILES"
syn match autoitConst "\$GUI_SHOW"
syn match autoitConst "\$GUI_HIDE"
syn match autoitConst "\$GUI_ENABLE"
syn match autoitConst "\$GUI_DISABLE"
syn match autoitConst "\$GUI_FOCUS"
syn match autoitConst "\$GUI_NOFOCUS"
syn match autoitConst "\$GUI_DEFBUTTON"
syn match autoitConst "\$GUI_EXPAND"
syn match autoitConst "\$GUI_ONTOP"
" guiconstants - font
syn match autoitConst "\$GUI_FONTITALIC"
syn match autoitConst "\$GUI_FONTUNDER"
syn match autoitConst "\$GUI_FONTSTRIKE"
" guiconstants - resizing
syn match autoitConst "\$GUI_DOCKAUTO"
syn match autoitConst "\$GUI_DOCKLEFT"
syn match autoitConst "\$GUI_DOCKRIGHT"
syn match autoitConst "\$GUI_DOCKHCENTER"
syn match autoitConst "\$GUI_DOCKTOP"
syn match autoitConst "\$GUI_DOCKBOTTOM"
syn match autoitConst "\$GUI_DOCKVCENTER"
syn match autoitConst "\$GUI_DOCKWIDTH"
syn match autoitConst "\$GUI_DOCKHEIGHT"
syn match autoitConst "\$GUI_DOCKSIZE"
syn match autoitConst "\$GUI_DOCKMENUBAR"
syn match autoitConst "\$GUI_DOCKSTATEBAR"
syn match autoitConst "\$GUI_DOCKALL"
syn match autoitConst "\$GUI_DOCKBORDERS"
" guiconstants - graphic
syn match autoitConst "\$GUI_GR_CLOSE"
syn match autoitConst "\$GUI_GR_LINE"
syn match autoitConst "\$GUI_GR_BEZIER"
syn match autoitConst "\$GUI_GR_MOVE"
syn match autoitConst "\$GUI_GR_COLOR"
syn match autoitConst "\$GUI_GR_RECT"
syn match autoitConst "\$GUI_GR_ELLIPSE"
syn match autoitConst "\$GUI_GR_PIE"
syn match autoitConst "\$GUI_GR_DOT"
syn match autoitConst "\$GUI_GR_PIXEL"
syn match autoitConst "\$GUI_GR_HINT"
syn match autoitConst "\$GUI_GR_REFRESH"
syn match autoitConst "\$GUI_GR_PENSIZE"
syn match autoitConst "\$GUI_GR_NOBKCOLOR"
" guiconstants - control default styles
syn match autoitConst "\$GUI_SS_DEFAULT_AVI"
syn match autoitConst "\$GUI_SS_DEFAULT_BUTTON"
syn match autoitConst "\$GUI_SS_DEFAULT_CHECKBOX"
syn match autoitConst "\$GUI_SS_DEFAULT_COMBO"
syn match autoitConst "\$GUI_SS_DEFAULT_DATE"
syn match autoitConst "\$GUI_SS_DEFAULT_EDIT"
syn match autoitConst "\$GUI_SS_DEFAULT_GRAPHIC"
syn match autoitConst "\$GUI_SS_DEFAULT_GROUP"
syn match autoitConst "\$GUI_SS_DEFAULT_ICON"
syn match autoitConst "\$GUI_SS_DEFAULT_INPUT"
syn match autoitConst "\$GUI_SS_DEFAULT_LABEL"
syn match autoitConst "\$GUI_SS_DEFAULT_LIST"
syn match autoitConst "\$GUI_SS_DEFAULT_LISTVIEW"
syn match autoitConst "\$GUI_SS_DEFAULT_MONTHCAL"
syn match autoitConst "\$GUI_SS_DEFAULT_PIC"
syn match autoitConst "\$GUI_SS_DEFAULT_PROGRESS"
syn match autoitConst "\$GUI_SS_DEFAULT_RADIO"
syn match autoitConst "\$GUI_SS_DEFAULT_SLIDER"
syn match autoitConst "\$GUI_SS_DEFAULT_TAB"
syn match autoitConst "\$GUI_SS_DEFAULT_TREEVIEW"
syn match autoitConst "\$GUI_SS_DEFAULT_UPDOWN"
syn match autoitConst "\$GUI_SS_DEFAULT_GUI"
" guiconstants - background color special flags
syn match autoitConst "\$GUI_BKCOLOR_DEFAULT"
syn match autoitConst "\$GUI_BKCOLOR_LV_ALTERNATE"
syn match autoitConst "\$GUI_BKCOLOR_TRANSPARENT"

" registry constants
syn match autoitConst "\([\"\']\)REG_BINARY\1"
syn match autoitConst "\([\"\']\)REG_SZ\1"
syn match autoitConst "\([\"\']\)REG_MULTI_SZ\1"
syn match autoitConst "\([\"\']\)REG_EXPAND_SZ\1"
syn match autoitConst "\([\"\']\)REG_DWORD\1"

" Define the default highlighting.
" Unused colors: Underlined, Ignore, Error, Todo
hi def link autoitFunction Statement  " yellow/yellow
hi def link autoitKeyword Statement
hi def link autoitOperator Operator
hi def link autoitVarSelector Operator
hi def link autoitComment	Comment  " cyan/blue
hi def link autoitParen Comment
hi def link autoitComma Comment
hi def link autoitBracket Comment
hi def link autoitNumber Constant " magenta/red
hi def link autoitString Constant
hi def link autoitQuote Constant
hi def link autoitIncluded Constant
hi def link autoitCont Special  " red/orange
hi def link autoitDoubledSingles Special
hi def link autoitDoubledDoubles Special
hi def link autoitCommDelimiter PreProc  " blue/magenta
hi def link autoitInclude PreProc
hi def link autoitVariable Identifier  " cyan/cyan
hi def link autoitBuiltin Type  " green/green
hi def link autoitOption Type
hi def link autoitStyle Type
hi def link autoitConst Type
hi def link autoitSend Type

syn sync minlines=50

let &cpo = s:keepcpo
unlet s:keepcpo
