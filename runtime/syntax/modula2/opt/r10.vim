" Vim syntax file
" Language:    Modula-2 (R10)
" Maintainer:  B.Kowarsch <trijezdci@moc.liamg>
" Last Change: 2020 June 18 (moved repository from bb to github)

" ----------------------------------------------------
" THIS FILE IS LICENSED UNDER THE VIM LICENSE
" see https://github.com/vim/vim/blob/master/LICENSE
" ----------------------------------------------------

" Remarks:
" Vim Syntax files are available for the following Modula-2 dialects:
" * for the PIM dialect : m2pim.vim
" * for the ISO dialect : m2iso.vim
" * for the R10 dialect : m2r10.vim (this file)

" -----------------------------------------------------------------------------
" This syntax description follows the Modula-2 Revision 2010 language report
" (Kowarsch and Sutcliffe, 2015) available at http://modula-2.info/m2r10.
" -----------------------------------------------------------------------------

" Parameters:
"
" Vim's filetype script recognises Modula-2 dialect tags within the first 200
" lines of Modula-2 .def and .mod input files.  The script sets filetype and
" dialect automatically when a valid dialect tag is found in the input file.
" The dialect tag for the R10 dialect is (*!m2r10*).  It is recommended to put
" the tag immediately after the module header in the Modula-2 input file.
"
" Example:
"  DEFINITION MODULE Foolib; (*!m2r10*)
"
" Variable g:modula2_default_dialect sets the default Modula-2 dialect when the
" dialect cannot be determined from the contents of the Modula-2 input file:
" if defined and set to 'm2r10', the default dialect is R10.
"
" Variable g:modula2_r10_allow_lowline controls support for lowline in identifiers:
" if defined and set to a non-zero value, they are recognised, otherwise not
"
" Variables may be defined in Vim startup file .vimrc
"
" Examples:
"  let g:modula2_default_dialect = 'm2r10'
"  let g:modula2_r10_allow_lowline = 1


if exists("b:current_syntax")
  finish
endif

" Modula-2 is case sensitive
syn case match


" -----------------------------------------------------------------------------
" Reserved Words
" -----------------------------------------------------------------------------
" Note: MODULE, PROCEDURE and END are defined separately further below
syn keyword modula2Resword ALIAS AND ARGLIST ARRAY BEGIN CASE CONST COPY DEFINITION
syn keyword modula2Resword DIV DO ELSE ELSIF EXIT FOR FROM GENLIB IF IMPLEMENTATION
syn keyword modula2Resword IMPORT IN LOOP MOD NEW NOT OF OPAQUE OR POINTER READ
syn keyword modula2Resword RECORD RELEASE REPEAT RETAIN RETURN SET THEN TO TYPE
syn keyword modula2Resword UNTIL VAR WHILE WRITE YIELD


" -----------------------------------------------------------------------------
" Schroedinger's Tokens
" -----------------------------------------------------------------------------
syn keyword modula2SchroedToken CAPACITY COROUTINE LITERAL


" -----------------------------------------------------------------------------
" Builtin Constant Identifiers
" -----------------------------------------------------------------------------
syn keyword modula2ConstIdent NIL FALSE TRUE


" -----------------------------------------------------------------------------
" Builtin Type Identifiers
" -----------------------------------------------------------------------------
syn keyword modula2TypeIdent BOOLEAN CHAR UNICHAR OCTET
syn keyword modula2TypeIdent CARDINAL LONGCARD INTEGER LONGINT REAL LONGREAL


" -----------------------------------------------------------------------------
" Builtin Procedure and Function Identifiers
" -----------------------------------------------------------------------------
syn keyword modula2ProcIdent APPEND INSERT REMOVE SORT SORTNEW
syn keyword modula2FuncIdent CHR ORD ODD ABS SGN MIN MAX LOG2 POW2 ENTIER
syn keyword modula2FuncIdent PRED SUCC PTR COUNT LENGTH


" -----------------------------------------------------------------------------
" Builtin Macro Identifiers
" -----------------------------------------------------------------------------
syn keyword modula2MacroIdent NOP TMIN TMAX TSIZE TLIMIT


