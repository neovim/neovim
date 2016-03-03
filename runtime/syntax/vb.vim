" Vim syntax file
" Language:	Visual Basic
" Maintainer:	Tim Chase <vb.vim@tim.thechases.com>
" Former Maintainer:	Robert M. Cortopassi <cortopar@mindspring.com>
"	(tried multiple times to contact, but email bounced)
" Last Change:
"   2005 May 25  Synched with work by Thomas Barthel
"   2004 May 30  Added a few keywords

" This was thrown together after seeing numerous requests on the
" VIM and VIM-DEV mailing lists.  It is by no means complete.
" Send comments, suggestions and requests to the maintainer.

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
	syntax clear
elseif exists("b:current_syntax")
	finish
endif

" VB is case insensitive
syn case ignore

syn keyword vbConditional If Then ElseIf Else Select Case

syn keyword vbOperator AddressOf And ByRef ByVal Eqv Imp In
syn keyword vbOperator Is Like Mod Not Or To Xor

syn match vbOperator "[()+.,\-/*=&]"
syn match vbOperator "[<>]=\="
syn match vbOperator "<>"
syn match vbOperator "\s\+_$"

syn keyword vbBoolean  True False
syn keyword vbConst Null Nothing

syn keyword vbRepeat Do For ForEach Loop Next
syn keyword vbRepeat Step To Until Wend While

syn keyword vbEvents AccessKeyPress Activate ActiveRowChanged
syn keyword vbEvents AfterAddFile AfterChangeFileName AfterCloseFile
syn keyword vbEvents AfterColEdit AfterColUpdate AfterDelete
syn keyword vbEvents AfterInsert AfterLabelEdit AfterRemoveFile
syn keyword vbEvents AfterUpdate AfterWriteFile AmbientChanged
syn keyword vbEvents ApplyChanges Associate AsyncProgress
syn keyword vbEvents AsyncReadComplete AsyncReadProgress AxisActivated
syn keyword vbEvents AxisLabelActivated AxisLabelSelected
syn keyword vbEvents AxisLabelUpdated AxisSelected AxisTitleActivated
syn keyword vbEvents AxisTitleSelected AxisTitleUpdated AxisUpdated
syn keyword vbEvents BeforeClick BeforeColEdit BeforeColUpdate
syn keyword vbEvents BeforeConnect BeforeDelete BeforeInsert
syn keyword vbEvents BeforeLabelEdit BeforeLoadFile BeforeUpdate
syn keyword vbEvents BeginRequest BeginTrans ButtonClick
syn keyword vbEvents ButtonCompleted ButtonDropDown ButtonGotFocus
syn keyword vbEvents ButtonLostFocus CallbackKeyDown Change Changed
syn keyword vbEvents ChartActivated ChartSelected ChartUpdated Click
syn keyword vbEvents Close CloseQuery CloseUp ColEdit ColResize
syn keyword vbEvents Collapse ColumnClick CommitTrans Compare
syn keyword vbEvents ConfigChageCancelled ConfigChanged
syn keyword vbEvents ConfigChangedCancelled Connect ConnectionRequest
syn keyword vbEvents CurrentRecordChanged DECommandAdded
syn keyword vbEvents DECommandPropertyChanged DECommandRemoved
syn keyword vbEvents DEConnectionAdded DEConnectionPropertyChanged
syn keyword vbEvents DEConnectionRemoved DataArrival DataChanged
syn keyword vbEvents DataUpdated DateClicked DblClick Deactivate
syn keyword vbEvents DevModeChange DeviceArrival DeviceOtherEvent
syn keyword vbEvents DeviceQueryRemove DeviceQueryRemoveFailed
syn keyword vbEvents DeviceRemoveComplete DeviceRemovePending
syn keyword vbEvents Disconnect DisplayChanged Dissociate
syn keyword vbEvents DoGetNewFileName Done DonePainting DownClick
syn keyword vbEvents DragDrop DragOver DropDown EditProperty EditQuery
syn keyword vbEvents EndRequest EnterCell EnterFocus ExitFocus Expand
syn keyword vbEvents FontChanged FootnoteActivated FootnoteSelected
syn keyword vbEvents FootnoteUpdated Format FormatSize GotFocus
syn keyword vbEvents HeadClick HeightChanged Hide InfoMessage
syn keyword vbEvents IniProperties InitProperties Initialize
syn keyword vbEvents ItemActivated ItemAdded ItemCheck ItemClick
syn keyword vbEvents ItemReloaded ItemRemoved ItemRenamed
syn keyword vbEvents ItemSeletected KeyDown KeyPress KeyUp LeaveCell
syn keyword vbEvents LegendActivated LegendSelected LegendUpdated
syn keyword vbEvents LinkClose LinkError LinkExecute LinkNotify
syn keyword vbEvents LinkOpen Load LostFocus MouseDown MouseMove
syn keyword vbEvents MouseUp NodeCheck NodeClick OLECompleteDrag
syn keyword vbEvents OLEDragDrop OLEDragOver OLEGiveFeedback OLESetData
syn keyword vbEvents OLEStartDrag ObjectEvent ObjectMove OnAddNew
syn keyword vbEvents OnComm Paint PanelClick PanelDblClick PathChange
syn keyword vbEvents PatternChange PlotActivated PlotSelected
syn keyword vbEvents PlotUpdated PointActivated PointLabelActivated
syn keyword vbEvents PointLabelSelected PointLabelUpdated PointSelected
syn keyword vbEvents PointUpdated PowerQuerySuspend PowerResume
syn keyword vbEvents PowerStatusChanged PowerSuspend ProcessTag
syn keyword vbEvents ProcessingTimeout QueryChangeConfig QueryClose
syn keyword vbEvents QueryComplete QueryCompleted QueryTimeout
syn keyword vbEvents QueryUnload ReadProperties RepeatedControlLoaded
syn keyword vbEvents RepeatedControlUnloaded Reposition
syn keyword vbEvents RequestChangeFileName RequestWriteFile Resize
syn keyword vbEvents ResultsChanged RetainedProject RollbackTrans
syn keyword vbEvents RowColChange RowCurrencyChange RowResize
syn keyword vbEvents RowStatusChanged Scroll SelChange SelectionChanged
syn keyword vbEvents SendComplete SendProgress SeriesActivated
syn keyword vbEvents SeriesSelected SeriesUpdated SettingChanged Show
syn keyword vbEvents SplitChange Start StateChanged StatusUpdate
syn keyword vbEvents SysColorsChanged Terminate TimeChanged Timer
syn keyword vbEvents TitleActivated TitleSelected TitleUpdated
syn keyword vbEvents UnboundAddData UnboundDeleteRow
syn keyword vbEvents UnboundGetRelativeBookmark UnboundReadData
syn keyword vbEvents UnboundWriteData Unformat Unload UpClick Updated
syn keyword vbEvents UserEvent Validate ValidationError
syn keyword vbEvents VisibleRecordChanged WillAssociate WillChangeData
syn keyword vbEvents WillDissociate WillExecute WillUpdateRows
syn keyword vbEvents WriteProperties


