" Vim syntax file
" Language:         AutoHotkey script file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2008-06-22

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn case ignore

syn keyword autohotkeyTodo
      \ contained
      \ TODO FIXME XXX NOTE

syn cluster autohotkeyCommentGroup
      \ contains=
      \   autohotkeyTodo,
      \   @Spell

syn match   autohotkeyComment
      \ display
      \ contains=@autohotkeyCommentGroup
      \ '`\@<!;.*$'

syn region  autohotkeyComment
      \ contains=@autohotkeyCommentGroup
      \ matchgroup=autohotkeyCommentStart
      \ start='/\*'
      \ end='\*/'

syn match   autohotkeyEscape
      \ display
      \ '`.'

syn match   autohotkeyHotkey
      \ contains=autohotkeyKey,
      \   autohotkeyHotkeyDelimiter
      \ display
      \ '^.\{-}::'

syn match   autohotkeyKey
      \ contained
      \ display
      \ '^.\{-}'

syn match   autohotkeyDelimiter
      \ contained
      \ display
      \ '::'

syn match   autohotkeyHotstringDefinition
      \ contains=autohotkeyHotstring,
      \   autohotkeyHotstringDelimiter
      \ display
      \ '^:\%(B0\|C1\|K\d\+\|P\d\+\|S[IPE]\|Z\d\=\|[*?COR]\)*:.\{-}::'

syn match   autohotkeyHotstring
      \ contained
      \ display
      \ '.\{-}'

syn match   autohotkeyHotstringDelimiter
      \ contained
      \ display
      \ '::'

syn match   autohotkeyHotstringDelimiter
      \ contains=autohotkeyHotstringOptions
      \ contained
      \ display
      \ ':\%(B0\|C1\|K\d\+\|P\d\+\|S[IPE]\|Z\d\=\|[*?COR]\):'

syn match   autohotkeyHotstringOptions
      \ contained
      \ display
      \ '\%(B0\|C1\|K\d\+\|P\d\+\|S[IPE]\|Z\d\=\|[*?COR]\)'

syn region autohotkeyString
      \ display
      \ oneline
      \ matchgroup=autohotkeyStringDelimiter
      \ start=+"+
      \ end=+"+
      \ contains=autohotkeyEscape

syn region autohotkeyVariable
      \ display
      \ oneline
      \ contains=autohotkeyBuiltinVariable
      \ matchgroup=autohotkeyVariableDelimiter
      \ start="%"
      \ end="%"
      \ keepend

syn keyword autohotkeyBuiltinVariable
      \ A_Space A_Tab
      \ A_WorkingDir A_ScriptDir A_ScriptName A_ScriptFullPath A_LineNumber
      \ A_LineFile A_AhkVersion A_AhkPAth A_IsCompiled A_ExitReason
      \ A_YYYY A_MM A_DD A_MMMM A_MMM A_DDDD A_DDD A_WDay A_YWeek A_Hour A_Min
      \ A_Sec A_MSec A_Now A_NowUTC A_TickCount
      \ A_IsSuspended A_BatchLines A_TitleMatchMode A_TitleMatchModeSpeed
      \ A_DetectHiddenWindows A_DetectHiddenText A_AutoTrim A_STringCaseSense
      \ A_FormatInteger A_FormatFloat A_KeyDelay A_WinDelay A_ControlDelay
      \ A_MouseDelay A_DefaultMouseSpeed A_IconHidden A_IconTip A_IconFile
      \ A_IconNumber
      \ A_TimeIdle A_TimeIdlePhysical
      \ A_Gui A_GuiControl A_GuiWidth A_GuiHeight A_GuiX A_GuiY A_GuiEvent
      \ A_GuiControlEvent A_EventInfo
      \ A_ThisMenuItem A_ThisMenu A_ThisMenuItemPos A_ThisHotkey A_PriorHotkey
      \ A_TimeSinceThisHotkey A_TimeSincePriorHotkey A_EndChar
      \ ComSpec A_Temp A_OSType A_OSVersion A_Language A_ComputerName A_UserName
      \ A_WinDir A_ProgramFiles ProgramFiles A_AppData A_AppDataCommon A_Desktop
      \ A_DesktopCommon A_StartMenu A_StartMenuCommon A_Programs
      \ A_ProgramsCommon A_Startup A_StartupCommon A_MyDocuments A_IsAdmin
      \ A_ScreenWidth A_ScreenHeight A_IPAddress1 A_IPAddress2 A_IPAddress3
      \ A_IPAddress4
      \ A_Cursor A_CaretX A_CaretY Clipboard ClipboardAll ErrorLevel A_LastError
      \ A_Index A_LoopFileName A_LoopRegName A_LoopReadLine A_LoopField

