" Vim syntax file
" Language:		Forth
" Maintainer:		Johan Kotlinski <kotlinski@gmail.com>
" Previous Maintainer:	Christian V. J. Brüssow <cvjb@cvjb.de>
" Last Change:		2023 Aug 13
" Filenames:		*.f,*.fs,*.ft,*.fth,*.4th
" URL:			https://github.com/jkotlinski/forth.vim

" Supports the Forth-2012 Standard.
"
" Removed words from the earlier Forth-79, Forth-83 and Forth-94 standards are
" also included.
"
" These have been organised according to the version in which they were
" initially included and the version in which they were removed (obsolescent
" status is ignored).  Words with "experimental" or "uncontrolled" status are
" not included unless they were later standardised.

" quit when a syntax file was already loaded
if exists("b:current_syntax")
    finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Synchronization method
exe "syn sync minlines=" .. get(g:, "forth_minlines", 50)

syn case ignore

" Characters allowed in keywords
" I don't know if 128-255 are allowed in ANS-FORTH
syn iskeyword 33-126,128-255

" Space errors {{{1
" when wanted, highlight trailing white space
if exists("forth_space_errors")
    if !exists("forth_no_trail_space_error")
        syn match forthSpaceError display excludenl "\s\+$"
    endif
    if !exists("forth_no_tab_space_error")
        syn match forthSpaceError display " \+\t"me=e-1
    endif
endif

" Core words {{{1

" basic mathematical and logical operators {{{2
syn keyword forthOperators * */ */MOD + - / /MOD 0< 0= 1+ 1- 2* 2/ < = > ABS
syn keyword forthOperators AND FM/MOD INVERT LSHIFT M* MAX MIN MOD NEGATE OR
syn keyword forthOperators RSHIFT SM/REM U< UM* UM/MOD XOR
  " extension words
syn keyword forthOperators 0<> 0> <> U> WITHIN
  " Forth-79
syn keyword forthOperators U* U/ U/MOD
  " Forth-79, Forth-83
syn keyword forthOperators NOT
  " Forth-83
syn keyword forthOperators 2+ 2-

" non-standard basic mathematical and logical operators
syn keyword forthOperators 0<= 0>= 8* <= >= ?DNEGATE ?NEGATE U<= U>= UNDER+

" various words that take an input and do something with it {{{2
syn keyword forthFunction . U.
  " extension words
syn keyword forthFunction .R U.R

" stack manipulations {{{2
syn keyword forthStack 2DROP 2DUP 2OVER 2SWAP >R ?DUP DROP DUP OVER R> R@ ROT
syn keyword forthStack SWAP
  " extension words
syn keyword forthStack  NIP PICK ROLL TUCK
syn keyword forthRStack 2>R 2R> 2R@

" non-standard stack manipulations
syn keyword forthStack  -ROT 3DROP 3DUP 4-ROT 4DROP 4DUP 4ROT 4SWAP 4TUCK
syn keyword forthStack  5DROP 5DUP 8DROP 8DUP 8SWAP
syn keyword forthRStack 4>R 4R> 4R@ 4RDROP RDROP

" stack pointer manipulations {{{2
syn keyword forthSP DEPTH

" non-standard stack pointer manipulations
syn keyword forthSP FP!  FP@ LP!  LP@ RP!  RP@ SP!  SP@

" address operations {{{2
syn keyword forthMemory !  +!  2!  2@ @ C!  C@
syn keyword forthAdrArith ALIGN ALIGNED ALLOT CELL+ CELLS CHAR+ CHARS
syn keyword forthMemBlks  FILL MOVE
  " extension words
syn keyword forthMemBlks  ERASE UNUSED

" non-standard address operations
syn keyword forthAdrArith ADDRESS-UNIT-BITS CELL CFALIGN CFALIGNED FLOAT
syn keyword forthAdrArith MAXALIGN MAXALIGNED

" conditionals {{{2
syn keyword forthCond ELSE IF THEN
  " extension words
syn keyword forthCond CASE ENDCASE ENDOF OF

" non-standard conditionals
syn keyword forthCond ?DUP-0=-IF ?DUP-IF ENDIF

" iterations {{{2
syn keyword forthLoop +LOOP BEGIN DO EXIT I J LEAVE LOOP RECURSE REPEAT UNLOOP
syn keyword forthLoop UNTIL WHILE
  " extension words
