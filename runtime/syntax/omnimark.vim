" Vim syntax file
" Language:	Omnimark
" Maintainer:	Paul Terray <mailto:terray@4dconcept.fr>
" Last Change:	11 Oct 2000

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

if version < 600
  set iskeyword=@,48-57,_,128-167,224-235,-
else
  setlocal iskeyword=@,48-57,_,128-167,224-235,-
endif

syn keyword omnimarkKeywords	ACTIVATE AGAIN
syn keyword omnimarkKeywords	CATCH CLEAR CLOSE COPY COPY-CLEAR CROSS-TRANSLATE
syn keyword omnimarkKeywords	DEACTIVATE DECLARE DECREMENT DEFINE DISCARD DIVIDE DO DOCUMENT-END DOCUMENT-START DONE DTD-START
syn keyword omnimarkKeywords	ELEMENT ELSE ESCAPE EXIT
syn keyword omnimarkKeywords	FAIL FIND FIND-END FIND-START FORMAT
syn keyword omnimarkKeywords	GROUP
syn keyword omnimarkKeywords	HALT HALT-EVERYTHING
syn keyword omnimarkKeywords	IGNORE IMPLIED INCLUDE INCLUDE-END INCLUDE-START INCREMENT INPUT
syn keyword omnimarkKeywords	JOIN
syn keyword omnimarkKeywords	LINE-END LINE-START LOG LOOKAHEAD
syn keyword omnimarkKeywords	MACRO
syn keyword omnimarkKeywords	MACRO-END MARKED-SECTION MARKUP-COMMENT MARKUP-ERROR MARKUP-PARSER MASK MATCH MINUS MODULO
syn keyword omnimarkKeywords	NEW NEWLINE NEXT
syn keyword omnimarkKeywords	OPEN OUTPUT OUTPUT-TO OVER
syn keyword omnimarkKeywords	PROCESS PROCESS-END PROCESS-START PROCESSING-INSTRUCTION PROLOG-END PROLOG-IN-ERROR PUT
syn keyword omnimarkKeywords	REMOVE REOPEN REPEAT RESET RETHROW RETURN
syn keyword omnimarkKeywords	WHEN WHITE-SPACE
syn keyword omnimarkKeywords	SAVE SAVE-CLEAR SCAN SELECT SET SGML SGML-COMMENT SGML-DECLARATION-END SGML-DTD SGML-DTDS SGML-ERROR SGML-IN SGML-OUT SGML-PARSE SGML-PARSER SHIFT SUBMIT SUCCEED SUPPRESS
syn keyword omnimarkKeywords	SYSTEM-CALL
syn keyword omnimarkKeywords	TEST-SYSTEM THROW TO TRANSLATE
syn keyword omnimarkKeywords	UC UL UNLESS UP-TRANSLATE
syn keyword omnimarkKeywords	XML-PARSE