syn keyword vbFunction Abs Array Asc AscB AscW Atn Avg BOF CBool CByte
syn keyword vbFunction CCur CDate CDbl CInt CLng CSng CStr CVDate CVErr
syn keyword vbFunction CVar CallByName Cdec Choose Chr ChrB ChrW Command
syn keyword vbFunction Cos Count CreateObject CurDir DDB Date DateAdd
syn keyword vbFunction DateDiff DatePart DateSerial DateValue Day Dir
syn keyword vbFunction DoEvents EOF Environ Error Exp FV FileAttr
syn keyword vbFunction FileDateTime FileLen FilterFix Fix Format
syn keyword vbFunction FormatCurrency FormatDateTime FormatNumber
syn keyword vbFunction FormatPercent FreeFile GetAllStrings GetAttr
syn keyword vbFunction GetAutoServerSettings GetObject GetSetting Hex
syn keyword vbFunction Hour IIf IMEStatus IPmt InStr Input InputB
syn keyword vbFunction InputBox InstrB Int IsArray IsDate IsEmpty IsError
syn keyword vbFunction IsMissing IsNull IsNumeric IsObject Join LBound
syn keyword vbFunction LCase LOF LTrim Left LeftB Len LenB LoadPicture
syn keyword vbFunction LoadResData LoadResPicture LoadResString Loc Log
syn keyword vbFunction MIRR Max Mid MidB Min Minute Month MonthName
syn keyword vbFunction MsgBox NPV NPer Now Oct PPmt PV Partition Pmt
syn keyword vbFunction QBColor RGB RTrim Rate Replace Right RightB Rnd
syn keyword vbFunction Round SLN SYD Second Seek Sgn Shell Sin Space Spc
syn keyword vbFunction Split Sqr StDev StDevP Str StrComp StrConv
syn keyword vbFunction StrReverse String Sum Switch Tab Tan Time
syn keyword vbFunction TimeSerial TimeValue Timer Trim TypeName UBound
syn keyword vbFunction UCase Val Var VarP VarType Weekday WeekdayName
syn keyword vbFunction Year

