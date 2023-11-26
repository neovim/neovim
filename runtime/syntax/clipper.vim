" Vim syntax file:
" Language:	Clipper 5.2 & FlagShip
" Maintainer:	C R Zamana <zamana@zip.net>
" Some things based on c.vim by Bram Moolenaar and pascal.vim by Mario Eusebio
" Last Change:	2011 Dec 29 by Thilo Six

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Exceptions for my "Very Own" (TM) user variables naming style.
" If you don't like this, comment it
syn match  clipperUserVariable	"\<[a,b,c,d,l,n,o,u,x][A-Z][A-Za-z0-9_]*\>"
syn match  clipperUserVariable	"\<[a-z]\>"

" Clipper is case insensitive ( see "exception" above )
syn case ignore

" Clipper keywords ( in no particular order )
syn keyword clipperStatement	ACCEPT APPEND BLANK FROM AVERAGE CALL CANCEL
syn keyword clipperStatement	CLEAR ALL GETS MEMORY TYPEAHEAD CLOSE
syn keyword clipperStatement	COMMIT CONTINUE SHARED NEW PICT
syn keyword clipperStatement	COPY FILE STRUCTURE STRU EXTE TO COUNT
syn keyword clipperStatement	CREATE FROM NIL
syn keyword clipperStatement	DELETE FILE DIR DISPLAY EJECT ERASE FIND GO
syn keyword clipperStatement	INDEX INPUT VALID WHEN
syn keyword clipperStatement	JOIN KEYBOARD LABEL FORM LIST LOCATE MENU TO
syn keyword clipperStatement	NOTE PACK QUIT READ
syn keyword clipperStatement	RECALL REINDEX RELEASE RENAME REPLACE REPORT
syn keyword clipperStatement	RETURN FORM RESTORE
syn keyword clipperStatement	RUN SAVE SEEK SELECT
syn keyword clipperStatement	SKIP SORT STORE SUM TEXT TOTAL TYPE UNLOCK
syn keyword clipperStatement	UPDATE USE WAIT ZAP
syn keyword clipperStatement	BEGIN SEQUENCE
syn keyword clipperStatement	SET ALTERNATE BELL CENTURY COLOR CONFIRM CONSOLE
syn keyword clipperStatement	CURSOR DATE DECIMALS DEFAULT DELETED DELIMITERS
syn keyword clipperStatement	DEVICE EPOCH ESCAPE EXACT EXCLUSIVE FILTER FIXED
syn keyword clipperStatement	FORMAT FUNCTION INTENSITY KEY MARGIN MESSAGE
syn keyword clipperStatement	ORDER PATH PRINTER PROCEDURE RELATION SCOREBOARD
syn keyword clipperStatement	SOFTSEEK TYPEAHEAD UNIQUE WRAP
syn keyword clipperStatement	BOX CLEAR GET PROMPT SAY ? ??
syn keyword clipperStatement	DELETE TAG GO RTLINKCMD TMP DBLOCKINFO
syn keyword clipperStatement	DBEVALINFO DBFIELDINFO DBFILTERINFO DBFUNCTABLE
syn keyword clipperStatement	DBOPENINFO DBORDERCONDINFO DBORDERCREATEINF
syn keyword clipperStatement	DBORDERINFO DBRELINFO DBSCOPEINFO DBSORTINFO
syn keyword clipperStatement	DBSORTITEM DBTRANSINFO DBTRANSITEM WORKAREA

" Conditionals
syn keyword clipperConditional	CASE OTHERWISE ENDCASE
syn keyword clipperConditional	IF ELSE ENDIF IIF IFDEF IFNDEF

" Loops
syn keyword clipperRepeat	DO WHILE ENDDO
syn keyword clipperRepeat	FOR TO NEXT STEP

" Visibility
syn keyword clipperStorageClass	ANNOUNCE STATIC
syn keyword clipperStorageClass DECLARE EXTERNAL LOCAL MEMVAR PARAMETERS
syn keyword clipperStorageClass PRIVATE PROCEDURE PUBLIC REQUEST STATIC
syn keyword clipperStorageClass FIELD FUNCTION
syn keyword clipperStorageClass EXIT PROCEDURE INIT PROCEDURE

" Operators
syn match   clipperOperator	"$\|%\|&\|+\|-\|->\|!"
syn match   clipperOperator	"\.AND\.\|\.NOT\.\|\.OR\."
syn match   clipperOperator	":=\|<\|<=\|<>\|!=\|#\|=\|==\|>\|>=\|@"
syn match   clipperOperator     "*"

" Numbers
syn match   clipperNumber	"\<\d\+\(u\=l\=\|lu\|f\)\>"

" Includes
syn region clipperIncluded	contained start=+"+ skip=+\\\\\|\\"+ end=+"+
syn match  clipperIncluded	contained "<[^>]*>"
syn match  clipperInclude	"^\s*#\s*include\>\s*["<]" contains=clipperIncluded

" String and Character constants
syn region clipperString	start=+"+ end=+"+
syn region clipperString	start=+'+ end=+'+

" Delimiters
syn match  ClipperDelimiters	"[()]\|[\[\]]\|[{}]\|[||]"

" Special
syn match clipperLineContinuation	";"

" This is from Bram Moolenaar:
if exists("c_comment_strings")
  " A comment can contain cString, cCharacter and cNumber.
  " But a "*/" inside a cString in a clipperComment DOES end the comment!
  " So we need to use a special type of cString: clipperCommentString, which
  " also ends on "*/", and sees a "*" at the start of the line as comment
  " again. Unfortunately this doesn't very well work for // type of comments :-(
  syntax match clipperCommentSkip	contained "^\s*\*\($\|\s\+\)"
  syntax region clipperCommentString	contained start=+"+ skip=+\\\\\|\\"+ end=+"+ end=+\*/+me=s-1 contains=clipperCommentSkip
  syntax region clipperComment2String	contained start=+"+ skip=+\\\\\|\\"+ end=+"+ end="$"
  syntax region clipperComment		start="/\*" end="\*/" contains=clipperCommentString,clipperCharacter,clipperNumber,clipperString
  syntax match  clipperComment		"//.*" contains=clipperComment2String,clipperCharacter,clipperNumber
else
  syn region clipperComment		start="/\*" end="\*/"
  syn match clipperComment		"//.*"
endif
syntax match clipperCommentError	"\*/"

" Lines beginning with an "*" are comments too
syntax match clipperComment		"^\*.*"


" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link clipperConditional		Conditional
hi def link clipperRepeat			Repeat
hi def link clipperNumber			Number
hi def link clipperInclude		Include
hi def link clipperComment		Comment
hi def link clipperOperator		Operator
hi def link clipperStorageClass		StorageClass
hi def link clipperStatement		Statement
hi def link clipperString			String
hi def link clipperFunction		Function
hi def link clipperLineContinuation	Special
hi def link clipperDelimiters		Delimiter
hi def link clipperUserVariable		Identifier


let b:current_syntax = "clipper"

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: ts=8