syn match   autohotkeyBuiltinVariable
      \ contained
      \ display
      \ '%\d\+%'

syn keyword autohotkeyCommand
      \ ClipWait EnvGet EnvSet EnvUpdate
      \ Drive DriveGet DriveSpaceFree FileAppend FileCopy FileCopyDir
      \ FileCreateDir FileCreateShortcut FileDelete FileGetAttrib
      \ FileGetShortcut FileGetSize FileGetTime FileGetVersion FileInstall
      \ FileMove FileMoveDir FileReadLine FileRead FileRecycle FileRecycleEmpty
      \ FileRemoveDir FileSelectFolder FileSelectFile FileSetAttrib FileSetTime
      \ IniDelete IniRead IniWrite SetWorkingDir
      \ SplitPath
      \ Gui GuiControl GuiControlGet IfMsgBox InputBox MsgBox Progress
      \ SplashImage SplashTextOn SplashTextOff ToolTip TrayTip
      \ Hotkey ListHotkeys BlockInput ControlSend ControlSendRaw GetKeyState
      \ KeyHistory KeyWait Input Send SendRaw SendInput SendPlay SendEvent
      \ SendMode SetKeyDelay SetNumScrollCapsLockState SetStoreCapslockMode
      \ EnvAdd EnvDiv EnvMult EnvSub Random SetFormat Transform
      \ AutoTrim BlockInput CoordMode Critical Edit ImageSearch
      \ ListLines ListVars Menu OutputDebug PixelGetColor PixelSearch
      \ SetBatchLines SetEnv SetTimer SysGet Thread Transform URLDownloadToFile
      \ Click ControlClick MouseClick MouseClickDrag MouseGetPos MouseMove
      \ SetDefaultMouseSpeed SetMouseDelay
      \ Process Run RunWait RunAs Shutdown Sleep
      \ RegDelete RegRead RegWrite
      \ SoundBeep SoundGet SoundGetWaveVolume SoundPlay SoundSet
      \ SoundSetWaveVolume
      \ FormatTime IfInString IfNotInString Sort StringCaseSense StringGetPos
      \ StringLeft StringRight StringLower StringUpper StringMid StringReplace
      \ StringSplit StringTrimLeft StringTrimRight
      \ Control ControlClick ControlFocus ControlGet ControlGetFocus
      \ ControlGetPos ControlGetText ControlMove ControlSend ControlSendRaw
      \ ControlSetText Menu PostMessage SendMessage SetControlDelay
      \ WinMenuSelectItem GroupActivate GroupAdd GroupClose GroupDeactivate
      \ DetectHiddenText DetectHiddenWindows SetTitleMatchMode SetWinDelay
      \ StatusBarGetText StatusBarWait WinActivate WinActivateBottom WinClose
      \ WinGet WinGetActiveStats WinGetActiveTitle WinGetClass WinGetPos
      \ WinGetText WinGetTitle WinHide WinKill WinMaximize WinMinimize
      \ WinMinimizeAll WinMinimizeAllUndo WinMove WinRestore WinSet
      \ WinSetTitle WinShow WinWait WinWaitActive WinWaitNotActive WinWaitClose

syn keyword autohotkeyFunction
      \ InStr RegExMatch RegExReplace StrLen SubStr Asc Chr
      \ DllCall VarSetCapacity WinActive WinExist IsLabel OnMessage 
      \ Abs Ceil Exp Floor Log Ln Mod Round Sqrt Sin Cos Tan ASin ACos ATan
      \ FileExist GetKeyState