syn keyword vbMethods AboutBox Accept Activate Add AddCustom AddFile
syn keyword vbMethods AddFromFile AddFromGuid AddFromString
syn keyword vbMethods AddFromTemplate AddItem AddNew AddToAddInToolbar
syn keyword vbMethods AddToolboxProgID Append AppendAppendChunk
syn keyword vbMethods AppendChunk Arrange Assert AsyncRead BatchUpdate
syn keyword vbMethods BeginQueryEdit BeginTrans Bind BuildPath
syn keyword vbMethods CanPropertyChange Cancel CancelAsyncRead
syn keyword vbMethods CancelBatch CancelUpdate CaptureImage CellText
syn keyword vbMethods CellValue Circle Clear ClearFields ClearSel
syn keyword vbMethods ClearSelCols ClearStructure Clone Close Cls
syn keyword vbMethods ColContaining CollapseAll ColumnSize CommitTrans
syn keyword vbMethods CompactDatabase Compose Connect Copy CopyFile
syn keyword vbMethods CopyFolder CopyQueryDef Count CreateDatabase
syn keyword vbMethods CreateDragImage CreateEmbed CreateField
syn keyword vbMethods CreateFolder CreateGroup CreateIndex CreateLink
syn keyword vbMethods CreatePreparedStatement CreatePropery CreateQuery
syn keyword vbMethods CreateQueryDef CreateRelation CreateTableDef
syn keyword vbMethods CreateTextFile CreateToolWindow CreateUser
syn keyword vbMethods CreateWorkspace Customize Cut Delete
syn keyword vbMethods DeleteColumnLabels DeleteColumns DeleteFile
syn keyword vbMethods DeleteFolder DeleteLines DeleteRowLabels
syn keyword vbMethods DeleteRows DeselectAll DesignerWindow DoVerb Drag
syn keyword vbMethods Draw DriveExists Edit EditCopy EditPaste EndDoc
syn keyword vbMethods EnsureVisible EstablishConnection Execute Exists
syn keyword vbMethods Expand Export ExportReport ExtractIcon Fetch
syn keyword vbMethods FetchVerbs FileExists Files FillCache Find
syn keyword vbMethods FindFirst FindItem FindLast FindNext FindPrevious
syn keyword vbMethods FolderExists Forward GetAbsolutePathName
syn keyword vbMethods GetBaseName GetBookmark GetChunk GetClipString
syn keyword vbMethods GetData GetDrive GetDriveName GetFile GetFileName
syn keyword vbMethods GetFirstVisible GetFolder GetFormat GetHeader
syn keyword vbMethods GetLineFromChar GetNumTicks GetParentFolderName
syn keyword vbMethods GetRows GetSelectedPart GetSelection
syn keyword vbMethods GetSpecialFolder GetTempName GetText
syn keyword vbMethods GetVisibleCount GoBack GoForward Hide HitTest
syn keyword vbMethods HoldFields Idle Import InitializeLabels Insert
syn keyword vbMethods InsertColumnLabels InsertColumns InsertFile
syn keyword vbMethods InsertLines InsertObjDlg InsertRowLabels
syn keyword vbMethods InsertRows Item Keys KillDoc Layout Line Lines
syn keyword vbMethods LinkExecute LinkPoke LinkRequest LinkSend Listen
syn keyword vbMethods LoadFile LoadResData LoadResPicture LoadResString
syn keyword vbMethods LogEvent MakeCompileFile MakeCompiledFile
syn keyword vbMethods MakeReplica MoreResults Move MoveData MoveFile
syn keyword vbMethods MoveFirst MoveFolder MoveLast MoveNext
syn keyword vbMethods MovePrevious NavigateTo NewPage NewPassword
syn keyword vbMethods NextRecordset OLEDrag OnAddinsUpdate OnConnection
syn keyword vbMethods OnDisconnection OnStartupComplete Open
syn keyword vbMethods OpenAsTextStream OpenConnection OpenDatabase
syn keyword vbMethods OpenQueryDef OpenRecordset OpenResultset OpenURL
syn keyword vbMethods Overlay PSet PaintPicture PastSpecialDlg Paste
syn keyword vbMethods PeekData Play Point PopulatePartial PopupMenu
syn keyword vbMethods Print PrintForm PrintReport PropertyChanged Quit
syn keyword vbMethods Raise RandomDataFill RandomFillColumns
syn keyword vbMethods RandomFillRows ReFill Read ReadAll ReadFromFile
syn keyword vbMethods ReadLine ReadProperty Rebind Refresh RefreshLink
syn keyword vbMethods RegisterDatabase ReleaseInstance Reload Remove
syn keyword vbMethods RemoveAddInFromToolbar RemoveAll RemoveItem Render
syn keyword vbMethods RepairDatabase ReplaceLine Reply ReplyAll Requery
syn keyword vbMethods ResetCustom ResetCustomLabel ResolveName
syn keyword vbMethods RestoreToolbar Resync Rollback RollbackTrans
syn keyword vbMethods RowBookmark RowContaining RowTop Save SaveAs
syn keyword vbMethods SaveFile SaveToFile SaveToOle1File SaveToolbar
syn keyword vbMethods Scale ScaleX ScaleY Scroll SelPrint SelectAll
syn keyword vbMethods SelectPart Send SendData Set SetAutoServerSettings
syn keyword vbMethods SetData SetFocus SetOption SetSelection SetSize
syn keyword vbMethods SetText SetViewport Show ShowColor ShowFont
syn keyword vbMethods ShowHelp ShowOpen ShowPrinter ShowSave
syn keyword vbMethods ShowWhatsThis SignOff SignOn Size Skip SkipLine
syn keyword vbMethods Span Split SplitContaining StartLabelEdit
syn keyword vbMethods StartLogging Stop Synchronize Tag TextHeight
syn keyword vbMethods TextWidth ToDefaults Trace TwipsToChartPart
syn keyword vbMethods TypeByChartType URLFor Update UpdateControls
syn keyword vbMethods UpdateRecord UpdateRow Upto ValidateControls Value
syn keyword vbMethods WhatsThisMode Write WriteBlankLines WriteLine
syn keyword vbMethods WriteProperty WriteTemplate ZOrder
syn keyword vbMethods rdoCreateEnvironment rdoRegisterDataSource

