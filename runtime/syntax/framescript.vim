" Vim syntax file
" Language:         FrameScript v4.0
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2007-02-22

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn match   framescriptOperator
      \ '[+*/%=-]\|[><]=\=\|#[&|]'

syn keyword framescriptTodo
      \ contained
      \ TODO FIXME XXX NOTE

syn cluster framescriptCommentGroup
      \ contains=
      \   framescriptTodo,
      \   @Spell

syn match   framescriptComment
      \ display
      \ contains=@framescriptCommentGroup
      \ '//.*$'

syn region  framescriptComment
      \ contains=@framescriptCommentGroup
      \ matchgroup=framescriptCommentStart
      \ start='/\*'
      \ end='\*/'

syn case ignore

syn match   framescriptInclude
      \ display
      \ contains=framescriptIncluded
      \ "^\s*<#Include\>\s*'"

syn region  framescriptIncluded
      \ contained
      \ display
      \ start=+'+
      \ skip=+\\\\\|\\'+
      \ end=+'+

syn match   framescriptNumbers
      \ display
      \ transparent
      \ contains=
      \   framescriptInteger,
      \   framescriptReal,
      \   framescriptMetric,
      \   framescriptCharacter
      \ '\<\d\|\.\d'

syn keyword framescriptBoolean
      \ True False

syn match   framescriptInteger
      \ contained
      \ display
      \ '\d\+\>'

syn match   framescriptInteger
      \ contained
      \ display
      \ '\x\+H\>'

syn match   framescriptInteger
      \ contained
      \ display
      \ '[01]\+B\>'

syn match   framescriptReal
      \ contained
      \ display
      \ '\d\+\.\d*\|\.\d\+\>'

syn match   framescriptMetric
      \ contained
      \ display
      \ '\%(\d\+\%(\.\d*\)\=\|\.\d\+\)\%(pts\|in\|"\|cm\|mm\|pica\)\>'

syn match   framescriptCharacter
      \ contained
      \ display
      \ '\d\+S\>'

syn region  framescriptString
      \ contains=framescriptStringSpecialChar,@Spell
      \ start=+'+
      \ skip=+\\\\\|\\'+
      \ end=+'+

syn match   framescriptStringSpecialChar
      \ contained
      \ display
      \ "\\[\\']"

syn keyword framescriptConstant
      \ BackSlash
      \ CharCR
      \ CharLF
      \ CharTAB
      \ ClientDir
      \ ClientName
      \ FslVersionMajor
      \ FslVersionMinor
      \ InstallName
      \ InstalledScriptList
      \ MainScript
      \ NULL
      \ ObjEndOffset
      \ ProductRevision
      \ Quote
      \ ThisScript

syn keyword framescriptOperator
      \ not
      \ and
      \ or

syn keyword framescriptSessionVariables
      \ ErrorCode
      \ ErrorMsg
      \ DeclareVarMode
      \ PlatformEncodingMode

syn keyword framescriptStructure
      \ Event
      \ EndEvent

syn keyword framescriptStatement
      \ Sub
      \ EndSub
      \ Run
      \ Function
      \ EndFunction
      \ Set
      \ Add
      \ Apply
      \ CallClient
      \ Close
      \ Copy
      \ Cut
      \ DialogBox
      \ Delete
      \ Demote
      \ Display
      \ DocCompare
      \ Export
      \ Find
      \ LeaveLoop
      \ LeaveScript
      \ LeaveSub
      \ LoopNext
      \ Merge
      \ MsgBox
      \ Paste
      \ PopClipboard
      \ PushClipboard
      \ Read
      \ Replace
      \ Return
      \ Sort
      \ Split

syn keyword framescriptStatement
      \ nextgroup=framescriptApplySubStatement skipwhite skipempty
      \ Apply

syn keyword framescriptApplySubStatement
      \ contained
      \ Pagelayout
      \ TextProperties

syn keyword framescriptStatement
      \ nextgroup=framescriptClearSubStatement skipwhite skipempty
      \ Clear

syn keyword framescriptClearSubStatement
      \ contained
      \ ChangeBars
      \ Text

syn keyword framescriptStatement
      \ nextgroup=framescriptCloseSubStatement skipwhite skipempty
      \ Close

