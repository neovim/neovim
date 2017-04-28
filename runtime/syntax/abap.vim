" Vim ABAP syntax file
"    Language: SAP - ABAP/R4
"    Revision: 2.1
"  Maintainer: Marius Piedallu van Wyk <lailoken@gmail.com>
" Last Change: 2013 Jun 13
"     Comment: Thanks to EPI-USE Labs for all your assistance. :)

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Always ignore case
syn case ignore

" Symbol Operators (space delimited)
syn match   abapSymbolOperator  "\W+\W"
syn match   abapSymbolOperator  "\W-\W"
syn match   abapSymbolOperator  "\W/\W"
syn match   abapSymbolOperator  "\W%\W"
syn match   abapSymbolOperator  "\W=\W"
syn match   abapSymbolOperator  "\W<\W"
syn match   abapSymbolOperator  "\W>\W"
syn match   abapSymbolOperator  "\W\*\W"
syn match   abapSymbolOperator  "\W[<>]=\W"
syn match   abapSymbolOperator  "\W<>\W"
syn match   abapSymbolOperator  "\W\*\*\W"
syn match   abapSymbolOperator  "\[\]"
syn match   abapSymbolOperator  "->\*\?"
syn match   abapSymbolOperator  "=>"
syn match   abapSymbolOperator  "[()~:,\.&$]"

" Literals
syn region  abapCharString matchgroup=abapCharString start="'" end="'" contains=abapCharStringEscape
syn match   abapCharStringEscape contained "''"

syn region  abapString matchgroup=abapString start="`" end="`" contains=abapStringEscape
syn match   abapStringEscape contained "``"

syn match   abapNumber  "\-\=\<\d\+\>"
syn region  abapHex     matchgroup=abapHex start="X'" end="'"

setlocal iskeyword=48-57,_,A-Z,a-z,/

syn match   abapNamespace        "\</\w\+/"

" multi-word statements
syn match   abapComplexStatement "\<\(WITH\W\+\(HEADER\W\+LINE\|FRAME\|KEY\)\|WITH\)\>"
syn match   abapComplexStatement "\<NO\W\+STANDARD\W\+PAGE\W\+HEADING\>"
syn match   abapComplexStatement "\<\(EXIT\W\+FROM\W\+STEP\W\+LOOP\|EXIT\)\>"
syn match   abapComplexStatement "\<\(BEGIN\W\+OF\W\+\(BLOCK\|LINE\)\|BEGIN\W\+OF\)\>"
syn match   abapComplexStatement "\<\(END\W\+OF\W\+\(BLOCK\|LINE\)\|END\W\+OF\)\>"
syn match   abapComplexStatement "\<NO\W\+INTERVALS\>"
syn match   abapComplexStatement "\<RESPECTING\W\+BLANKS\>"
syn match   abapComplexStatement "\<SEPARATED\W\+BY\>"
syn match   abapComplexStatement "\<USING\(\W\+EDIT\W\+MASK\)\?\>"
syn match   abapComplexStatement "\<WHERE\(\W\+LINE\)\?\>"
syn match   abapComplexStatement "\<RADIOBUTTON\W\+GROUP\>"
syn match   abapComplexStatement "\<REF\W\+TO\>"
syn match   abapComplexStatement "\<\(PUBLIC\|PRIVATE\|PROTECTED\)\(\W\+SECTION\)\?\>"
syn match   abapComplexStatement "\<DELETING\W\+\(TRAILING\|LEADING\)\>"
syn match   abapComplexStatement "\<\(ALL\W\+OCCURRENCES\)\|\(\(FIRST\|LAST\)\W\+OCCURRENCE\)\>"
syn match   abapComplexStatement "\<INHERITING\W\+FROM\>"
syn match   abapComplexStatement "\<\(UP\W\+\)\?TO\>"