syn keyword vbStatement Alias AppActivate As Base Beep Begin Call ChDir
syn keyword vbStatement ChDrive Close Const Date Declare DefBool DefByte
syn keyword vbStatement DefCur DefDate DefDbl DefDec DefInt DefLng DefObj
syn keyword vbStatement DefSng DefStr DefVar Deftype DeleteSetting Dim Do
syn keyword vbStatement Each ElseIf End Enum Erase Error Event Exit
syn keyword vbStatement Explicit FileCopy For ForEach Function Get GoSub
syn keyword vbStatement GoTo Gosub Implements Kill LSet Let Lib LineInput
syn keyword vbStatement Load Lock Loop Mid MkDir Name Next On OnError Open
syn keyword vbStatement Option Preserve Private Property Public Put RSet
syn keyword vbStatement RaiseEvent Randomize ReDim Redim Reset Resume
syn keyword vbStatement Return RmDir SavePicture SaveSetting Seek SendKeys
syn keyword vbStatement Sendkeys Set SetAttr Static Step Stop Sub Time
syn keyword vbStatement Type Unload Unlock Until Wend While Width With
syn keyword vbStatement Write

syn keyword vbKeyword As Binary ByRef ByVal Date Empty Error Friend Get
syn keyword vbKeyword Input Is Len Lock Me Mid New Nothing Null On
syn keyword vbKeyword Option Optional ParamArray Print Private Property
syn keyword vbKeyword Public PublicNotCreateable OnNewProcessSingleUse
syn keyword vbKeyword InSameProcessMultiUse GlobalMultiUse Resume Seek
syn keyword vbKeyword Set Static Step String Time WithEvents

syn keyword vbTodo contained	TODO

"Datatypes
syn keyword vbTypes Boolean Byte Currency Date Decimal Double Empty
syn keyword vbTypes Integer Long Object Single String Variant

"VB defined values
syn keyword vbDefine dbBigInt dbBinary dbBoolean dbByte dbChar
syn keyword vbDefine dbCurrency dbDate dbDecimal dbDouble dbFloat
syn keyword vbDefine dbGUID dbInteger dbLong dbLongBinary dbMemo
syn keyword vbDefine dbNumeric dbSingle dbText dbTime dbTimeStamp
syn keyword vbDefine dbVarBinary