" -----------------------------------------------------------------------------
" Builtin Primitives
" -----------------------------------------------------------------------------
syn keyword modula2PrimitiveIdent SXF VAL STORE VALUE SEEK SUBSET


" -----------------------------------------------------------------------------
" Unsafe Facilities via Pseudo-Module UNSAFE
" -----------------------------------------------------------------------------
syn keyword modula2UnsafeIdent UNSAFE BYTE WORD LONGWORD OCTETSEQ
syn keyword modula2UnsafeIdent ADD SUB INC DEC SETBIT HALT
syn keyword modula2UnsafeIdent ADR CAST BIT SHL SHR BWNOT BWAND BWOR


" -----------------------------------------------------------------------------
" Non-Portable Language Extensions
" -----------------------------------------------------------------------------
syn keyword modula2NonPortableIdent ASSEMBLER ASM REG


" -----------------------------------------------------------------------------
" User Defined Identifiers
" -----------------------------------------------------------------------------
syn match modula2Ident "[a-zA-Z][a-zA-Z0-9]*\(_\)\@!"
syn match modula2LowLineIdent "[a-zA-Z][a-zA-Z0-9]*\(_[a-zA-Z0-9]\+\)\+"

syn match modula2ReswordDo "\(TO\)\@<!DO"
syn match modula2ReswordTo "TO\(\sDO\)\@!"

" TODO: support for OpenVMS reswords and identifiers which may include $ and %


" -----------------------------------------------------------------------------
" String Literals
" -----------------------------------------------------------------------------
syn region modula2String start=/"/ end=/"/ oneline
syn region modula2String start="\(^\|\s\|[({=<>&#,]\|\[\)\@<='" end=/'/ oneline


" -----------------------------------------------------------------------------
" Numeric Literals
" -----------------------------------------------------------------------------
syn match modula2Base2Num "0b[01]\+\('[01]\+\)*"
syn match modula2Base16Num "0[ux][0-9A-F]\+\('[0-9A-F]\+\)*"