syn keyword forthLoop ?DO AGAIN

" non-standard iterations
syn keyword forthLoop +DO -DO -LOOP ?LEAVE DONE FOR K NEXT U+DO U-DO

" new words {{{2
syn match   forthColonDef      "\<:\s*[^ \t]\+\>"
syn keyword forthEndOfColonDef ;
syn keyword forthDefine ' , C, CONSTANT CREATE DOES> EXECUTE IMMEDIATE LITERAL
syn keyword forthDefine POSTPONE STATE VARIABLE ]
syn match   forthDefine "\<\[']\>"
syn match   forthDefine "\<\[\>"
  " extension words
syn keyword forthColonDef :NONAME
syn keyword forthDefine   BUFFER: COMPILE, DEFER IS MARKER TO VALUE
syn match   forthDefine   "\<\[COMPILE]\>"
  " Forth-79, Forth-83
syn keyword forthDefine COMPILE

" non-standard new words
syn match   forthClassDef       "\<:CLASS\s*[^ \t]\+\>"
syn keyword forthEndOfClassDef  ;CLASS
syn match   forthObjectDef      "\<:OBJECT\s*[^ \t]\+\>"
syn keyword forthEndOfObjectDef ;OBJECT
syn match   forthColonDef       "\<:M\s*[^ \t]\+\>"
syn keyword forthEndOfColonDef  ;M
syn keyword forthDefine 2, <BUILDS <COMPILATION <INTERPRETATION C; COMP'
syn keyword forthDefine COMPILATION> COMPILE-ONLY CREATE-INTERPRET/COMPILE
syn keyword forthDefine CVARIABLE F, FIND-NAME INTERPRET INTERPRETATION>
syn keyword forthDefine LASTXT NAME>COMP NAME>INT NAME?INT POSTPONE, RESTRICT
syn keyword forthDefine USER
syn match   forthDefine "\<\[COMP']\>"

" basic character operations {{{2
syn keyword forthCharOps BL COUNT CR EMIT FIND KEY SPACE SPACES TYPE WORD
" recognize 'char (' or '[CHAR] (' correctly, so it doesn't
" highlight everything after the paren as a comment till a closing ')'
syn match forthCharOps '\<CHAR\s\S\s'
syn match forthCharOps '\<\[CHAR]\s\S\s'
  " Forth-83, Forth-94
syn keyword forthCharOps EXPECT #TIB TIB

" non-standard basic character operations
syn keyword forthCharOps (.)

" char-number conversion {{{2
syn keyword forthConversion # #> #S <# >NUMBER HOLD S>D SIGN
  " extension words
syn keyword forthConversion HOLDS
  " Forth-79, Forth-83, Forth-93
syn keyword forthConversion CONVERT

" non-standard char-number conversion
syn keyword forthConversion #>> (NUMBER) (NUMBER?) <<# DIGIT DPL HLD NUMBER

" interpreter, wordbook, compiler {{{2
syn keyword forthForth >BODY >IN ACCEPT ENVIRONMENT?  EVALUATE HERE QUIT SOURCE
  " extension words
syn keyword forthForth ACTION-OF DEFER!  DEFER@ PAD PARSE PARSE-NAME REFILL
syn keyword forthForth RESTORE-INPUT SAVE-INPUT SOURCE-ID
  " Forth-79
syn keyword forthForth 79-STANDARD
  " Forth-83
syn keyword forthForth <MARK <RESOLVE >MARK >RESOLVE ?BRANCH BRANCH FORTH-83
  " Forth-79, Forth-83, Forth-94
syn keyword forthForth QUERY
  " Forth-83, Forth-94
syn keyword forthForth SPAN