"VB defined values
syn keyword vbDefine vb3DDKShadow vb3DFace vb3DHighlight vb3DLight
syn keyword vbDefine vb3DShadow vbAbort vbAbortRetryIgnore
syn keyword vbDefine vbActiveBorder vbActiveTitleBar vbAlias
syn keyword vbDefine vbApplicationModal vbApplicationWorkspace
syn keyword vbDefine vbAppTaskManager vbAppWindows vbArchive vbArray
syn keyword vbDefine vbBack vbBinaryCompare vbBlack vbBlue vbBoolean
syn keyword vbDefine vbButtonFace vbButtonShadow vbButtonText vbByte
syn keyword vbDefine vbCalGreg vbCalHijri vbCancel vbCr vbCritical
syn keyword vbDefine vbCrLf vbCurrency vbCyan vbDatabaseCompare
syn keyword vbDefine vbDataObject vbDate vbDecimal vbDefaultButton1
syn keyword vbDefine vbDefaultButton2 vbDefaultButton3 vbDefaultButton4
syn keyword vbDefine vbDesktop vbDirectory vbDouble vbEmpty vbError
syn keyword vbDefine vbExclamation vbFirstFourDays vbFirstFullWeek
syn keyword vbDefine vbFirstJan1 vbFormCode vbFormControlMenu
syn keyword vbDefine vbFormFeed vbFormMDIForm vbFriday vbFromUnicode
syn keyword vbDefine vbGrayText vbGreen vbHidden vbHide vbHighlight
syn keyword vbDefine vbHighlightText vbHiragana vbIgnore vbIMEAlphaDbl
syn keyword vbDefine vbIMEAlphaSng vbIMEDisable vbIMEHiragana
syn keyword vbDefine vbIMEKatakanaDbl vbIMEKatakanaSng vbIMEModeAlpha
syn keyword vbDefine vbIMEModeAlphaFull vbIMEModeDisable
syn keyword vbDefine vbIMEModeHangul vbIMEModeHangulFull
syn keyword vbDefine vbIMEModeHiragana vbIMEModeKatakana
syn keyword vbDefine vbIMEModeKatakanaHalf vbIMEModeNoControl
syn keyword vbDefine vbIMEModeOff vbIMEModeOn vbIMENoOp vbIMEOff
syn keyword vbDefine vbIMEOn vbInactiveBorder vbInactiveCaptionText
syn keyword vbDefine vbInactiveTitleBar vbInfoBackground vbInformation
syn keyword vbDefine vbInfoText vbInteger vbKatakana vbKey0 vbKey1
syn keyword vbDefine vbKey2 vbKey3 vbKey4 vbKey5 vbKey6 vbKey7 vbKey8
syn keyword vbDefine vbKey9 vbKeyA vbKeyAdd vbKeyB vbKeyBack vbKeyC
syn keyword vbDefine vbKeyCancel vbKeyCapital vbKeyClear vbKeyControl
syn keyword vbDefine vbKeyD vbKeyDecimal vbKeyDelete vbKeyDivide
syn keyword vbDefine vbKeyDown vbKeyE vbKeyEnd vbKeyEscape vbKeyExecute
syn keyword vbDefine vbKeyF vbKeyF1 vbKeyF10 vbKeyF11 vbKeyF12 vbKeyF13
syn keyword vbDefine vbKeyF14 vbKeyF15 vbKeyF16 vbKeyF2 vbKeyF3 vbKeyF4
syn keyword vbDefine vbKeyF5 vbKeyF6 vbKeyF7 vbKeyF8 vbKeyF9 vbKeyG
syn keyword vbDefine vbKeyH vbKeyHelp vbKeyHome vbKeyI vbKeyInsert
syn keyword vbDefine vbKeyJ vbKeyK vbKeyL vbKeyLButton vbKeyLeft vbKeyM
syn keyword vbDefine vbKeyMButton vbKeyMenu vbKeyMultiply vbKeyN
syn keyword vbDefine vbKeyNumlock vbKeyNumpad0 vbKeyNumpad1
syn keyword vbDefine vbKeyNumpad2 vbKeyNumpad3 vbKeyNumpad4
syn keyword vbDefine vbKeyNumpad5 vbKeyNumpad6 vbKeyNumpad7
syn keyword vbDefine vbKeyNumpad8 vbKeyNumpad9 vbKeyO vbKeyP
syn keyword vbDefine vbKeyPageDown vbKeyPageUp vbKeyPause vbKeyPrint
syn keyword vbDefine vbKeyQ vbKeyR vbKeyRButton vbKeyReturn vbKeyRight
syn keyword vbDefine vbKeyS vbKeySelect vbKeySeparator vbKeyShift
syn keyword vbDefine vbKeySnapshot vbKeySpace vbKeySubtract vbKeyT
syn keyword vbDefine vbKeyTab vbKeyU vbKeyUp vbKeyV vbKeyW vbKeyX
syn keyword vbDefine vbKeyY vbKeyZ vbLf vbLong vbLowerCase vbMagenta
syn keyword vbDefine vbMaximizedFocus vbMenuBar vbMenuText
syn keyword vbDefine vbMinimizedFocus vbMinimizedNoFocus vbMonday
syn keyword vbDefine vbMsgBox vbMsgBoxHelpButton vbMsgBoxRight
syn keyword vbDefine vbMsgBoxRtlReading vbMsgBoxSetForeground
syn keyword vbDefine vbMsgBoxText vbNarrow vbNewLine vbNo vbNormal
syn keyword vbDefine vbNormalFocus vbNormalNoFocus vbNull vbNullChar
syn keyword vbDefine vbNullString vbObject vbObjectError vbOK
syn keyword vbDefine vbOKCancel vbOKOnly vbProperCase vbQuestion
syn keyword vbDefine vbReadOnly vbRed vbRetry vbRetryCancel vbSaturday
syn keyword vbDefine vbScrollBars vbSingle vbString vbSunday vbSystem
syn keyword vbDefine vbSystemModal vbTab vbTextCompare vbThursday
syn keyword vbDefine vbTitleBarText vbTuesday vbUnicode vbUpperCase
syn keyword vbDefine vbUseSystem vbUseSystemDayOfWeek vbVariant
syn keyword vbDefine vbVerticalTab vbVolume vbWednesday vbWhite vbWide
syn keyword vbDefine vbWindowBackground vbWindowFrame vbWindowText
syn keyword vbDefine vbYellow vbYes vbYesNo vbYesNoCancel

