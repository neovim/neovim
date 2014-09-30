" Vim syntax file
" Language:		CA-OpenROAD
" Maintainer:	Luis Moreno <lmoreno@eresmas.net>
" Last change:	2001 Jun 12

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
"
if version < 600
	syntax clear
elseif exists("b:current_syntax")
	finish
endif

syntax case ignore

" Keywords
"
syntax keyword openroadKeyword	ABORT ALL ALTER AND ANY AS ASC AT AVG BEGIN
syntax keyword openroadKeyword	BETWEEN BY BYREF CALL CALLFRAME CALLPROC CASE
syntax keyword openroadKeyword	CLEAR CLOSE COMMIT CONNECT CONTINUE COPY COUNT
syntax keyword openroadKeyword	CREATE CURRENT DBEVENT DECLARE DEFAULT DELETE
syntax keyword openroadKeyword	DELETEROW DESC DIRECT DISCONNECT DISTINCT DO
syntax keyword openroadKeyword	DROP ELSE ELSEIF END ENDCASE ENDDECLARE ENDFOR
syntax keyword openroadKeyword	ENDIF ENDLOOP ENDWHILE ESCAPE EXECUTE EXISTS
syntax keyword openroadKeyword	EXIT FETCH FIELD FOR FROM GOTOFRAME GRANT GROUP
syntax keyword openroadKeyword	HAVING IF IMMEDIATE IN INDEX INITIALISE
syntax keyword openroadKeyword	INITIALIZE INQUIRE_INGRES INQUIRE_SQL INSERT
syntax keyword openroadKeyword	INSERTROW INSTALLATION INTEGRITY INTO KEY LIKE
syntax keyword openroadKeyword	LINK MAX MESSAGE METHOD MIN MODE MODIFY NEXT
syntax keyword openroadKeyword	NOECHO NOT NULL OF ON OPEN OPENFRAME OR ORDER
syntax keyword openroadKeyword	PERMIT PROCEDURE PROMPT QUALIFICATION RAISE
syntax keyword openroadKeyword	REGISTER RELOCATE REMOVE REPEAT REPEATED RESUME
syntax keyword openroadKeyword	RETURN RETURNING REVOKE ROLE ROLLBACK RULE SAVE
syntax keyword openroadKeyword	SAVEPOINT SELECT SET SLEEP SOME SUM SYSTEM TABLE
syntax keyword openroadKeyword	THEN TO TRANSACTION UNION UNIQUE UNTIL UPDATE
syntax keyword openroadKeyword	VALUES VIEW WHERE WHILE WITH WORK

syntax keyword openroadTodo contained	TODO

" Catch errors caused by wrong parenthesis
"
syntax cluster	openroadParenGroup	contains=openroadParenError,openroadTodo
syntax region	openroadParen		transparent start='(' end=')' contains=ALLBUT,@openroadParenGroup
syntax match	openroadParenError	")"
highlight link	openroadParenError	cError

" Numbers
"
syntax match	openroadNumber		"\<[0-9]\+\>"

" String
"
syntax region	openroadString		start=+'+  end=+'+

" Operators, Data Types and Functions
"
syntax match	openroadOperator	/[\+\-\*\/=\<\>;\(\)]/

syntax keyword	openroadType		ARRAY BYTE CHAR DATE DECIMAL FLOAT FLOAT4
syntax keyword	openroadType		FLOAT8 INT1 INT2 INT4 INTEGER INTEGER1
syntax keyword	openroadType		INTEGER2 INTEGER4 MONEY OBJECT_KEY
syntax keyword	openroadType		SECURITY_LABEL SMALLINT TABLE_KEY VARCHAR

syntax keyword	openroadFunc		IFNULL

