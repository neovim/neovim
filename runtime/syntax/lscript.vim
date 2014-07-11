" Vim syntax file
" Language:	LotusScript
" Maintainer:	Taryn East (taryneast@hotmail.com)
" Last Change:	2003 May 11

" This is a rough  amalgamation of the visual basic syntax file, and the UltraEdit
" and Textpad syntax highlighters.
" It's not too brilliant given that a) I've never written a syntax.vim file before
" and b) I'm not so crash hot at LotusScript either. If you see any problems
" feel free to email me with them.

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" LotusScript is case insensitive
syn case ignore

" These are Notes thingies that had an equivalent in the vb highlighter
" or I was already familiar with them
syn keyword lscriptStatement ActivateApp As And Base Beep Call Case ChDir ChDrive Class
syn keyword lscriptStatement Const Dim Declare DefCur DefDbl DefInt DefLng DefSng DefStr
syn keyword lscriptStatement DefVar Do Else %Else ElseIf %ElseIf End %End Erase Event Exit
syn keyword lscriptStatement Explicit FileCopy FALSE For ForAll Function Get GoTo GoSub
syn keyword lscriptStatement If %If In Is Kill Let List Lock Loop MkDir
syn keyword lscriptStatement Name Next New NoCase NoPitch Not Nothing NULL
syn keyword lscriptStatement On Option Or PI Pitch Preserve Private Public
syn keyword lscriptStatement Property Public Put
syn keyword lscriptStatement Randomize ReDim Reset Resume Return RmDir
syn keyword lscriptStatement Select SendKeys SetFileAttr Set Static Sub Then To TRUE
syn keyword lscriptStatement Type Unlock Until While WEnd With Write XOr

syn keyword lscriptDatatype Array Currency Double Integer Long Single String String$ Variant

syn keyword lscriptNotesType Field Button Navigator
syn keyword lscriptNotesType NotesACL NotesACLEntry NotesAgent NotesDatabase NotesDateRange
syn keyword lscriptNotesType NotesDateTime NotesDbDirectory NotesDocument
syn keyword lscriptNotesType NotesDocumentCollection NotesEmbeddedObject NotesForm
syn keyword lscriptNotesType NotesInternational NotesItem NotesLog NotesName NotesNewsLetter
syn keyword lscriptNotesType NotesMIMEEntry NotesOutline NotesOutlineEntry NotesRegistration
syn keyword lscriptNotesType NotesReplication NotesRichTextItem NotesRichTextParagraphStyle
syn keyword lscriptNotesType NotesRichTextStyle NotesRichTextTab
syn keyword lscriptNotesType NotesSession NotesTimer NotesView NotesViewColumn NotesViewEntry
syn keyword lscriptNotesType NotesViewEntryCollection NotesViewNavigator NotesUIDatabase
syn keyword lscriptNotesType NotesUIDocument NotesUIView NotesUIWorkspace