"Numbers
"integer number, or floating point number without a dot.
syn match vbNumber "\<\d\+\>"
"floating point number, with dot
syn match vbNumber "\<\d\+\.\d*\>"
"floating point number, starting with a dot
syn match vbNumber "\.\d\+\>"
"syn match  vbNumber		"{[[:xdigit:]-]\+}\|&[hH][[:xdigit:]]\+&"
"syn match  vbNumber		":[[:xdigit:]]\+"
"syn match  vbNumber		"[-+]\=\<\d\+\>"
syn match  vbFloat		"[-+]\=\<\d\+[eE][\-+]\=\d\+"
syn match  vbFloat		"[-+]\=\<\d\+\.\d*\([eE][\-+]\=\d\+\)\="
syn match  vbFloat		"[-+]\=\<\.\d\+\([eE][\-+]\=\d\+\)\="

" String and Character contstants
syn region  vbString		start=+"+  end=+"\|$+
syn region  vbComment		start="\(^\|\s\)REM\s" end="$" contains=vbTodo
syn region  vbComment		start="\(^\|\s\)\'"   end="$" contains=vbTodo
syn match   vbLineNumber	"^\d\+\(\s\|$\)"
syn match   vbTypeSpecifier  "[a-zA-Z0-9][\$%&!#]"ms=s+1
syn match   vbTypeSpecifier  "#[a-zA-Z0-9]"me=e-1

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_vb_syntax_inits")
	if version < 508
		let did_vb_syntax_inits = 1
		command -nargs=+ HiLink hi link <args>
	else
		command -nargs=+ HiLink hi def link <args>
	endif

	HiLink vbBoolean		Boolean
	HiLink vbLineNumber		Comment
	HiLink vbComment		Comment
	HiLink vbConditional	Conditional
	HiLink vbConst			Constant
	HiLink vbDefine			Constant
	HiLink vbError			Error
	HiLink vbFunction		Identifier
	HiLink vbIdentifier		Identifier
	HiLink vbNumber			Number
	HiLink vbFloat			Float
	HiLink vbMethods		PreProc
	HiLink vbOperator		Operator
	HiLink vbRepeat			Repeat
	HiLink vbString			String
	HiLink vbStatement		Statement
	HiLink vbKeyword		Statement
	HiLink vbEvents			Special
	HiLink vbTodo			Todo
	HiLink vbTypes			Type
	HiLink vbTypeSpecifier	Type

	delcommand HiLink
endif

let b:current_syntax = "vb"

" vim: ts=8