syn keyword framescriptCloseSubStatement
      \ contained
      \ Book
      \ Document
      \ TextFile

syn keyword framescriptStatement
      \ nextgroup=framescriptExecSubStatement skipwhite skipempty
      \ Exec

syn keyword framescriptExecSubStatement
      \ contained
      \ Compile
      \ Script
      \ Wait

syn keyword framescriptStatement
      \ nextgroup=framescriptExecuteSubStatement skipwhite skipempty
      \ Execute

syn keyword framescriptExecuteSubStatement
      \ contained
      \ FrameCommand
      \ Hypertext
      \ StartUndoCheckPoint
      \ EndUndoCheckPoint
      \ ClearUndoHistory

syn keyword framescriptStatement
      \ nextgroup=framescriptGenerateSubStatement skipwhite skipempty
      \ Generate

syn keyword framescriptGenerateSubStatement
      \ contained
      \ Bookfile

syn keyword framescriptStatement
      \ nextgroup=framescriptGetSubStatement skipwhite skipempty
      \ Get

syn keyword framescriptGetSubStatement
      \ contained
      \ Member
      \ Object
      \ String
      \ TextList
      \ TextProperties

syn keyword framescriptStatement
      \ nextgroup=framescriptImportSubStatement skipwhite skipempty
      \ Import

syn keyword framescriptImportSubStatement
      \ contained
      \ File
      \ Formats
      \ ElementDefs

syn keyword framescriptStatement
      \ nextgroup=framescriptInstallSubStatement skipwhite skipempty
      \ Install
      \ Uninstall

syn keyword framescriptInstallSubStatement
      \ contained
      \ ChangeBars
      \ Text

syn keyword framescriptStatement
      \ nextgroup=framescriptNewSubStatement skipwhite skipempty
      \ New

syn keyword framescriptNewSubStatement
      \ contained
      \ AFrame
      \ Footnote
      \ Marker
      \ TiApiClient
      \ Variable
      \ XRef
      \ FormatChangeList
      \ FormatRule
      \ FmtRuleClause
      \ Arc
      \ Ellipse
      \ Flow
      \ Group
      \ Inset
      \ Line
      \ Math
      \ Polygon
      \ Polyline
      \ Rectangle
      \ RoundRect
      \ TextFrame
      \ Textline
      \ UnanchoredFrame
      \ Command
      \ Menu
      \ MenuItemSeparator
      \ Book
      \ CharacterFormat
      \ Color
      \ ConditionFormat
      \ ElementDef
      \ FormatChangeList
      \ MarkerType
      \ MasterPage
      \ ParagraphFormat
      \ PgfFmt
      \ ReferencePAge
      \ RulingFormat
      \ TableFormat
      \ VariableFormat
      \ XRefFormat
      \ BodyPage
      \ BookComponent
      \ Paragraph
      \ Element
      \ Attribute
      \ AttributeDef
      \ AttributeList
      \ AttributeDefList
      \ ElementLoc
      \ ElementRange
      \ Table
      \ TableRows
      \ TableCols
      \ Text
      \ Integer
      \ Real
      \ Metric
      \ String
      \ Object
      \ TextLoc
      \ TextRange
      \ IntList
      \ UIntList
      \ MetricList
      \ StringList
      \ PointList
      \ TabList
      \ PropertyList
      \ LibVar
      \ ScriptVar
      \ SubVar
      \ TextFile

syn keyword framescriptStatement
      \ nextgroup=framescriptOpenSubStatement skipwhite skipempty
      \ Open

syn keyword framescriptOpenSubStatement
      \ contained
      \ Document
      \ Book
      \ TextFile

syn keyword framescriptStatement
      \ nextgroup=framescriptPrintSubStatement skipwhite skipempty
      \ Print

syn keyword framescriptPrintSubStatement
      \ contained
      \ Document
      \ Book

syn keyword framescriptStatement
      \ nextgroup=framescriptQuitSubStatement skipwhite skipempty
      \ Quit

syn keyword framescriptQuitSubStatement
      \ contained
      \ Session

syn keyword framescriptStatement
      \ nextgroup=framescriptRemoveSubStatement skipwhite skipempty
      \ Remove