syn keyword lscriptNotesConst ACLLEVEL_AUTHOR ACLLEVEL_DEPOSITOR ACLLEVEL_DESIGNER
syn keyword lscriptNotesConst ACLLEVEL_EDITOR ACLLEVEL_MANAGER ACLLEVEL_NOACCESS
syn keyword lscriptNotesConst ACLLEVEL_READER ACLTYPE_MIXED_GROUP ACLTYPE_PERSON
syn keyword lscriptNotesConst ACLTYPE_PERSON_GROUP ACLTYPE_SERVER ACLTYPE_SERVER_GROUP
syn keyword lscriptNotesConst ACLTYPE_UNSPECIFIED ACTIONCD ALIGN_CENTER
syn keyword lscriptNotesConst ALIGN_FULL ALIGN_LEFT ALIGN_NOWRAP ALIGN_RIGHT
syn keyword lscriptNotesConst ASSISTANTINFO ATTACHMENT AUTHORS COLOR_BLACK
syn keyword lscriptNotesConst COLOR_BLUE COLOR_CYAN COLOR_DARK_BLUE COLOR_DARK_CYAN
syn keyword lscriptNotesConst COLOR_DARK_GREEN COLOR_DARK_MAGENTA COLOR_DARK_RED
syn keyword lscriptNotesConst COLOR_DARK_YELLOW COLOR_GRAY COLOR_GREEN COLOR_LIGHT_GRAY
syn keyword lscriptNotesConst COLOR_MAGENTA COLOR_RED COLOR_WHITE COLOR_YELLOW
syn keyword lscriptNotesConst DATABASE DATETIMES DB_REPLICATION_PRIORITY_HIGH
syn keyword lscriptNotesConst DB_REPLICATION_PRIORITY_LOW DB_REPLICATION_PRIORITY_MED
syn keyword lscriptNotesConst DB_REPLICATION_PRIORITY_NOTSET EFFECTS_EMBOSS
syn keyword lscriptNotesConst EFFECTS_EXTRUDE EFFECTS_NONE EFFECTS_SHADOW
syn keyword lscriptNotesConst EFFECTS_SUBSCRIPT EFFECTS_SUPERSCRIPT EMBED_ATTACHMENT
syn keyword lscriptNotesConst EMBED_OBJECT EMBED_OBJECTLINK EMBEDDEDOBJECT ERRORITEM
syn keyword lscriptNotesConst EV_ALARM EV_COMM EV_MAIL EV_MISC EV_REPLICA EV_RESOURCE
syn keyword lscriptNotesConst EV_SECURITY EV_SERVER EV_UNKNOWN EV_UPDATE FONT_COURIER
syn keyword lscriptNotesConst FONT_HELV FONT_ROMAN FORMULA FT_DATABASE FT_DATE_ASC
syn keyword lscriptNotesConst FT_DATE_DES FT_FILESYSTEM FT_FUZZY FT_SCORES FT_STEMS
syn keyword lscriptNotesConst FT_THESAURUS HTML ICON ID_CERTIFIER ID_FLAT
syn keyword lscriptNotesConst ID_HIERARCHICAL LSOBJECT MIME_PART NAMES NOTESLINKS
syn keyword lscriptNotesConst NOTEREFS NOTES_DESKTOP_CLIENT NOTES_FULL_CLIENT
syn keyword lscriptNotesConst NOTES_LIMITED_CLIENT NUMBERS OTHEROBJECT
syn keyword lscriptNotesConst OUTLINE_CLASS_DATABASE OUTLINE_CLASS_DOCUMENT
syn keyword lscriptNotesConst OUTLINE_CLASS_FOLDER OUTLINE_CLASS_FORM
syn keyword lscriptNotesConst OUTLINE_CLASS_FRAMESET OUTLINE_CLASS_NAVIGATOR
syn keyword lscriptNotesConst OUTLINE_CLASS_PAGE OUTLINE_CLASS_UNKNOWN
syn keyword lscriptNotesConst OUTLINE_CLASS_VIEW OUTLINE_OTHER_FOLDERS_TYPE
syn keyword lscriptNotesConst OUTLINE_OTHER_UNKNOWN_TYPE OUTLINE_OTHER_VIEWS_TYPE
syn keyword lscriptNotesConst OUTLINE_TYPE_ACTION OUTLINE_TYPE_NAMEDELEMENT
syn keyword lscriptNotesConst OUTLINE_TYPE_NOTELINK OUTLINE_TYPE_URL PAGINATE_BEFORE
syn keyword lscriptNotesConst PAGINATE_DEFAULT PAGINATE_KEEP_TOGETHER
syn keyword lscriptNotesConst PAGINATE_KEEP_WITH_NEXT PICKLIST_CUSTOM PICKLIST_NAMES
syn keyword lscriptNotesConst PICKLIST_RESOURCES PICKLIST_ROOMS PROMPT_OK PROMPT_OKCANCELCOMBO
syn keyword lscriptNotesConst PROMPT_OKCANCELEDIT PROMPT_OKCANCELEDITCOMBO PROMPT_OKCANCELLIST
syn keyword lscriptNotesConst PROMPT_OKCANCELLISTMULT PROMPT_PASSWORD PROMPT_YESNO
syn keyword lscriptNotesConst PROMPT_YESNOCANCEL QUERYCD READERS REPLICA_CANDIDATE
syn keyword lscriptNotesConst RICHTEXT RULER_ONE_CENTIMETER RULER_ONE_INCH SEV_FAILURE
syn keyword lscriptNotesConst SEV_FATAL SEV_NORMAL SEV_WARNING1 SEV_WARNING2
syn keyword lscriptNotesConst SIGNATURE SPACING_DOUBLE SPACING_ONE_POINT_50
syn keyword lscriptNotesConst SPACING_SINGLE STYLE_NO_CHANGE TAB_CENTER TAB_DECIMAL
syn keyword lscriptNotesConst TAB_LEFT TAB_RIGHT TARGET_ALL_DOCS TARGET_ALL_DOCS_IN_VIEW
syn keyword lscriptNotesConst TARGET_NEW_DOCS TARGET_NEW_OR_MODIFIED_DOCS TARGET_NONE
syn keyword lscriptNotesConst TARGET_RUN_ONCE TARGET_SELECTED_DOCS TARGET_UNREAD_DOCS_IN_VIEW
syn keyword lscriptNotesConst TEMPLATE TEMPLATE_CANDIDATE TEXT TRIGGER_AFTER_MAIL_DELIVERY
syn keyword lscriptNotesConst TRIGGER_BEFORE_MAIL_DELIVERY TRIGGER_DOC_PASTED
syn keyword lscriptNotesConst TRIGGER_DOC_UPDATE TRIGGER_MANUAL TRIGGER_NONE
syn keyword lscriptNotesConst TRIGGER_SCHEDULED UNAVAILABLE UNKNOWN USERDATA
syn keyword lscriptNotesConst USERID VC_ALIGN_CENTER VC_ALIGN_LEFT VC_ALIGN_RIGHT
syn keyword lscriptNotesConst VC_ATTR_PARENS VC_ATTR_PUNCTUATED VC_ATTR_PERCENT
syn keyword lscriptNotesConst VC_FMT_ALWAYS VC_FMT_CURRENCY VC_FMT_DATE VC_FMT_DATETIME
syn keyword lscriptNotesConst VC_FMT_FIXED VC_FMT_GENERAL VC_FMT_HM VC_FMT_HMS
syn keyword lscriptNotesConst VC_FMT_MD VC_FMT_NEVER VC_FMT_SCIENTIFIC
syn keyword lscriptNotesConst VC_FMT_SOMETIMES VC_FMT_TIME VC_FMT_TODAYTIME VC_FMT_YM
syn keyword lscriptNotesConst VC_FMT_YMD VC_FMT_Y4M VC_FONT_BOLD VC_FONT_ITALIC
syn keyword lscriptNotesConst VC_FONT_STRIKEOUT VC_FONT_UNDERLINE VC_SEP_COMMA
syn keyword lscriptNotesConst VC_SEP_NEWLINE VC_SEP_SEMICOLON VC_SEP_SPACE
syn keyword lscriptNotesConst VIEWMAPDATA VIEWMAPLAYOUT VW_SPACING_DOUBLE
syn keyword lscriptNotesConst VW_SPACING_ONE_POINT_25 VW_SPACING_ONE_POINT_50
syn keyword lscriptNotesConst VW_SPACING_ONE_POINT_75 VW_SPACING_SINGLE