" System Classes
"
syntax keyword	openroadClass	ACTIVEFIELD ANALOGFIELD APPFLAG APPSOURCE
syntax keyword	openroadClass	ARRAYOBJECT ATTRIBUTEOBJECT BARFIELD
syntax keyword	openroadClass	BITMAPOBJECT BOXTRIM BREAKSPEC BUTTONFIELD
syntax keyword	openroadClass	CELLATTRIBUTE CHOICEBITMAP CHOICEDETAIL
syntax keyword	openroadClass	CHOICEFIELD CHOICEITEM CHOICELIST CLASS
syntax keyword	openroadClass	CLASSSOURCE COLUMNCROSS COLUMNFIELD
syntax keyword	openroadClass	COMPOSITEFIELD COMPSOURCE CONTROLBUTTON
syntax keyword	openroadClass	CROSSTABLE CURSORBITMAP CURSOROBJECT DATASTREAM
syntax keyword	openroadClass	DATEOBJECT DBEVENTOBJECT DBSESSIONOBJECT
syntax keyword	openroadClass	DISPLAYFORM DYNEXPR ELLIPSESHAPE ENTRYFIELD
syntax keyword	openroadClass	ENUMFIELD EVENT EXTOBJECT EXTOBJFIELD
syntax keyword	openroadClass	FIELDOBJECT FLEXIBLEFORM FLOATOBJECT FORMFIELD
syntax keyword	openroadClass	FRAMEEXEC FRAMEFORM FRAMESOURCE FREETRIM
syntax keyword	openroadClass	GHOSTEXEC GHOSTSOURCE IMAGEFIELD IMAGETRIM
syntax keyword	openroadClass	INTEGEROBJECT LISTFIELD LISTVIEWCOLATTR
syntax keyword	openroadClass	LISTVIEWFIELD LONGBYTEOBJECT LONGVCHAROBJECT
syntax keyword	openroadClass	MATRIXFIELD MENUBAR MENUBUTTON MENUFIELD
syntax keyword	openroadClass	MENUGROUP MENUITEM MENULIST MENUSEPARATOR
syntax keyword	openroadClass	MENUSTACK MENUTOGGLE METHODEXEC METHODOBJECT
syntax keyword	openroadClass	MONEYOBJECT OBJECT OPTIONFIELD OPTIONMENU
syntax keyword	openroadClass	PALETTEFIELD POPUPBUTTON PROC4GLSOURCE PROCEXEC
syntax keyword	openroadClass	PROCHANDLE QUERYCOL QUERYOBJECT QUERYPARM
syntax keyword	openroadClass	QUERYTABLE RADIOFIELD RECTANGLESHAPE ROWCROSS
syntax keyword	openroadClass	SCALARFIELD SCOPE SCROLLBARFIELD SEGMENTSHAPE
syntax keyword	openroadClass	SESSIONOBJECT SHAPEFIELD SLIDERFIELD SQLSELECT
syntax keyword	openroadClass	STACKFIELD STRINGOBJECT SUBFORM TABBAR
syntax keyword	openroadClass	TABFIELD TABFOLDER TABLEFIELD TABPAGE
syntax keyword	openroadClass	TOGGLEFIELD TREE TREENODE TREEVIEWFIELD
syntax keyword	openroadClass	USERCLASSOBJECT USEROBJECT VIEWPORTFIELD

" System Events
"
syntax keyword	openroadEvent	CHILDCLICK CHILDCLICKPOINT CHILDCOLLAPSED
syntax keyword	openroadEvent	CHILDDETAILS CHILDDOUBLECLICK CHILDDRAGBOX
syntax keyword	openroadEvent	CHILDDRAGSEGMENT CHILDENTRY CHILDEXIT
syntax keyword	openroadEvent	CHILDEXPANDED CHILDHEADERCLICK CHILDMOVED
syntax keyword	openroadEvent	CHILDPROPERTIES CHILDRESIZED CHILDSCROLL
syntax keyword	openroadEvent	CHILDSELECT CHILDSELECTIONCHANGED CHILDSETVALUE
syntax keyword	openroadEvent	CHILDUNSELECT CHILDVALIDATE CLICK CLICKPOINT
syntax keyword	openroadEvent	COLLAPSED DBEVENT DETAILS DOUBLECLICK DRAGBOX
syntax keyword	openroadEvent	DRAGSEGMENT ENTRY EXIT EXPANDED EXTCLASSEVENT
syntax keyword	openroadEvent	FRAMEACTIVATE FRAMEDEACTIVATE HEADERCLICK
syntax keyword	openroadEvent	INSERTROW LABELCHANGED MOVED PAGEACTIVATED
syntax keyword	openroadEvent	PAGECHANGED PAGEDEACTIVATED PROPERTIES RESIZED
syntax keyword	openroadEvent	SCROLL SELECT SELECTIONCHANGED SETVALUE
syntax keyword	openroadEvent	TERMINATE UNSELECT USEREVENT VALIDATE
syntax keyword	openroadEvent	WINDOWCLOSE WINDOWICON WINDOWMOVED WINDOWRESIZED
syntax keyword	openroadEvent	WINDOWVISIBLE

