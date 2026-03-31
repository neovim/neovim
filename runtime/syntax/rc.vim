" Vim syntax file
" Language:	M$ Resource files (*.rc)
" Maintainer:	Christian Brabandt
" Last Change:	20220116
" Repository:   https://github.com/chrisbra/vim-rc-syntax
" License:	Vim (see :h license)
" Previous Maintainer:	Heiko Erhardt <Heiko.Erhardt@munich.netsurf.de>

" This file is based on the c.vim

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Common RC keywords
syn keyword rcLanguage LANGUAGE

syn keyword rcMainObject TEXTINCLUDE VERSIONINFO BITMAP ICON CURSOR CURSOR
syn keyword rcMainObject MENU ACCELERATORS TOOLBAR DIALOG
syn keyword rcMainObject STRINGTABLE MESSAGETABLE RCDATA DLGINIT DESIGNINFO

syn keyword rcSubObject POPUP MENUITEM SEPARATOR
syn keyword rcSubObject CONTROL LTEXT CTEXT RTEXT EDITTEXT
syn keyword rcSubObject BUTTON PUSHBUTTON DEFPUSHBUTTON GROUPBOX LISTBOX COMBOBOX
syn keyword rcSubObject FILEVERSION PRODUCTVERSION FILEFLAGSMASK FILEFLAGS FILEOS
syn keyword rcSubObject FILETYPE FILESUBTYPE

syn keyword rcCaptionParam CAPTION
syn keyword rcParam CHARACTERISTICS CLASS STYLE EXSTYLE VERSION FONT

syn keyword rcStatement BEGIN END BLOCK VALUE

syn keyword rcCommonAttribute PRELOAD LOADONCALL FIXED MOVEABLE DISCARDABLE PURE IMPURE