" non-standard interpreter, wordbook, compiler
syn keyword forthForth ) >LINK >NEXT >VIEW ASSERT( ASSERT0( ASSERT1( ASSERT2(
syn keyword forthForth ASSERT3( BODY> CFA COLD L>NAME LINK> N>LINK NAME> VIEW
syn keyword forthForth VIEW>

" booleans {{{2
  " extension words
syn match forthBoolean "\<\%(TRUE\|FALSE\)\>"

" numbers {{{2
syn keyword forthMath  BASE DECIMAL
  " extension words
syn keyword forthMath  HEX
syn match forthInteger '\<-\=\d\+\.\=\>'
syn match forthInteger '\<#-\=\d\+\.\=\>'
syn match forthInteger '\<\$-\=\x\+\.\=\>'
syn match forthInteger '\<%-\=[01]\+\.\=\>'

" characters {{{2
syn match forthCharacter "'\k'"

" strings {{{2

" Words that end with " are assumed to start string parsing.
" This includes standard words: S" ."
syn region forthString matchgroup=forthString start=+\<\S\+"\s+ end=+"+ end=+$+ contains=@Spell
  " extension words
syn region forthString matchgroup=forthString start=+\<C"\s+ end=+"+ end=+$+ contains=@Spell
" Matches S\"
syn region forthString matchgroup=forthString start=+\<S\\"\s+ end=+"+ end=+$+ contains=@Spell,forthEscape

syn match forthEscape +\C\\[abeflmnqrtvz"\\]+ contained
syn match forthEscape "\C\\x\x\x" contained

" comments {{{2

syn keyword forthTodo contained TODO FIXME XXX

" Some special, non-FORTH keywords
syn match forthTodo contained "\<\%(TODO\|FIXME\|XXX\)\%(\>\|:\@=\)"

" XXX If you find this overkill you can remove it. This has to come after the
" highlighting for numbers and booleans otherwise it has no effect.
syn region forthComment start='\<\%(0\|FALSE\)\s\+\[IF]' end='\<\[ENDIF]' end='\<\[THEN]' contains=forthTodo

if get(g:, "forth_no_comment_fold", 0)
    syn region forthComment start='\<(\>' end=')' contains=@Spell,forthTodo,forthSpaceError
      " extension words
    syn match  forthComment '\<\\\>.*$' contains=@Spell,forthTodo,forthSpaceError
else
    syn region forthComment start='\<(\>' end=')' contains=@Spell,forthTodo,forthSpaceError fold
      " extension words
    syn match  forthComment '\<\\\>.*$' contains=@Spell,forthTodo,forthSpaceError
    syn region forthMultilineComment start="^\s*\\\>" end="\n\%(\s*\\\>\)\@!" contains=forthComment transparent fold
endif

  " extension words
syn region forthComment start='\<\.(\>' end=')' end='$' contains=@Spell,forthTodo,forthSpaceError

" ABORT {{{2
syn keyword forthForth ABORT
syn region forthForth start=+\<ABORT"\s+ end=+"\>+ end=+$+

" The optional Block word set {{{1
" Handled as Core words - REFILL
syn keyword forthBlocks BLK BLOCK BUFFER FLUSH LOAD SAVE-BUFFERS UPDATE
  " extension words
syn keyword forthBlocks EMPTY-BUFFERS LIST SCR THRU

" Non-standard Block words
syn keyword forthBlocks +LOAD +THRU --> BLOCK-INCLUDED BLOCK-OFFSET
syn keyword forthBlocks BLOCK-POSITION EMPTY-BUFFER GET-BLOCK-FID OPEN-BLOCKS
syn keyword forthBlocks SAVE-BUFFER UPDATED? USE

" The optional Double-Number word set {{{1
syn keyword forthConversion D>S
syn keyword forthDefine     2CONSTANT 2LITERAL 2VARIABLE
syn keyword forthFunction   D. D.R
syn keyword forthOperators  D+ D- D0= D2* D2/ D= DABS DMAX DMIN DNEGATE
syn keyword forthOperators  D0< D< M+ M*/
  " extension words
syn keyword forthDefine    2VALUE
syn keyword forthOperators DU<
syn keyword forthStack     2ROT

" Non-standard Double-Number words
syn keyword forthOperators D0<= D0<> D0> D0>= D<= D<> D> D>= DU<= DU> DU>=
syn keyword forthStack     2-ROT 2NIP 2RDROP 2TUCK

" The optional Exception word set {{{1
" Handled as Core words - ABORT ABORT"
syn keyword forthCond CATCH THROW

" The optional Facility word set {{{1
syn keyword forthCharOps AT-XY KEY?  PAGE
  " extension words
syn keyword forthCharOps EKEY EKEY>CHAR EKEY>FKEY EKEY?  EMIT?  K-ALT-MASK
syn keyword forthCharOps K-CTRL-MASK K-DELETE K-DOWN K-END K-F1 K-F10 K-F11
syn keyword forthCharOps K-F12 K-F2 K-F3 K-F4 K-F5 K-F6 K-F7 K-F8 K-F9 K-HOME
syn keyword forthCharOps K-INSERT K-LEFT K-NEXT K-PRIOR K-RIGHT K-SHIFT-MASK
syn keyword forthCharOps K-UP
syn keyword forthDefine  +FIELD BEGIN-STRUCTURE CFIELD: END-STRUCTURE FIELD:
syn keyword forthForth   MS TIME&DATE

" The optional File-Access word set {{{1
" Handled as Core words - REFILL SOURCE-ID S\" S" (
syn keyword forthFileMode  BIN R/O R/W W/O
syn keyword forthFileWords CLOSE-FILE CREATE-FILE DELETE-FILE FILE-POSITION
syn keyword forthFileWords FILE-SIZE INCLUDE-FILE INCLUDED OPEN-FILE READ-FILE
syn keyword forthFileWords READ-LINE REPOSITION-FILE RESIZE-FILE WRITE-FILE
syn keyword forthFileWords WRITE-LINE
  " extension words
syn keyword forthFileWords FILE-STATUS FLUSH-FILE RENAME-FILE REQUIRED
syn match forthInclude '\<INCLUDE\s\+\k\+'
syn match forthInclude '\<REQUIRE\s\+\k\+'

" Non-standard File-Access words
syn keyword forthFileWords EMIT-FILE KEY-FILE KEY?-FILE SLURP-FID SLURP-FILE
syn keyword forthFileWords STDERR STDIN STDOUT
syn match forthInclude '^FLOAD\s\+'
syn match forthInclude '^NEEDS\s\+'

" The optional Floating-Point word set {{{1

" numbers
syn match   forthFloat      '\<[+-]\=\d\+\.\=\d*[DdEe][+-]\=\d*\>'

syn keyword forthConversion >FLOAT D>F F>D
syn keyword forthAdrArith   FALIGN FALIGNED FLOAT+ FLOATS
syn keyword forthDefine     FCONSTANT FLITERAL FVARIABLE
syn keyword forthFStack     FDROP FDUP FOVER FROT FSWAP
syn keyword forthFunction   REPRESENT
syn keyword forthMemory     F! F@
syn keyword forthOperators  F* F+ F- F/ F0< F0= F< FLOOR FMAX FMIN FNEGATE
syn keyword forthOperators  FROUND
syn keyword forthSP         FDEPTH
  " extension words
syn keyword forthConversion F>S S>F
syn keyword forthAdrArith   DFALIGN DFALIGNED DFLOAT+ DFLOATS SFALIGN
syn keyword forthAdrArith   SFALIGNED SFLOAT+ SFLOATS
syn keyword forthDefine     DFFIELD: FFIELD: FVALUE SFFIELD:
syn keyword forthFunction   F. FE. FS. PRECISION SET-PRECISION
syn keyword forthMemory     DF! DF@ SF! SF@
syn keyword forthOperators  F** FABS FACOS FACOSH FALOG FASIN FASINH FATAN
syn keyword forthOperators  FATAN2 FATANH FCOS FCOSH FEXP FEXPM1 FLN FLNP1
syn keyword forthOperators  FLOG FSIN FSINCOS FSINH FSQRT FTAN FTANH FTRUNC F~

" Non-standard Floating-Point words
syn keyword forthOperators 1/F F2* F2/ F~ABS F~REL
syn keyword forthFStack    FNIP FTUCK

" The optional Locals word set {{{1
syn keyword forthForth (LOCAL)
  " extension words
syn region forthLocals start="\<{:\>" end="\<:}\>"
syn region forthLocals start="\<LOCALS|\>" end="\<|\>"

" Non-standard Locals words
syn region forthLocals start="\<{\>" end="\<}\>"

" The optional Memory-Allocation word set {{{1
syn keyword forthMemory ALLOCATE FREE RESIZE

" The optional Programming-Tools wordset {{{1
syn keyword forthDebug .S ? DUMP SEE WORDS
  " extension words
syn keyword forthAssembler ;CODE ASSEMBLER CODE END-CODE
syn keyword forthCond      AHEAD CS-PICK CS-ROLL
syn keyword forthDefine    NAME>COMPILE NAME>INTERPRET NAME>STRING SYNONYM
syn keyword forthDefine    TRAVERSE-WORDLIST
syn match   forthDefine    "\<\[DEFINED]\>"
syn match   forthDefine    "\<\[ELSE]\>"
syn match   forthDefine    "\<\[IF]\>"
syn match   forthDefine    "\<\[THEN]\>"
syn match   forthDefine    "\<\[UNDEFINED]\>"
syn keyword forthForth     BYE FORGET
syn keyword forthStack     N>R NR>
syn keyword forthVocs      EDITOR

" Non-standard Programming-Tools words
syn keyword forthAssembler FLUSH-ICACHE
syn keyword forthDebug     PRINTDEBUGDATA PRINTDEBUGLINE
syn match   forthDebug     "\<\~\~\>"
syn match   forthDefine    "\<\[+LOOP]\>"
syn match   forthDefine    "\<\[?DO]\>"
syn match   forthDefine    "\<\[AGAIN]\>"
syn match   forthDefine    "\<\[BEGIN]\>"
syn match   forthDefine    "\<\[DO]\>"
syn match   forthDefine    "\<\[ENDIF]\>"
syn match   forthDefine    "\<\[IFDEF]\>"
syn match   forthDefine    "\<\[IFUNDEF]\>"
syn match   forthDefine    "\<\[LOOP]\>"
syn match   forthDefine    "\<\[NEXT]\>"
syn match   forthDefine    "\<\[REPEAT]\>"
syn match   forthDefine    "\<\[UNTIL]\>"
syn match   forthDefine    "\<\[WHILE]\>"

" The optional Search-Order word set {{{1
" Handled as Core words - FIND
syn keyword forthVocs DEFINITIONS FORTH-WORDLIST GET-CURRENT GET-ORDER
syn keyword forthVocs SEARCH-WORDLIST SET-CURRENT SET-ORDER WORDLIST
  " extension words
syn keyword forthVocs ALSO FORTH ONLY ORDER PREVIOUS
  " Forth-79, Forth-83
syn keyword forthVocs CONTEXT CURRENT VOCABULARY

" Non-standard Search-Order words
syn keyword forthVocs #VOCS ROOT SEAL VOCS

" The optional String word set {{{1
syn keyword forthFunction -TRAILING /STRING BLANK CMOVE CMOVE> COMPARE SEARCH
syn keyword forthFunction SLITERAL
  " extension words
syn keyword forthFunction REPLACES SUBSTITUTE UNESCAPE

" The optional Extended-Character word set {{{1
" Handled as Core words - [CHAR] CHAR and PARSE
syn keyword forthAdrArith XCHAR+
syn keyword forthCharOps  X-SIZE XC-SIZE XEMIT XKEY XKEY?
syn keyword forthDefine   XC,
syn keyword forthMemory   XC!+ XC!+? XC@+
  " extension words
syn keyword forthAdrArith   XCHAR- +X/STRING X\\STRING-
syn keyword forthCharOps    EKEY>XCHAR X-WIDTH XC-WIDTH
syn keyword forthConversion XHOLD
syn keyword forthString     -TRAILING-GARBAGE

" Define the default highlighting {{{1
hi def link forthBoolean Boolean
hi def link forthCharacter Character
hi def link forthTodo Todo
hi def link forthOperators Operator
hi def link forthMath Number
hi def link forthInteger Number
hi def link forthFloat Float
hi def link forthStack Special
hi def link forthRstack Special
hi def link forthFStack Special
hi def link forthSP Special
hi def link forthMemory Function
hi def link forthAdrArith Function
hi def link forthMemBlks Function
hi def link forthCond Conditional
hi def link forthLoop Repeat
hi def link forthColonDef Define
hi def link forthEndOfColonDef Define
hi def link forthDefine Define
hi def link forthDebug Debug
hi def link forthAssembler Include
hi def link forthCharOps Character
hi def link forthConversion String
hi def link forthForth Statement
hi def link forthVocs Statement
hi def link forthEscape Special
hi def link forthString String
hi def link forthComment Comment
hi def link forthClassDef Define
hi def link forthEndOfClassDef Define
hi def link forthObjectDef Define
hi def link forthEndOfObjectDef Define
hi def link forthInclude Include
hi def link forthLocals Type " nothing else uses type and locals must stand out
hi def link forthFileMode Function
hi def link forthFunction Function
hi def link forthFileWords Statement
hi def link forthBlocks Statement
hi def link forthSpaceError Error
"}}}

let b:current_syntax = "forth"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim:ts=8:sw=4:nocindent:smartindent:fdm=marker:tw=78