syn keyword framescriptRemoveSubStatement
      \ contained
      \ Attribute
      \ CommandObject

syn keyword framescriptStatement
      \ nextgroup=framescriptSaveSubStatement skipwhite skipempty
      \ Save

syn keyword framescriptSaveSubStatement
      \ contained
      \ Document
      \ Book

syn keyword framescriptStatement
      \ nextgroup=framescriptSelectSubStatement skipwhite skipempty
      \ Select

syn keyword framescriptSelectSubStatement
      \ contained
      \ TableCells

syn keyword framescriptStatement
      \ nextgroup=framescriptStraddleSubStatement skipwhite skipempty
      \ Straddle

syn keyword framescriptStraddleSubStatement
      \ contained
      \ TableCells

syn keyword framescriptStatement
      \ nextgroup=framescriptUpdateSubStatement skipwhite skipempty
      \ Update

syn keyword framescriptUpdateSubStatement
      \ contained
      \ ReDisplay
      \ Formatting
      \ Hyphenating
      \ ResetEquationsSettings
      \ ResetRefFrames
      \ RestartPgfNums
      \ TextInset
      \ Variables
      \ XRefs
      \ Book

syn keyword framescriptStatement
      \ nextgroup=framescriptWriteSubStatement skipwhite skipempty
      \ Write

syn keyword framescriptUpdateSubStatement
      \ contained
      \ Console
      \ Display

syn keyword framescriptRepeat
      \ Loop
      \ EndLoop

syn keyword framescriptConditional
      \ If
      \ ElseIf
      \ Else
      \ EndIf

syn keyword framescriptType
      \ Local
      \ GlobalVar

let b:framescript_minlines = exists("framescript_minlines")
                         \ ? framescript_minlines : 15
exec "syn sync ccomment framescriptComment minlines=" . b:framescript_minlines

hi def link framescriptTodo                 Todo
hi def link framescriptComment              Comment
hi def link framescriptCommentStart         framescriptComment
hi def link framescriptInclude              Include
hi def link framescriptIncluded             String
hi def link framescriptBoolean              Boolean
hi def link framescriptNumber               Number
hi def link framescriptInteger              framescriptNumber
hi def link framescriptReal                 framescriptNumber
hi def link framescriptMetric               framescriptNumber
hi def link framescriptCharacter            framescriptNumber
hi def link framescriptString               String
hi def link framescriptStringSpecialChar    SpecialChar
hi def link framescriptConstant             Constant
hi def link framescriptOperator             None
hi def link framescriptSessionVariables     PreProc
hi def link framescriptStructure            Structure
hi def link framescriptStatement            Statement
hi def link framescriptSubStatement         Type
hi def link framescriptApplySubStatement    framescriptSubStatement
hi def link framescriptClearSubStatement    framescriptSubStatement
hi def link framescriptCloseSubStatement    framescriptSubStatement
hi def link framescriptExecSubStatement     framescriptSubStatement
hi def link framescriptExecuteSubStatement  framescriptSubStatement
hi def link framescriptGenerateSubStatement framescriptSubStatement
hi def link framescriptGetSubStatement      framescriptSubStatement
hi def link framescriptImportSubStatement   framescriptSubStatement
hi def link framescriptInstallSubStatement  framescriptSubStatement
hi def link framescriptNewSubStatement      framescriptSubStatement
hi def link framescriptOpenSubStatement     framescriptSubStatement
hi def link framescriptPrintSubStatement    framescriptSubStatement
hi def link framescriptQuitSubStatement     framescriptSubStatement
hi def link framescriptRemoveSubStatement   framescriptSubStatement
hi def link framescriptSaveSubStatement     framescriptSubStatement
hi def link framescriptSelectSubStatement   framescriptSubStatement
hi def link framescriptStraddleSubStatement framescriptSubStatement
hi def link framescriptUpdateSubStatement   framescriptSubStatement
hi def link framescriptRepeat               Repeat
hi def link framescriptConditional          Conditional
hi def link framescriptType                 Type

let b:current_syntax = "framescript"

let &cpo = s:cpo_save
unlet s:cpo_save