syn keyword autohotkeyStatement
      \ Break Continue Exit ExitApp Gosub Goto OnExit Pause Return
      \ Suspend Reload

syn keyword autohotkeyRepeat
      \ Loop

syn keyword autohotkeyConditional
      \ IfExist IfNotExist If IfEqual IfLess IfGreater Else

syn match   autohotkeyPreProcStart
      \ nextgroup=
      \   autohotkeyInclude,
      \   autohotkeyPreProc
      \ skipwhite
      \ display
      \ '^\s*\zs#'

syn keyword autohotkeyInclude
      \ contained
      \ Include
      \ IncludeAgain

syn keyword autohotkeyPreProc
      \ contained
      \ HotkeyInterval HotKeyModifierTimeout
      \ Hotstring
      \ IfWinActive IfWinNotActive IfWinExist IfWinNotExist
      \ MaxHotkeysPerInterval MaxThreads MaxThreadsBuffer MaxThreadsPerHotkey
      \ UseHook InstallKeybdHook InstallMouseHook
      \ KeyHistory
      \ NoTrayIcon SingleInstance
      \ WinActivateForce
      \ AllowSameLineComments
      \ ClipboardTimeout
      \ CommentFlag
      \ ErrorStdOut
      \ EscapeChar
      \ MaxMem
      \ NoEnv
      \ Persistent

syn keyword autohotkeyMatchClass
      \ ahk_group ahk_class ahk_id ahk_pid

syn match   autohotkeyNumbers
      \ display
      \ transparent
      \ contains=
      \   autohotkeyInteger,
      \   autohotkeyFloat
      \ '\<\d\|\.\d'

syn match   autohotkeyInteger
      \ contained
      \ display
      \ '\d\+\>'

syn match   autohotkeyInteger
      \ contained
      \ display
      \ '0x\x\+\>'

syn match   autohotkeyFloat
      \ contained
      \ display
      \ '\d\+\.\d*\|\.\d\+\>'

syn keyword autohotkeyType
      \ local
      \ global

syn keyword autohotkeyBoolean
      \ true
      \ false

" TODO: Shouldn't we look for g:, b:,  variables before defaulting to
" something?
if exists("g:autohotkey_syntax_sync_minlines")
  let b:autohotkey_syntax_sync_minlines = g:autohotkey_syntax_sync_minlines
else
  let b:autohotkey_syntax_sync_minlines = 50
endif
exec "syn sync ccomment autohotkeyComment minlines=" . b:autohotkey_syntax_sync_minlines

hi def link autohotkeyTodo                Todo
hi def link autohotkeyComment             Comment
hi def link autohotkeyCommentStart        autohotkeyComment
hi def link autohotkeyEscape              Special
hi def link autohotkeyHotkey              Type
hi def link autohotkeyKey                 Type
hi def link autohotkeyDelimiter           Delimiter
hi def link autohotkeyHotstringDefinition Type
hi def link autohotkeyHotstring           Type
hi def link autohotkeyHotstringDelimiter  autohotkeyDelimiter
hi def link autohotkeyHotstringOptions    Special
hi def link autohotkeyString              String
hi def link autohotkeyStringDelimiter     autohotkeyString
hi def link autohotkeyVariable            Identifier
hi def link autohotkeyVariableDelimiter   autohotkeyVariable
hi def link autohotkeyBuiltinVariable     Macro
hi def link autohotkeyCommand             Keyword
hi def link autohotkeyFunction            Function
hi def link autohotkeyStatement           autohotkeyCommand
hi def link autohotkeyRepeat              Repeat
hi def link autohotkeyConditional         Conditional
hi def link autohotkeyPreProcStart        PreProc
hi def link autohotkeyInclude             Include
hi def link autohotkeyPreProc             PreProc
hi def link autohotkeyMatchClass          Typedef
hi def link autohotkeyNumber              Number
hi def link autohotkeyInteger             autohotkeyNumber
hi def link autohotkeyFloat               autohotkeyNumber
hi def link autohotkeyType                Type
hi def link autohotkeyBoolean             Boolean

let b:current_syntax = "autohotkey"

let &cpo = s:cpo_save
unlet s:cpo_save