"| *** VMSCRIPT BUG ALERT ***
"| The regular expression below causes errors when split into separate strings
"|
"| syn match modula2Base10Num
"|   \ "\(\(0[bux]\@!\|[1-9]\)[0-9]*\('[0-9]\+\)*\)" .
"|   \ "\(\.[0-9]\+\('[0-9]\+\)*\(e[+-]\?[0-9]\+\('[0-9]\+\)*\)\?\)\?"
"|
"| E475: Invalid argument: modula2Base10Num "\(\(0[bux]\@!\|[1-9]\)[0-9]*\('[0-9]\+\)*\)"
"|  . "\(\.[0-9]\+\('[0-9]\+\)*\(e[+-]\?[0-9]\+\('[0-9]\+\)*\)\?\)\?"
"|
"| However, the same regular expression works just fine as a sole string.
"|
"| As a consequence, we have no choice but to put it all into a single line
"| which greatly diminishes readability and thereby increases the opportunity
"| for error during maintenance. Ideally, regular expressions should be split
"| into small human readable pieces with interleaved comments that explain
"| precisely what each piece is doing.  Vimscript imposes poor design. :-(

syn match modula2Base10Num
  \ "\(\(0[bux]\@!\|[1-9]\)[0-9]*\('[0-9]\+\)*\)\(\.[0-9]\+\('[0-9]\+\)*\(e[+-]\?[0-9]\+\('[0-9]\+\)*\)\?\)\?"


" -----------------------------------------------------------------------------
" Punctuation
" -----------------------------------------------------------------------------
syn match modula2Punctuation
  \ "\.\|[,:;]\|\*\|[/+-]\|\#\|[=<>&]\|\^\|\[\|\]\|(\(\*\)\@!\|[){}]"


" -----------------------------------------------------------------------------
" Pragmas
" -----------------------------------------------------------------------------
syn region modula2Pragma start="<\*" end="\*>"
  \ contains = modula2PragmaKey, modula2TechDebtPragma
syn keyword modula2PragmaKey contained MSG IF ELSIF ELSE END INLINE NOINLINE OUT
syn keyword modula2PragmaKey contained GENERATED ENCODING ALIGN PADBITS NORETURN
syn keyword modula2PragmaKey contained PURITY SINGLEASSIGN LOWLATENCY VOLATILE
syn keyword modula2PragmaKey contained FORWARD ADDR FFI FFIDENT

syn match modula2DialectTag "(\*!m2r10\(+[a-z0-9]\+\)\?\*)"


" -----------------------------------------------------------------------------
" Line Comments
" -----------------------------------------------------------------------------
syn region modula2Comment start=/^!/ end=/$/ oneline


" -----------------------------------------------------------------------------
" Block Comments
" -----------------------------------------------------------------------------
syn region modula2Comment
  \ start="\(END\s\)\@<!(\*\(!m2r10\(+[a-z0-9]\+\)\?\*)\)\@!" end="\*)"
  \ contains = modula2Comment, modula2CommentKey, modula2TechDebtMarker

syn match modula2CommentKey
  \ "[Aa]uthor[s]\?\|[Cc]opyright\|[Ll]icense\|[Ss]ynopsis" contained
syn match modula2CommentKey
  \ "\([Pp]re\|[Pp]ost\|[Ee]rror\)\-condition[s]\?:" contained


" -----------------------------------------------------------------------------
" Block Statement Tails
" -----------------------------------------------------------------------------
syn match modula2ReswordEnd
  \ "END" nextgroup = modula2StmtTailComment skipwhite
syn match modula2StmtTailComment
  \ "(\*\s\(IF\|CASE\|FOR\|LOOP\|WHILE\)\s\*)" contained


" -----------------------------------------------------------------------------
" Technical Debt Markers
" -----------------------------------------------------------------------------
syn match modula2ToDoHeader "TO DO"

syn match modula2ToDoTail
  \ "END\(\s(\*\sTO DO\s\*)\)\@=" nextgroup = modula2ToDoTailComment skipwhite
syntax match modula2ToDoTailComment "(\*\sTO DO\s\*)" contained

" contained within pragma
syn keyword modula2TechDebtPragma contained DEPRECATED

" contained within comment
syn keyword modula2TechDebtMarker contained FIXME


" -----------------------------------------------------------------------------
" Disabled Code Sections
" -----------------------------------------------------------------------------
syn region modula2DisabledCode start="^?<" end="^>?"


" -----------------------------------------------------------------------------
" Headers
" -----------------------------------------------------------------------------
" !!! this section must be second last !!!

" module header
syn match modula2ModuleHeader
  \ "\(MODULE\|BLUEPRINT\)\( [A-Z][a-zA-Z0-9]*\)\?"
  \ contains = modula2ReswordModule, modula2ReswordBlueprint, modula2ModuleIdent

syn match modula2ModuleIdent
  \ "[A-Z][a-zA-Z0-9]*" contained

syn match modula2ModuleTail
  \ "END [A-Z][a-zA-Z0-9]*\.$"
  \ contains = modula2ReswordEnd, modula2ModuleIdent, modula2Punctuation

" procedure, sole occurrence
syn match modula2ProcedureHeader
  \ "PROCEDURE\(\s\[\|\s[a-zA-Z]\)\@!" contains = modula2ReswordProcedure

" procedure header
syn match modula2ProcedureHeader
  \ "PROCEDURE [a-zA-Z][a-zA-Z0-9]*\(_[a-zA-Z0-9]\+\)*"
  \ contains = modula2ReswordProcedure,
  \ modula2ProcedureIdent, modula2ProcedureLowlineIdent, modula2IllegalChar, modula2IllegalIdent

" procedure binding to operator
syn match modula2ProcedureHeader
  \ "PROCEDURE \[[+-\*/\\=<>]\] [a-zA-Z][a-zA-Z0-9]*\(_[a-zA-Z0-9]\+\)*"
  \ contains = modula2ReswordProcedure, modula2Punctuation,
  \ modula2ProcedureIdent, modula2ProcedureLowlineIdent, modula2IllegalChar, modula2IllegalIdent

" procedure binding to builtin
syn match modula2ProcedureHeader
  \ "PROCEDURE \[[A-Z]\+\(:\([#\*,]\|++\|--\)\?\)\?\] [a-zA-Z][a-zA-Z0-9]*\(_[a-zA-Z0-9]\+\)*"
  \ contains = modula2ReswordProcedure,
  \ modula2Punctuation, modula2Resword, modula2SchroedToken,
  \ modula2ProcIdent, modula2FuncIdent, modula2PrimitiveIdent,
  \ modula2ProcedureIdent, modula2ProcedureLowlineIdent, modula2IllegalChar, modula2IllegalIdent

syn match modula2ProcedureIdent
  \ "\([a-zA-Z]\)\([a-zA-Z0-9]*\)" contained

syn match modula2ProcedureLowlineIdent
  \ "[a-zA-Z][a-zA-Z0-9]*\(_[a-zA-Z0-9]\+\)\+" contained

syn match modula2ProcedureTail
  \ "END [a-zA-Z][a-zA-Z0-9]*\(_[a-zA-Z0-9]\+\)*;$"
  \ contains = modula2ReswordEnd,
  \ modula2ProcedureIdent, modula2ProcedureLowLineIdent,
  \ modula2Punctuation, modula2IllegalChar, modula2IllegalIdent

syn keyword modula2ReswordModule contained MODULE
syn keyword modula2ReswordBlueprint contained BLUEPRINT
syn keyword modula2ReswordProcedure contained PROCEDURE
syn keyword modula2ReswordEnd contained END


" -----------------------------------------------------------------------------
" Illegal Symbols
" -----------------------------------------------------------------------------
" !!! this section must be last !!!

" any '`' '~' '@' '$' '%'
syn match modula2IllegalChar "[`~@$%]"

" any solitary sequence of '_'
syn match modula2IllegalChar "\<_\+\>"

" any '?' at start of line if not followed by '<'
syn match modula2IllegalChar "^?\(<\)\@!"

" any '?' not following '>' at start of line
syn match modula2IllegalChar "\(\(^>\)\|\(^\)\)\@<!?"

" any identifiers with leading occurrences of '_'
syn match modula2IllegalIdent "_\+[a-zA-Z][a-zA-Z0-9]*\(_\+[a-zA-Z0-9]*\)*"

" any identifiers containing consecutive occurences of '_'
syn match modula2IllegalIdent
  \ "[a-zA-Z][a-zA-Z0-9]*\(_[a-zA-Z0-9]\+\)*\(__\+[a-zA-Z0-9]\+\(_[a-zA-Z0-9]\+\)*\)\+"

" any identifiers with trailing occurrences of '_'
syn match modula2IllegalIdent "[a-zA-Z][a-zA-Z0-9]*\(_\+[a-zA-Z0-9]\+\)*_\+\>"


" -----------------------------------------------------------------------------
" Define Rendering Styles
" -----------------------------------------------------------------------------

" highlight default link modula2PredefIdentStyle Keyword
" highlight default link modula2ConstIdentStyle modula2PredefIdentStyle
" highlight default link modula2TypeIdentStyle modula2PredefIdentStyle
" highlight default link modula2ProcIdentStyle modula2PredefIdentStyle
" highlight default link modula2FuncIdentStyle modula2PredefIdentStyle
" highlight default link modula2MacroIdentStyle modula2PredefIdentStyle

highlight default link modula2ConstIdentStyle Constant
highlight default link modula2TypeIdentStyle Type
highlight default link modula2ProcIdentStyle Function
highlight default link modula2FuncIdentStyle Function
highlight default link modula2MacroIdentStyle Function
highlight default link modula2PrimitiveIdentStyle Function
highlight default link modula2UnsafeIdentStyle Question
highlight default link modula2NonPortableIdentStyle Question
highlight default link modula2StringLiteralStyle String
highlight default link modula2CommentStyle Comment
highlight default link modula2PragmaStyle PreProc
highlight default link modula2PragmaKeyStyle PreProc
highlight default link modula2DialectTagStyle SpecialComment
highlight default link modula2TechDebtMarkerStyle SpecialComment
highlight default link modula2ReswordStyle Keyword
highlight default link modula2HeaderIdentStyle Function
highlight default link modula2UserDefIdentStyle Normal
highlight default link modula2NumericLiteralStyle Number
highlight default link modula2PunctuationStyle Delimiter
highlight default link modula2CommentKeyStyle SpecialComment
highlight default link modula2DisabledCodeStyle NonText


" -----------------------------------------------------------------------------
" Assign Rendering Styles
" -----------------------------------------------------------------------------

" headers
highlight default link modula2ModuleIdent modula2HeaderIdentStyle
highlight default link modula2ProcedureIdent modula2HeaderIdentStyle
highlight default link modula2ModuleHeader modula2HeaderIdentStyle
highlight default link modula2ModuleTail Normal
highlight default link modula2ProcedureHeader Normal
highlight default link modula2ProcedureTail Normal

" lowline identifiers are rendered as errors if g:modula2_r10_allow_lowline is unset
if exists("g:modula2_r10_allow_lowline")
  if g:modula2_r10_allow_lowline != 0
    highlight default link modula2ProcedureLowlineIdent modula2HeaderIdentStyle
  else
    highlight default link modula2ProcedureLowlineIdent Error
  endif
else
  highlight default link modula2ProcedureLowlineIdent modula2HeaderIdentStyle
endif

" reserved words
highlight default link modula2Resword modula2ReswordStyle
highlight default link modula2ReswordModule modula2ReswordStyle
highlight default link modula2ReswordProcedure modula2ReswordStyle
highlight default link modula2ReswordEnd modula2ReswordStyle
highlight default link modula2ReswordDo modula2ReswordStyle
highlight default link modula2ReswordTo modula2ReswordStyle
highlight default link modula2SchroedToken modula2ReswordStyle

" predefined identifiers
highlight default link modula2ConstIdent modula2ConstIdentStyle
highlight default link modula2TypeIdent modula2TypeIdentStyle
highlight default link modula2ProcIdent modula2ProcIdentStyle
highlight default link modula2FuncIdent modula2FuncIdentStyle
highlight default link modula2MacroIdent modula2MacroIdentStyle
highlight default link modula2PrimitiveIdent modula2PrimitiveIdentStyle

" unsafe and non-portable identifiers
highlight default link modula2UnsafeIdent modula2UnsafeIdentStyle
highlight default link modula2NonPortableIdent modula2NonPortableIdentStyle

" user defined identifiers
highlight default link modula2Ident modula2UserDefIdentStyle

" lowline identifiers are rendered as errors if g:modula2_r10_allow_lowline is unset
if exists("g:modula2_r10_allow_lowline")
  if g:modula2_r10_allow_lowline != 0
    highlight default link modula2LowLineIdent modula2UserDefIdentStyle
  else
    highlight default link modula2LowLineIdent Error
  endif
else
  highlight default link modula2LowLineIdent modula2UserDefIdentStyle
endif

" literals
highlight default link modula2String modula2StringLiteralStyle
highlight default link modula2Base2Num modula2NumericLiteralStyle
highlight default link modula2Base10Num modula2NumericLiteralStyle
highlight default link modula2Base16Num modula2NumericLiteralStyle

" punctuation
highlight default link modula2Punctuation modula2PunctuationStyle

" pragmas
highlight default link modula2Pragma modula2PragmaStyle
highlight default link modula2PragmaKey modula2PragmaKeyStyle
highlight default link modula2DialectTag modula2DialectTagStyle

" comments
highlight default link modula2Comment modula2CommentStyle
highlight default link modula2CommentKey modula2CommentKeyStyle
highlight default link modula2ToDoTailComment modula2CommentStyle
highlight default link modula2StmtTailComment modula2CommentStyle

" technical debt markers
highlight default link modula2ToDoHeader modula2TechDebtMarkerStyle
highlight default link modula2ToDoTail modula2TechDebtMarkerStyle
highlight default link modula2TechDebtPragma modula2TechDebtMarkerStyle

" disabled code
highlight default link modula2DisabledCode modula2DisabledCodeStyle

" illegal symbols
highlight default link modula2IllegalChar Error
highlight default link modula2IllegalIdent Error


let b:current_syntax = "modula2"

" vim: ts=4

" END OF FILE