" System Constants
"
syntax keyword	openroadConst	BF_BMP BF_GIF BF_SUNRASTER BF_TIFF
syntax keyword	openroadConst	BF_WINDOWCURSOR BF_WINDOWICON BF_XBM
syntax keyword	openroadConst	CC_BACKGROUND CC_BLACK CC_BLUE CC_BROWN CC_CYAN
syntax keyword	openroadConst	CC_DEFAULT_1 CC_DEFAULT_10 CC_DEFAULT_11
syntax keyword	openroadConst	CC_DEFAULT_12 CC_DEFAULT_13 CC_DEFAULT_14
syntax keyword	openroadConst	CC_DEFAULT_15 CC_DEFAULT_16 CC_DEFAULT_17
syntax keyword	openroadConst	CC_DEFAULT_18 CC_DEFAULT_19 CC_DEFAULT_2
syntax keyword	openroadConst	CC_DEFAULT_20 CC_DEFAULT_21 CC_DEFAULT_22
syntax keyword	openroadConst	CC_DEFAULT_23 CC_DEFAULT_24 CC_DEFAULT_25
syntax keyword	openroadConst	CC_DEFAULT_26 CC_DEFAULT_27 CC_DEFAULT_28
syntax keyword	openroadConst	CC_DEFAULT_29 CC_DEFAULT_3 CC_DEFAULT_30
syntax keyword	openroadConst	CC_DEFAULT_4 CC_DEFAULT_5 CC_DEFAULT_6
syntax keyword	openroadConst	CC_DEFAULT_7 CC_DEFAULT_8 CC_DEFAULT_9
syntax keyword	openroadConst	CC_FOREGROUND CC_GRAY CC_GREEN CC_LIGHT_BLUE
syntax keyword	openroadConst	CC_LIGHT_BROWN	CC_LIGHT_CYAN CC_LIGHT_GRAY
syntax keyword	openroadConst	CC_LIGHT_GREEN CC_LIGHT_ORANGE CC_LIGHT_PINK
syntax keyword	openroadConst	CC_LIGHT_PURPLE CC_LIGHT_RED CC_LIGHT_YELLOW
syntax keyword	openroadConst	CC_MAGENTA CC_ORANGE CC_PALE_BLUE CC_PALE_BROWN
syntax keyword	openroadConst	CC_PALE_CYAN CC_PALE_GRAY CC_PALE_GREEN
syntax keyword	openroadConst	CC_PALE_ORANGE CC_PALE_PINK CC_PALE_PURPLE
syntax keyword	openroadConst	CC_PALE_RED CC_PALE_YELLOW CC_PINK CC_PURPLE
syntax keyword	openroadConst	CC_RED CC_SYS_ACTIVEBORDER CC_SYS_ACTIVECAPTION
syntax keyword	openroadConst	CC_SYS_APPWORKSPACE CC_SYS_BACKGROUND
syntax keyword	openroadConst	CC_SYS_BTNFACE CC_SYS_BTNSHADOW CC_SYS_BTNTEXT
syntax keyword	openroadConst	CC_SYS_CAPTIONTEXT CC_SYS_GRAYTEXT
syntax keyword	openroadConst	CC_SYS_HIGHLIGHT CC_SYS_HIGHLIGHTTEXT
syntax keyword	openroadConst	CC_SYS_INACTIVEBORDER CC_SYS_INACTIVECAPTION
syntax keyword	openroadConst	CC_SYS_INACTIVECAPTIONTEXT CC_SYS_MENU
syntax keyword	openroadConst	CC_SYS_MENUTEXT CC_SYS_SCROLLBAR CC_SYS_SHADOW
syntax keyword	openroadConst	CC_SYS_WINDOW CC_SYS_WINDOWFRAME
syntax keyword	openroadConst	CC_SYS_WINDOWTEXT CC_WHITE CC_YELLOW
syntax keyword	openroadConst	CL_INVALIDVALUE CP_BOTH CP_COLUMNS CP_NONE
syntax keyword	openroadConst	CP_ROWS CS_CLOSED CS_CURRENT CS_NOCURRENT
syntax keyword	openroadConst	CS_NO_MORE_ROWS CS_OPEN CS_OPEN_CACHED DC_BW
syntax keyword	openroadConst	DC_COLOR DP_AUTOSIZE_FIELD DP_CLIP_IMAGE
syntax keyword	openroadConst	DP_SCALE_IMAGE_H DP_SCALE_IMAGE_HW
syntax keyword	openroadConst	DP_SCALE_IMAGE_W DS_CONNECTED DS_DISABLED
syntax keyword	openroadConst	DS_DISCONNECTED DS_INGRES_DBMS DS_NO_DBMS
syntax keyword	openroadConst	DS_ORACLE_DBMS DS_SQLSERVER_DBMS DV_NULL
syntax keyword	openroadConst	DV_STRING DV_SYSTEM EH_NEXT_HANDLER EH_RESUME
syntax keyword	openroadConst	EH_RETRY EP_INTERACTIVE EP_NONE EP_OUTPUT
syntax keyword	openroadConst	ER_FAIL ER_NAMEEXISTS ER_OK ER_OUTOFRANGE
syntax keyword	openroadConst	ER_ROWNOTFOUND ER_USER1 ER_USER10 ER_USER2
syntax keyword	openroadConst	ER_USER3 ER_USER4 ER_USER5 ER_USER6 ER_USER7
syntax keyword	openroadConst	ER_USER8 ER_USER9 FALSE FA_BOTTOMCENTER
syntax keyword	openroadConst	FA_BOTTOMLEFT FA_BOTTOMRIGHT FA_CENTER
syntax keyword	openroadConst	FA_CENTERLEFT FA_CENTERRIGHT FA_DEFAULT FA_NONE
syntax keyword	openroadConst	FA_TOPCENTER FA_TOPLEFT FA_TOPRIGHT
syntax keyword	openroadConst	FB_CHANGEABLE FB_CLICKPOINT FB_DIMMED FB_DRAGBOX
syntax keyword	openroadConst	FB_DRAGSEGMENT FB_FLEXIBLE FB_INVISIBLE
syntax keyword	openroadConst	FB_LANDABLE FB_MARKABLE FB_RESIZEABLE
syntax keyword	openroadConst	FB_VIEWABLE FB_VISIBLE FC_LOWER FC_NONE FC_UPPER
syntax keyword	openroadConst	FM_QUERY FM_READ FM_UPDATE FM_USER1 FM_USER2
syntax keyword	openroadConst	FM_USER3 FO_DEFAULT FO_HORIZONTAL FO_VERTICAL
syntax keyword	openroadConst	FP_BITMAP FP_CLEAR FP_CROSSHATCH FP_DARKSHADE
syntax keyword	openroadConst	FP_DEFAULT FP_HORIZONTAL FP_LIGHTSHADE FP_SHADE
syntax keyword	openroadConst	FP_SOLID FP_VERTICAL FT_NOTSETVALUE FT_SETVALUE
syntax keyword	openroadConst	FT_TABTO FT_TAKEFOCUS GF_BOTTOM GF_DEFAULT
syntax keyword	openroadConst	GF_LEFT GF_RIGHT GF_TOP HC_DOUBLEQUOTE
syntax keyword	openroadConst	HC_FORMFEED HC_NEWLINE HC_QUOTE HC_SPACE HC_TAB
syntax keyword	openroadConst	HV_CONTENTS HV_CONTEXT HV_HELPONHELP HV_KEY
syntax keyword	openroadConst	HV_QUIT LS_3D LS_DASH LS_DASHDOT LS_DASHDOTDOT
syntax keyword	openroadConst	LS_DEFAULT LS_DOT LS_SOLID LW_DEFAULT
syntax keyword	openroadConst	LW_EXTRATHIN LW_MAXIMUM LW_MIDDLE LW_MINIMUM
syntax keyword	openroadConst	LW_NOLINE LW_THICK LW_THIN LW_VERYTHICK
syntax keyword	openroadConst	LW_VERYTHIN MB_DISABLED MB_ENABLED MB_INVISIBLE
syntax keyword	openroadConst	MB_MOVEABLE MT_ERROR MT_INFO MT_NONE MT_WARNING
syntax keyword	openroadConst	OP_APPEND OP_NONE OS3D OS_DEFAULT OS_SHADOW
syntax keyword	openroadConst	OS_SOLID PU_CANCEL PU_OK QS_ACTIVE QS_INACTIVE
syntax keyword	openroadConst	QS_SETCOL QY_ARRAY QY_CACHE QY_CURSOR QY_DIRECT
syntax keyword	openroadConst	RC_CHILDSELECTED RC_DOWN RC_END RC_FIELDFREED
syntax keyword	openroadConst	RC_FIELDORPHANED RC_GROUPSELECT RC_HOME RC_LEFT
syntax keyword	openroadConst	RC_MODECHANGED RC_MOUSECLICK RC_MOUSEDRAG
syntax keyword	openroadConst	RC_NEXT RC_NOTAPPLICABLE RC_PAGEDOWN RC_PAGEUP
syntax keyword	openroadConst	RC_PARENTSELECTED RC_PREVIOUS RC_PROGRAM
syntax keyword	openroadConst	RC_RESUME RC_RETURN RC_RIGHT RC_ROWDELETED
syntax keyword	openroadConst	RC_ROWINSERTED RC_ROWSALLDELETED RC_SELECT
syntax keyword	openroadConst	RC_TFSCROLL RC_TOGGLESELECT RC_UP RS_CHANGED
syntax keyword	openroadConst	RS_DELETED RS_NEW RS_UNCHANGED RS_UNDEFINED
syntax keyword	openroadConst	SK_CLOSE SK_COPY SK_CUT SK_DELETE SK_DETAILS
syntax keyword	openroadConst	SK_DUPLICATE SK_FIND SK_GO SK_HELP SK_NEXT
syntax keyword	openroadConst	SK_NONE SK_PASTE SK_PROPS SK_QUIT SK_REDO
syntax keyword	openroadConst	SK_SAVE SK_TFDELETEALLROWS SK_TFDELETEROW
syntax keyword	openroadConst	SK_TFFIND SK_TFINSERTROW SK_UNDO SP_APPSTARTING
syntax keyword	openroadConst	SP_ARROW SP_CROSS SP_IBEAM SP_ICON SP_NO
syntax keyword	openroadConst	SP_SIZE SP_SIZENESW SP_SIZENS SP_SIZENWSE
syntax keyword	openroadConst	SP_SIZEWE SP_UPARROW SP_WAIT SY_NT SY_OS2
syntax keyword	openroadConst	SY_UNIX SY_VMS SY_WIN95 TF_COURIER TF_HELVETICA
syntax keyword	openroadConst	TF_LUCIDA TF_MENUDEFAULT TF_NEWCENTURY TF_SYSTEM
syntax keyword	openroadConst	TF_TIMESROMAN TRUE UE_DATAERROR UE_EXITED
syntax keyword	openroadConst	UE_NOTACTIVE UE_PURGED UE_RESUMED UE_UNKNOWN
syntax keyword	openroadConst	WI_MOTIF WI_MSWIN32 WI_MSWINDOWS WI_NONE WI_PM
syntax keyword	openroadConst	WP_FLOATING WP_INTERACTIVE WP_PARENTCENTERED
syntax keyword	openroadConst	WP_PARENTRELATIVE WP_SCREENCENTERED
syntax keyword	openroadConst	WP_SCREENRELATIVE WV_ICON WV_INVISIBLE
syntax keyword	openroadConst	WV_UNREALIZED WV_VISIBLE