" hyphenated-word statements
syn match   abapComplexStatement "\<LINE-COUNT\>"
syn match   abapComplexStatement "\<ADD-CORRESPONDING\>"
syn match   abapComplexStatement "\<AUTHORITY-CHECK\>"
syn match   abapComplexStatement "\<BREAK-POINT\>"
syn match   abapComplexStatement "\<CLASS-DATA\>"
syn match   abapComplexStatement "\<CLASS-METHODS\>"
syn match   abapComplexStatement "\<CLASS-METHOD\>"
syn match   abapComplexStatement "\<DIVIDE-CORRESPONDING\>"
syn match   abapComplexStatement "\<EDITOR-CALL\>"
syn match   abapComplexStatement "\<END-OF-DEFINITION\>"
syn match   abapComplexStatement "\<END-OF-PAGE\>"
syn match   abapComplexStatement "\<END-OF-SELECTION\>"
syn match   abapComplexStatement "\<FIELD-GROUPS\>"
syn match   abapComplexStatement "\<FIELD-SYMBOLS\>"
syn match   abapComplexStatement "\<FUNCTION-POOL\>"
syn match   abapComplexStatement "\<IS\W\+\(NOT\W\+\)\?\(ASSIGNED\|BOUND\|INITIAL\|SUPPLIED\)\>"
syn match   abapComplexStatement "\<MOVE-CORRESPONDING\>"
syn match   abapComplexStatement "\<MULTIPLY-CORRESPONDING\>"
syn match   abapComplexStatement "\<NEW-LINE\>"
syn match   abapComplexStatement "\<NEW-PAGE\>"
syn match   abapComplexStatement "\<NEW-SECTION\>"
syn match   abapComplexStatement "\<PRINT-CONTROL\>"
syn match   abapComplexStatement "\<RP-PROVIDE-FROM-LAST\>"
syn match   abapComplexStatement "\<SELECT-OPTIONS\>"
syn match   abapComplexStatement "\<SELECTION-SCREEN\>"
syn match   abapComplexStatement "\<START-OF-SELECTION\>"
syn match   abapComplexStatement "\<SUBTRACT-CORRESPONDING\>"
syn match   abapComplexStatement "\<SYNTAX-CHECK\>"
syn match   abapComplexStatement "\<SYNTAX-TRACE\>"
syn match   abapComplexStatement "\<TOP-OF-PAGE\>"
syn match   abapComplexStatement "\<TYPE-POOL\>"
syn match   abapComplexStatement "\<TYPE-POOLS\>"
syn match   abapComplexStatement "\<LINE-SIZE\>"
syn match   abapComplexStatement "\<LINE-COUNT\>"
syn match   abapComplexStatement "\<MESSAGE-ID\>"
syn match   abapComplexStatement "\<DISPLAY-MODE\>"
syn match   abapComplexStatement "\<READ\(-ONLY\)\?\>"

" ABAP statements
syn keyword abapStatement ADD ALIAS ALIASES ASSERT ASSIGN ASSIGNING AT
syn keyword abapStatement BACK
syn keyword abapStatement CALL CASE CATCH CHECK CLASS CLEAR CLOSE CNT COLLECT COMMIT COMMUNICATION COMPUTE CONCATENATE CONDENSE CONSTANTS CONTINUE CONTROLS CONVERT CREATE CURRENCY
syn keyword abapStatement DATA DEFINE DEFINITION DEFERRED DELETE DESCRIBE DETAIL DIVIDE DO
syn keyword abapStatement ELSE ELSEIF ENDAT ENDCASE ENDCLASS ENDDO ENDEXEC ENDFORM ENDFUNCTION ENDIF ENDIFEND ENDINTERFACE ENDLOOP ENDMETHOD ENDMODULE ENDON ENDPROVIDE ENDSELECT ENDTRY ENDWHILE EVENT EVENTS EXEC EXIT EXPORT EXPORTING EXTRACT
syn keyword abapStatement FETCH FIELDS FORM FORMAT FREE FROM FUNCTION
syn keyword abapStatement GENERATE GET
syn keyword abapStatement HIDE
syn keyword abapStatement IF IMPORT IMPORTING INDEX INFOTYPES INITIALIZATION INTERFACE INTERFACES INPUT INSERT IMPLEMENTATION 
syn keyword abapStatement LEAVE LIKE LINE LOAD LOCAL LOOP
syn keyword abapStatement MESSAGE METHOD METHODS MODIFY MODULE MOVE MULTIPLY
syn keyword abapStatement ON OVERLAY OPTIONAL OTHERS
syn keyword abapStatement PACK PARAMETERS PERFORM POSITION PROGRAM PROVIDE PUT
syn keyword abapStatement RAISE RANGES RECEIVE RECEIVING REDEFINITION REFERENCE REFRESH REJECT REPLACE REPORT RESERVE RESTORE RETURNING ROLLBACK
syn keyword abapStatement SCAN SCROLL SEARCH SELECT SET SHIFT SKIP SORT SORTED SPLIT STANDARD STATICS STEP STOP SUBMIT SUBTRACT SUM SUMMARY SUPPRESS
syn keyword abapStatement TABLES TIMES TRANSFER TRANSLATE TRY TYPE TYPES
syn keyword abapStatement UNASSIGN ULINE UNPACK UPDATE
syn keyword abapStatement WHEN WHILE WINDOW WRITE