syn keyword omnimarkCommands	ACTIVE AFTER ANCESTOR AND ANOTHER ARG AS ATTACHED ATTRIBUTE ATTRIBUTES
syn keyword omnimarkCommands	BASE BEFORE BINARY BINARY-INPUT BINARY-MODE BINARY-OUTPUT BREAK-WIDTH BUFFER BY
syn keyword omnimarkCommands	CASE CHILDREN CLOSED COMPILED-DATE COMPLEMENT CONREF CONTENT CONTEXT-TRANSLATE COUNTER CREATED CREATING CREATOR CURRENT
syn keyword omnimarkCommands	DATA-ATTRIBUTE DATA-ATTRIBUTES DATA-CONTENT DATA-LETTERS DATE DECLARED-CONREF DECLARED-CURRENT DECLARED-DEFAULTED DECLARED-FIXED DECLARED-IMPLIED DECLARED-REQUIRED
syn keyword omnimarkCommands	DEFAULT-ENTITY DEFAULTED DEFAULTING DELIMITER DIFFERENCE DIRECTORY DOCTYPE DOCUMENT DOCUMENT-ELEMENT DOMAIN-FREE DOWN-TRANSLATE DTD DTD-END DTDS
syn keyword omnimarkCommands	ELEMENTS ELSEWHERE EMPTY ENTITIES ENTITY EPILOG-START EQUAL EXCEPT EXISTS EXTERNAL EXTERNAL-DATA-ENTITY EXTERNAL-ENTITY EXTERNAL-FUNCTION EXTERNAL-OUTPUT-FUNCTION
syn keyword omnimarkCommands	EXTERNAL-TEXT-ENTITY
syn keyword omnimarkCommands	FALSE FILE FUNCTION FUNCTION-LIBRARY
syn keyword omnimarkCommands	GENERAL GLOBAL GREATER-EQUAL GREATER-THAN GROUPS
syn keyword omnimarkCommands	HAS HASNT HERALDED-NAMES
syn keyword omnimarkCommands	ID ID-CHECKING IDREF IDREFS IN IN-LIBRARY INCLUSION INITIAL INITIAL-SIZE INSERTION-BREAK INSTANCE INTERNAL INVALID-DATA IS ISNT ITEM
syn keyword omnimarkCommands	KEY KEYED
syn keyword omnimarkCommands	LAST LASTMOST LC LENGTH LESS-EQUAL LESS-THAN LETTERS LIBRARY LITERAL LOCAL
syn keyword omnimarkCommands	MATCHES MIXED MODIFIABLE
syn keyword omnimarkCommands	NAME NAME-LETTERS NAMECASE NAMED NAMES NDATA-ENTITY NEGATE NESTED-REFERENTS NMTOKEN NMTOKENS NO NO-DEFAULT-IO NON-CDATA NON-IMPLIED NON-SDATA NOT NOTATION NUMBER-OF NUMBERS
syn keyword omnimarkCommands	NUTOKEN NUTOKENS
syn keyword omnimarkCommands	OCCURRENCE OF OPAQUE OPTIONAL OR
syn keyword omnimarkCommands	PARAMETER PARENT PAST PATTERN PLUS PREPARENT PREVIOUS PROPER PUBLIC
syn keyword omnimarkCommands	READ-ONLY READABLE REFERENT REFERENTS REFERENTS-ALLOWED REFERENTS-DISPLAYED REFERENTS-NOT-ALLOWED REMAINDER REPEATED REPLACEMENT-BREAK REVERSED
syn keyword omnimarkCommands	SILENT-REFERENT SIZE SKIP SOURCE SPECIFIED STATUS STREAM SUBDOC-ENTITY SUBDOCUMENT SUBDOCUMENTS SUBELEMENT SWITCH SYMBOL SYSTEM
syn keyword omnimarkCommands	TEXT-MODE THIS TIMES TOKEN TRUE
syn keyword omnimarkCommands	UNANCHORED UNATTACHED UNION USEMAP USING
syn keyword omnimarkCommands	VALUE VALUED VARIABLE
syn keyword omnimarkCommands	WITH WRITABLE
syn keyword omnimarkCommands	XML XML-DTD XML-DTDS
syn keyword omnimarkCommands	YES
syn keyword omnimarkCommands	#ADDITIONAL-INFO #APPINFO #CAPACITY #CHARSET #CLASS #COMMAND-LINE-NAMES #CONSOLE #CURRENT-INPUT #CURRENT-OUTPUT #DATA #DOCTYPE #DOCUMENT #DTD #EMPTY #ERROR #ERROR-CODE
syn keyword omnimarkCommands	#FILE-NAME #FIRST #GROUP #IMPLIED #ITEM #LANGUAGE-VERSION #LAST #LIBPATH #LIBRARY #LIBVALUE #LINE-NUMBER #MAIN-INPUT #MAIN-OUTPUT #MARKUP-ERROR-COUNT #MARKUP-ERROR-TOTAL
syn keyword omnimarkCommands	#MARKUP-PARSER #MARKUP-WARNING-COUNT #MARKUP-WARNING-TOTAL #MESSAGE #NONE #OUTPUT #PLATFORM-INFO #PROCESS-INPUT #PROCESS-OUTPUT #RECOVERY-INFO #SGML #SGML-ERROR-COUNT
syn keyword omnimarkCommands	#SGML-ERROR-TOTAL #SGML-WARNING-COUNT #SGML-WARNING-TOTAL #SUPPRESS #SYNTAX #!

syn keyword omnimarkPatterns	ANY ANY-TEXT
syn keyword omnimarkPatterns	BLANK
syn keyword omnimarkPatterns	CDATA CDATA-ENTITY CONTENT-END CONTENT-START
syn keyword omnimarkPatterns	DIGIT
syn keyword omnimarkPatterns	LETTER
syn keyword omnimarkPatterns	NUMBER
syn keyword omnimarkPatterns	PCDATA
syn keyword omnimarkPatterns	RCDATA
syn keyword omnimarkPatterns	SDATA SDATA-ENTITY SPACE
syn keyword omnimarkPatterns	TEXT
syn keyword omnimarkPatterns	VALUE-END VALUE-START
syn keyword omnimarkPatterns	WORD-END WORD-START

syn region  omnimarkComment	start=";" end="$"

" strings
syn region  omnimarkString		matchgroup=Normal start=+'+  end=+'+ skip=+%'+ contains=omnimarkEscape
syn region  omnimarkString		matchgroup=Normal start=+"+  end=+"+ skip=+%"+ contains=omnimarkEscape
syn match  omnimarkEscape contained +%.+
syn match  omnimarkEscape contained +%[0-9][0-9]#+

"syn sync maxlines=100
syn sync minlines=2000

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_omnimark_syntax_inits")
  if version < 508
    let did_omnimark_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink omnimarkCommands		Statement
  HiLink omnimarkKeywords		Identifier
  HiLink omnimarkString		String
  HiLink omnimarkPatterns		Macro
"  HiLink omnimarkNumber			Number
  HiLink omnimarkComment		Comment
  HiLink omnimarkEscape		Special

  delcommand HiLink
endif

let b:current_syntax = "omnimark"

" vim: ts=8