syn keyword rcAttribute WS_OVERLAPPED WS_POPUP WS_CHILD WS_MINIMIZE WS_VISIBLE WS_DISABLED WS_CLIPSIBLINGS
syn keyword rcAttribute WS_CLIPCHILDREN WS_MAXIMIZE WS_CAPTION WS_BORDER WS_DLGFRAME WS_VSCROLL WS_HSCROLL
syn keyword rcAttribute WS_SYSMENU WS_THICKFRAME WS_GROUP WS_TABSTOP WS_MINIMIZEBOX WS_MAXIMIZEBOX WS_TILED
syn keyword rcAttribute WS_ICONIC WS_SIZEBOX WS_TILEDWINDOW WS_OVERLAPPEDWINDOW WS_POPUPWINDOW WS_CHILDWINDOW
syn keyword rcAttribute WS_EX_DLGMODALFRAME WS_EX_NOPARENTNOTIFY WS_EX_TOPMOST WS_EX_ACCEPTFILES
syn keyword rcAttribute WS_EX_TRANSPARENT WS_EX_MDICHILD WS_EX_TOOLWINDOW WS_EX_WINDOWEDGE WS_EX_CLIENTEDGE
syn keyword rcAttribute WS_EX_CONTEXTHELP WS_EX_RIGHT WS_EX_LEFT WS_EX_RTLREADING WS_EX_LTRREADING
syn keyword rcAttribute WS_EX_LEFTSCROLLBAR WS_EX_RIGHTSCROLLBAR WS_EX_CONTROLPARENT WS_EX_STATICEDGE
syn keyword rcAttribute WS_EX_APPWINDOW WS_EX_OVERLAPPEDWINDOW WS_EX_PALETTEWINDOW
syn keyword rcAttribute ES_LEFT ES_CENTER ES_RIGHT ES_MULTILINE ES_UPPERCASE ES_LOWERCASE ES_PASSWORD
syn keyword rcAttribute ES_AUTOVSCROLL ES_AUTOHSCROLL ES_NOHIDESEL ES_OEMCONVERT ES_READONLY ES_WANTRETURN
syn keyword rcAttribute ES_NUMBER
syn keyword rcAttribute BS_PUSHBUTTON BS_DEFPUSHBUTTON BS_CHECKBOX BS_AUTOCHECKBOX BS_RADIOBUTTON BS_3STATE
syn keyword rcAttribute BS_AUTO3STATE BS_GROUPBOX BS_USERBUTTON BS_AUTORADIOBUTTON BS_OWNERDRAW BS_LEFTTEXT
syn keyword rcAttribute BS_TEXT BS_ICON BS_BITMAP BS_LEFT BS_RIGHT BS_CENTER BS_TOP BS_BOTTOM BS_VCENTER
syn keyword rcAttribute BS_PUSHLIKE BS_MULTILINE BS_NOTIFY BS_FLAT BS_RIGHTBUTTON
syn keyword rcAttribute SS_LEFT SS_CENTER SS_RIGHT SS_ICON SS_BLACKRECT SS_GRAYRECT SS_WHITERECT
syn keyword rcAttribute SS_BLACKFRAME SS_GRAYFRAME SS_WHITEFRAME SS_USERITEM SS_SIMPLE SS_LEFTNOWORDWRAP
syn keyword rcAttribute SS_OWNERDRAW SS_BITMAP SS_ENHMETAFILE SS_ETCHEDHORZ SS_ETCHEDVERT SS_ETCHEDFRAME
syn keyword rcAttribute SS_TYPEMASK SS_NOPREFIX SS_NOTIFY SS_CENTERIMAGE SS_RIGHTJUST SS_REALSIZEIMAGE
syn keyword rcAttribute SS_SUNKEN SS_ENDELLIPSIS SS_PATHELLIPSIS SS_WORDELLIPSIS SS_ELLIPSISMASK
syn keyword rcAttribute DS_ABSALIGN DS_SYSMODAL DS_LOCALEDIT DS_SETFONT DS_MODALFRAME DS_NOIDLEMSG
syn keyword rcAttribute DS_SETFOREGROUND DS_3DLOOK DS_FIXEDSYS DS_NOFAILCREATE DS_CONTROL DS_CENTER
syn keyword rcAttribute DS_CENTERMOUSE DS_CONTEXTHELP
syn keyword rcAttribute LBS_NOTIFY LBS_SORT LBS_NOREDRAW LBS_MULTIPLESEL LBS_OWNERDRAWFIXED
syn keyword rcAttribute LBS_OWNERDRAWVARIABLE LBS_HASSTRINGS LBS_USETABSTOPS LBS_NOINTEGRALHEIGHT
syn keyword rcAttribute LBS_MULTICOLUMN LBS_WANTKEYBOARDINPUT LBS_EXTENDEDSEL LBS_DISABLENOSCROLL
syn keyword rcAttribute LBS_NODATA LBS_NOSEL LBS_STANDARD
syn keyword rcAttribute CBS_SIMPLE CBS_DROPDOWN CBS_DROPDOWNLIST CBS_OWNERDRAWFIXED CBS_OWNERDRAWVARIABLE
syn keyword rcAttribute CBS_AUTOHSCROLL CBS_OEMCONVERT CBS_SORT CBS_HASSTRINGS CBS_NOINTEGRALHEIGHT
syn keyword rcAttribute CBS_DISABLENOSCROLL CBS_UPPERCASE CBS_LOWERCASE
syn keyword rcAttribute SBS_HORZ SBS_VERT SBS_TOPALIGN SBS_LEFTALIGN SBS_BOTTOMALIGN SBS_RIGHTALIGN
syn keyword rcAttribute SBS_SIZEBOXTOPLEFTALIGN SBS_SIZEBOXBOTTOMRIGHTALIGN SBS_SIZEBOX SBS_SIZEGRIP
syn keyword rcAttribute CCS_TOP CCS_NOMOVEY CCS_BOTTOM CCS_NORESIZE CCS_NOPARENTALIGN CCS_ADJUSTABLE
syn keyword rcAttribute CCS_NODIVIDER
syn keyword rcAttribute LVS_ICON LVS_REPORT LVS_SMALLICON LVS_LIST LVS_TYPEMASK LVS_SINGLESEL LVS_SHOWSELALWAYS
syn keyword rcAttribute LVS_SORTASCENDING LVS_SORTDESCENDING LVS_SHAREIMAGELISTS LVS_NOLABELWRAP
syn keyword rcAttribute LVS_EDITLABELS LVS_OWNERDATA LVS_NOSCROLL LVS_TYPESTYLEMASK  LVS_ALIGNTOP LVS_ALIGNLEFT
syn keyword rcAttribute LVS_ALIGNMASK LVS_OWNERDRAWFIXED LVS_NOCOLUMNHEADER LVS_NOSORTHEADER LVS_AUTOARRANGE
syn keyword rcAttribute TVS_HASBUTTONS TVS_HASLINES TVS_LINESATROOT TVS_EDITLABELS TVS_DISABLEDRAGDROP
syn keyword rcAttribute TVS_SHOWSELALWAYS
syn keyword rcAttribute TCS_FORCEICONLEFT TCS_FORCELABELLEFT TCS_TABS TCS_BUTTONS TCS_SINGLELINE TCS_MULTILINE
syn keyword rcAttribute TCS_RIGHTJUSTIFY TCS_FIXEDWIDTH TCS_RAGGEDRIGHT TCS_FOCUSONBUTTONDOWN
syn keyword rcAttribute TCS_OWNERDRAWFIXED TCS_TOOLTIPS TCS_FOCUSNEVER
syn keyword rcAttribute ACS_CENTER ACS_TRANSPARENT ACS_AUTOPLAY
syn keyword rcStdId IDI_APPLICATION IDI_HAND IDI_QUESTION IDI_EXCLAMATION IDI_ASTERISK IDI_WINLOGO IDI_WINLOGO
syn keyword rcStdId IDI_WARNING IDI_ERROR IDI_INFORMATION
syn keyword rcStdId IDCANCEL IDABORT IDRETRY IDIGNORE IDYES IDNO IDCLOSE IDHELP IDC_STATIC

" Common RC keywords

" Common RC keywords
syn keyword rcTodo contained	TODO FIXME XXX