" More statemets
syn keyword abapStatement LINES
syn keyword abapStatement INTO GROUP BY HAVING ORDER BY SINGLE
syn keyword abapStatement APPENDING CORRESPONDING FIELDS OF TABLE
syn keyword abapStatement LEFT RIGHT OUTER INNER JOIN AS CLIENT SPECIFIED BYPASSING BUFFER ROWS CONNECTING
syn keyword abapStatement OCCURS STRUCTURE OBJECT PROPERTY
syn keyword abapStatement CASTING APPEND RAISING VALUE COLOR
syn keyword abapStatement CHANGING EXCEPTION EXCEPTIONS DEFAULT CHECKBOX COMMENT
syn keyword abapStatement ID NUMBER FOR TITLE OUTPUT

" Special ABAP specific tables:
syn match   abapSpecialTables "\<\(sy\|\(hrp\|p\|pa\)\d\d\d\d\|t\d\d\d.\|innnn\)-"me=e-1 contained
syn match   abapStructure     "\<\w\+-[^\>]"me=e-2 contains=abapSpecialTables,abapStatement,abapComplexStatement
syn match   abapField         "-\w\+"ms=s+1

" Pointer
syn match   abapSpecial  "<\w\+>"

" Abap common constants:
syn keyword abapSpecial  TRUE FALSE NULL SPACE

" Includes
syn region abapInclude   start="include" end="." contains=abapComment

" Types
syn keyword abapTypes    c n i p f d t x string xstring decfloat16 decfloat34

" Atritmitic operators
syn keyword abapOperator abs sign ceil floor trunc frac acos asin atan cos sin tan
syn keyword abapOperator cosh sinh tanh exp log log10 sqrt

" String operators
syn keyword abapStatement strlen xstrlen charlen numofchar dbmaxlen

syn keyword abapOperator EQ NE LT LE GT GE NOT AND OR XOR IN LIKE BETWEEN

" An error? Not strictly... but cannot think of reason this is intended.
syn match   abapError    "\.\."

" Comments
syn region  abapComment  start="^\*" end="$" contains=abapTodo
syn match   abapComment  "\".*" contains=abapTodo
syn keyword abapTodo     contained TODO NOTE
syn match   abapTodo     "\#EC\W\+\w\+"

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link abapError          Error
hi def link abapComment        Comment
hi def link abapInclude        Include
hi def link abapStatement      Statement
hi def link abapComplexStatement      Statement
hi def link abapSpecial        Special
hi def link abapNamespace      Special
hi def link abapSpecialTables  Special
hi def link abapSymbolOperator abapOperator
hi def link abapOperator       Operator
hi def link abapCharString     String
hi def link abapString         String
hi def link abapFloat          Float
hi def link abapTypes          Type
hi def link abapSymbol         Structure
hi def link abapStructure      Structure
hi def link abapField          Variable
hi def link abapNumber         Number
hi def link abapHex            Number


let b:current_syntax = "abap"

" vim: ts=8 sw=2