syn keyword lscriptFunction Abs Asc Atn Atn2 ACos ASin
syn keyword lscriptFunction CCur CDat CDbl Chr Chr$ CInt CLng Command Command$
syn keyword lscriptFunction Cos CSng CStr
syn keyword lscriptFunction CurDir CurDir$ CVar Date Date$ DateNumber DateSerial DateValue
syn keyword lscriptFunction Day Dir Dir$ Environ$ Environ EOF Error Error$ Evaluate Exp
syn keyword lscriptFunction FileAttr FileDateTime FileLen Fix Format Format$ FreeFile
syn keyword lscriptFunction GetFileAttr GetThreadInfo Hex Hex$ Hour
syn keyword lscriptFunction IMESetMode IMEStatus Input Input$ InputB InputB$
syn keyword lscriptFunction InputBP InputBP$ InputBox InputBox$ InStr InStrB InStrBP InstrC
syn keyword lscriptFunction IsA IsArray IsDate IsElement IsList IsNumeric
syn keyword lscriptFunction IsObject IsResponse IsScalar IsUnknown LCase LCase$
syn keyword lscriptFunction Left Left$ LeftB LeftB$ LeftC
syn keyword lscriptFunction LeftBP LeftBP$ Len LenB LenBP LenC Loc LOF Log
syn keyword lscriptFunction LSet LTrim LTrim$ MessageBox Mid Mid$ MidB MidB$ MidC
syn keyword lscriptFunction Minute Month Now Oct Oct$ Responses Right Right$
syn keyword lscriptFunction RightB RightB$ RightBP RightBP$ RightC Round Rnd RSet RTrim RTrim$
syn keyword lscriptFunction Second Seek Sgn Shell Sin Sleep Space Space$ Spc Sqr Str Str$
syn keyword lscriptFunction StrConv StrLeft StrleftBack StrRight StrRightBack
syn keyword lscriptFunction StrCompare Tab Tan Time Time$ TimeNumber Timer
syn keyword lscriptFunction TimeValue Trim Trim$ Today TypeName UCase UCase$
syn keyword lscriptFunction UniversalID Val Weekday Year