" System Variables
"
syntax keyword	openroadVar		CurFrame CurProcedure CurMethod CurObject

" Identifiers
"
syntax match	openroadIdent	/[a-zA-Z_][a-zA-Z_]*![a-zA-Z_][a-zA-Z_]*/

" Comments
"
if exists("openroad_comment_strings")
	syntax match openroadCommentSkip	contained "^\s*\*\($\|\s\+\)"
	syntax region openroadCommentString	contained start=+"+ skip=+\\\\\|\\"+ end=+"+ end="$"
	syntax region openroadComment		start="/\*" end="\*/" contains=openroadCommentString,openroadCharacter,openroadNumber
	syntax match openroadComment		"//.*" contains=openroadComment2String,openroadCharacter,openroadNumber
else
	syn region openroadComment			start="/\*" end="\*/"
	syn match openroadComment			"//.*"
endif

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
"
if version >= 508 || !exists("did_openroad_syntax_inits")
	if version < 508
		let did_openroad_syntax_inits = 1
		command -nargs=+ HiLink hi link <args>
	else
		command -nargs=+ HiLink hi def link <args>
	endif

	HiLink openroadKeyword	Statement
	HiLink openroadNumber	Number
	HiLink openroadString	String
	HiLink openroadComment	Comment
	HiLink openroadOperator	Operator
	HiLink openroadType		Type
	HiLink openroadFunc		Special
	HiLink openroadClass	Type
	HiLink openroadEvent	Statement
	HiLink openroadConst	Constant
	HiLink openroadVar		Identifier
	HiLink openroadIdent	Identifier
	HiLink openroadTodo		Todo

	delcommand HiLink
endif

let b:current_syntax = "openroad"