" String and Character constants
" Highlight special characters (those which have a backslash) differently
syn match rcSpecial contained	"\\[0-7][0-7][0-7]\=\|\\."
syn region rcString		start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=rcSpecial
syn match rcCharacter		"'[^\\]'"
syn match rcSpecialCharacter	"'\\.'"
syn match rcSpecialCharacter	"'\\[0-7][0-7]'"
syn match rcSpecialCharacter	"'\\[0-7][0-7][0-7]'"

"catch errors caused by wrong parenthesis
syn region rcParen		transparent start='(' end=')' contains=ALLBUT,rcParenError,rcIncluded,rcSpecial,rcTodo
syn match rcParenError		")"
syn match rcInParen contained	"[{}]"

"integer number, or floating point number without a dot and with "f".
syn case ignore
syn match rcNumber		"\<\d\+\(u\=l\=\|lu\|f\)\>"
"floating point number, with dot, optional exponent
syn match rcFloat		"\<\d\+\.\d*\(e[-+]\=\d\+\)\=[fl]\=\>"
"floating point number, starting with a dot, optional exponent
syn match rcFloat		"\.\d\+\(e[-+]\=\d\+\)\=[fl]\=\>"
"floating point number, without dot, with exponent
syn match rcFloat		"\<\d\+e[-+]\=\d\+[fl]\=\>"
"hex number
syn match rcNumber		"\<0x[0-9a-f]\+\(u\=l\=\|lu\)\>"
"syn match rcIdentifier	"\<[a-z_][a-z0-9_]*\>"
syn case match
" flag an octal number with wrong digits
syn match rcOctalError		"\<0[0-7]*[89]"

if exists("rc_comment_strings")
  " A comment can contain rcString, rcCharacter and rcNumber.
  " But a "*/" inside a rcString in a rcComment DOES end the comment!  So we
  " need to use a special type of rcString: rcCommentString, which also ends on
  " "*/", and sees a "*" at the start of the line as comment again.
  " Unfortunately this doesn't very well work for // type of comments :-(
  syntax match rcCommentSkip	contained "^\s*\*\($\|\s\+\)"
  syntax region rcCommentString	contained start=+"+ skip=+\\\\\|\\"+ end=+"+ end=+\*/+me=s-1 contains=rcSpecial,rcCommentSkip
  syntax region rcComment2String	contained start=+"+ skip=+\\\\\|\\"+ end=+"+ end="$" contains=rcSpecial
  syntax region rcComment	start="/\*" end="\*/" contains=rcTodo,rcCommentString,rcCharacter,rcNumber,rcFloat
  syntax match  rcComment	"//.*" contains=rcTodo,rcComment2String,rcCharacter,rcNumber
else
  syn region rcComment		start="/\*" end="\*/" contains=rcTodo
  syn match rcComment		"//.*" contains=rcTodo
endif
syntax match rcCommentError	"\*/"

syn region rcPreCondit	start="^\s*#\s*\(if\>\|ifdef\>\|ifndef\>\|elif\>\|else\>\|endif\>\)" skip="\\$" end="$" contains=rcComment,rcString,rcCharacter,rcNumber,rcCommentError
syn region rcIncluded contained start=+"+ skip=+\\\\\|\\"+ end=+"+
syn match rcIncluded contained "<[^>]*>"
syn match rcInclude		"^\s*#\s*include\>\s*["<]" contains=rcIncluded
"syn match rcLineSkip	"\\$"
syn region rcDefine		start="^\s*#\s*\(define\>\|undef\>\)" skip="\\$" end="$" contains=ALLBUT,rcPreCondit,rcIncluded,rcInclude,rcDefine,rcInParen
syn region rcPreProc		start="^\s*#\s*\(pragma\>\|line\>\|warning\>\|warn\>\|error\>\)" skip="\\$" end="$" contains=ALLBUT,rcPreCondit,rcIncluded,rcInclude,rcDefine,rcInParen

syn sync ccomment rcComment minlines=10

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link rcCharacter	Character
hi def link rcSpecialCharacter rcSpecial
hi def link rcNumber	Number
hi def link rcFloat	Float
hi def link rcOctalError	rcError
hi def link rcParenError	rcError
hi def link rcInParen	rcError
hi def link rcCommentError	rcError
hi def link rcInclude	Include
hi def link rcPreProc	PreProc
hi def link rcDefine	Macro
hi def link rcIncluded	rcString
hi def link rcError	Error
hi def link rcPreCondit	PreCondit
hi def link rcCommentString rcString
hi def link rcComment2String rcString
hi def link rcCommentSkip	rcComment
hi def link rcString	String
hi def link rcComment	Comment
hi def link rcSpecial	SpecialChar
hi def link rcTodo	Todo

hi def link rcAttribute	rcCommonAttribute
hi def link rcStdId	rcStatement
hi def link rcStatement	Statement

hi def link rcLanguage	Constant
hi def link rcCaptionParam Constant
hi def link rcCommonAttribute Constant

hi def link rcMainObject Identifier
hi def link rcSubObject	Define
hi def link rcParam	Constant
hi def link rcStatement	Statement
"
"hi def link rcIdentifier Identifier



let b:current_syntax = "rc"

" vim: ts=8