syn keyword lscriptMethods AppendToTextList ArrayAppend ArrayReplace ArrayGetIndex
syn keyword lscriptMethods Append Bind Close
"syn keyword lscriptMethods Contains
syn keyword lscriptMethods CopyToDatabase CopyAllItems Count CurrentDatabase Delete Execute
syn keyword lscriptMethods GetAllDocumentsByKey GetDatabase GetDocumentByKey
syn keyword lscriptMethods GetDocumentByUNID GetFirstDocument GetFirstItem
syn keyword lscriptMethods GetItems GetItemValue GetNthDocument GetView
syn keyword lscriptMethods IsEmpty IsNull %Include Items
syn keyword lscriptMethods Line LBound LoadMsgText Open Print
syn keyword lscriptMethods RaiseEvent ReplaceItemValue Remove RemoveItem Responses
syn keyword lscriptMethods Save Stop UBound UnprocessedDocuments Write

syn keyword lscriptEvents Compare OnError

"*************************************************************************************
"These are Notes thingies that I'm not sure how to classify as they had no vb equivalent
" At a wild guess I'd put them as Functions...
" if anyone sees something really out of place... tell me!

syn keyword lscriptFunction Access Alias Any Bin Bin$ Binary ByVal
syn keyword lscriptFunction CodeLock CodeLockCheck CodeUnlock CreateLock
syn keyword lscriptFunction CurDrive CurDrive$ DataType DestroyLock Eqv
syn keyword lscriptFunction Erl Err Fraction From FromFunction FullTrim
syn keyword lscriptFunction Imp Int Lib Like ListTag LMBCS LSServer Me
syn keyword lscriptFunction Mod MsgDescription MsgText Output Published
syn keyword lscriptFunction Random Read Shared Step UChr UChr$ Uni Unicode
syn keyword lscriptFunction Until Use UseLSX UString UString$ Width Yield


syn keyword lscriptTodo contained	TODO

"integer number, or floating point number without a dot.
syn match  lscriptNumber		"\<\d\+\>"
"floating point number, with dot
syn match  lscriptNumber		"\<\d\+\.\d*\>"
"floating point number, starting with a dot
syn match  lscriptNumber		"\.\d\+\>"

" String and Character constants
syn region  lscriptString		start=+"+  end=+"+
syn region  lscriptComment		start="REM" end="$" contains=lscriptTodo
syn region  lscriptComment		start="'"   end="$" contains=lscriptTodo
syn region  lscriptLineNumber	start="^\d" end="\s"
syn match   lscriptTypeSpecifier	"[a-zA-Z0-9][\$%&!#]"ms=s+1

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_lscript_syntax_inits")
  if version < 508
    let did_lscript_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  hi lscriptNotesType	term=underline ctermfg=DarkGreen guifg=SeaGreen gui=bold

  HiLink lscriptNotesConst	lscriptNotesType
  HiLink lscriptLineNumber	Comment
  HiLink lscriptDatatype	Type
  HiLink lscriptNumber		Number
  HiLink lscriptError		Error
  HiLink lscriptStatement	Statement
  HiLink lscriptString		String
  HiLink lscriptComment		Comment
  HiLink lscriptTodo		Todo
  HiLink lscriptFunction	Identifier
  HiLink lscriptMethods		PreProc
  HiLink lscriptEvents		Special
  HiLink lscriptTypeSpecifier	Type

  delcommand HiLink
endif

let b:current_syntax = "lscript"

" vim: ts=8
