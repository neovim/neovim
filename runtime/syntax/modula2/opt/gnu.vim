" Vim syntax file
" Language:    Modula-2 (GNU)
" Maintainer:  Wilken Gottwalt <wilken.gottwalt@posteo.net> (based on B.Kowarschs ISO syntax)
" Last Change: 2025 November 26

" ----------------------------------------------------
" THIS FILE IS LICENSED UNDER THE VIM LICENSE
" see https://github.com/vim/vim/blob/master/LICENSE
" ----------------------------------------------------

" Remarks:
" Vim Syntax files are available for the following Modula-2 dialects:
" * for the PIM dialect : m2pim.vim
" * for the ISO dialect : m2iso.vim
" * for the R10 dialect : m2r10.vim
" * for the GNU dialect : m2gnu.vim (this file)

" -----------------------------------------------------------------------------
" This syntax description follows ISO standard IS-10514 (aka ISO Modula-2 part 1)
" with the addition of the following language extensions:
" * GCC extensions
" * non-nesting code disabling tags ?< and >? at the start of a line
" -----------------------------------------------------------------------------

" Parameters:
"
" Vim's filetype script recognises Modula-2 dialect tags within the first 200
" lines of Modula-2 .def and .mod input files.  The script sets filetype and
" dialect automatically when a valid dialect tag is found in the input file.
" The dialect tag for the GNU dialect is (*!m2gnu*).  It is recommended to put
" the tag immediately after the module header in the Modula-2 input file.
"
" Example:
"  DEFINITION MODULE Foolib; (*!m2gnu*)
"
" Variable g:modula2_default_dialect sets the default Modula-2 dialect when the
" dialect cannot be determined from the contents of the Modula-2 input file:
" if defined and set to 'm2gnu', the default dialect is GNU.
"
" Variable g:modula2_gnu_allow_lowline controls support for lowline in identifiers:
" if defined and set to a non-zero value, they are recognised, otherwise not
"
" Variable g:modula2_gnu_disallow_octals controls the rendering of octal literals:
" if defined and set to a non-zero value, they are rendered as errors.
"
" Variable g:modula2_gnu_disallow_synonyms controls the rendering of @, & and ~:
" if defined and set to a non-zero value, they are rendered as errors.
"
" Variables may be defined in Vim startup file .vimrc
"
" Examples:
"  let g:modula2_default_dialect = 'm2gnu'
"  let g:modula2_gnu_allow_lowline = 1
"  let g:modula2_gnu_disallow_octals = 1
"  let g:modula2_gnu_disallow_synonyms = 1

if exists("b:current_syntax")
  finish
endif

" Modula-2 is case sensitive
syn case match

" -----------------------------------------------------------------------------
" Reserved Words
" -----------------------------------------------------------------------------
syn keyword modula2Resword AND ARRAY BEGIN BY CASE CONST COROUTINE DEFINITION DIV DO
syn keyword modula2Resword ELSE ELSIF EXCEPT EXIT EXPORT FINALLY FOR FORWARD FROM IF
syn keyword modula2Resword IMPLEMENTATION IMPORT IN LOOP MOD NOT OF OR PACKEDSET
syn keyword modula2Resword POINTER QUALIFIED RECORD REPEAT REM RETRY RETURN SET
syn keyword modula2Resword THEN TO TYPE UNTIL UNQUALIFIED VAR WHILE WITH

" -----------------------------------------------------------------------------
" Builtin Constant Identifiers
" -----------------------------------------------------------------------------
syn keyword modula2ConstIdent FALSE NIL TRUE

" -----------------------------------------------------------------------------
" Builtin Type Identifiers
" -----------------------------------------------------------------------------
syn keyword modula2TypeIdent BITSET BOOLEAN CHAR PROC SHORTCARD CARDINAL LONGCARD
syn keyword modula2TypeIdent SHORTINT INTEGER LONGINT SHORTREAL REAL LONGREAL
syn keyword modula2TypeIdent SHORTCOMPLEX COMPLEX LONGCOMPLEX PROTECTION

" -----------------------------------------------------------------------------
" Fixed Size SYSTEM Type Identifiers Matching C Types
" -----------------------------------------------------------------------------
syn keyword modula2TypeIdent INTEGER8 INTEGER16 INTEGER32 INTEGER64
syn keyword modula2TypeIdent CARDINAL8 CARDINAL16 CARDINAL32 CARDINAL64
syn keyword modula2TypeIdent BITSET8 BITSET16 BITSET32
syn keyword modula2TypeIdent WORD16 WORD32 WORD64
syn keyword modula2TypeIdent REAL32 REAL64 REAL96 REAL128
syn keyword modula2TypeIdent COMPLEX32 COMPLEX64 COMPLEX96 COMPLEX128

" -----------------------------------------------------------------------------
" Builtin Procedure and Function Identifiers
" -----------------------------------------------------------------------------
syn keyword modula2ProcIdent CAP DEC EXCL HALT INC INCL
syn keyword modula2FuncIdent ABS CHR CMPLX FLOAT HIGH IM INT LENGTH LFLOAT MAX MIN
syn keyword modula2FuncIdent ODD ORD RE SIZE TRUNC VAL

" -----------------------------------------------------------------------------
" Wirthian Macro Identifiers
" -----------------------------------------------------------------------------
syn keyword modula2MacroIdent ALLOCATE DEALLOCATE NEW DISPOSE

" -----------------------------------------------------------------------------
" Unsafe Facilities via Pseudo-Module SYSTEM
" -----------------------------------------------------------------------------
syn keyword modula2UnsafeIdent ADDRESS BYTE CSIZE_T CSSIZE_T LOC WORD
syn keyword modula2UnsafeIdent ADR CAST TSIZE
syn keyword modula2UnsafeIdent MAKEADR ADDADR SUBADR DIFADR ROTATE SHIFT

" -----------------------------------------------------------------------------
" User Defined Identifiers
" -----------------------------------------------------------------------------
syn match modula2Ident "[a-zA-Z][a-zA-Z0-9]*\(_\)\@!"
syn match modula2LowLineIdent "[a-zA-Z][a-zA-Z0-9]*\(_[a-zA-Z0-9]\+\)\+"

" -----------------------------------------------------------------------------
" String Literals
" -----------------------------------------------------------------------------
syn region modula2String start=/"/ end=/"/ oneline
syn region modula2String start=/'/ end=/'/ oneline

" -----------------------------------------------------------------------------
" Numeric Literals
" -----------------------------------------------------------------------------
syn match modula2Num
  \ "\(\([0-7]\+\)[BC]\@!\|[89]\)[0-9]*\(\.[0-9]\+\([eE][+-]\?[0-9]\+\)\?\)\?"
syn match modula2Num "[0-9A-F]\+H"
syn match modula2Octal "[0-7]\+[BC]"

" -----------------------------------------------------------------------------
" Punctuation
" -----------------------------------------------------------------------------
syn match modula2Punctuation
  \ "\.\|[,:;]\|\*\|[/+-]\|\#\|[=<>]\|\^\|\[\|\]\|(\(\*\)\@!\|[){}]"
syn match modula2Synonym "[@&~]"

" -----------------------------------------------------------------------------
" Pragmas
" -----------------------------------------------------------------------------
syn region modula2Pragma start="<\*" end="\*>"
syn match modula2DialectTag "(\*!m2gnu\(+[a-z0-9]\+\)\?\*)"

" -----------------------------------------------------------------------------
" Block Comments
" -----------------------------------------------------------------------------
syn region modula2Comment start="(\*\(!m2gnu\(+[a-z0-9]\+\)\?\*)\)\@!" end="\*)"
  \ contains = modula2Comment, modula2CommentKey, modula2TechDebtMarker
syn match modula2CommentKey "[Aa]uthor[s]\?\|[Cc]opyright\|[Ll]icense\|[Ss]ynopsis"
syn match modula2CommentKey "\([Pp]re\|[Pp]ost\|[Ee]rror\)\-condition[s]\?:"

" -----------------------------------------------------------------------------
" Technical Debt Markers
" -----------------------------------------------------------------------------
syn keyword modula2TechDebtMarker contained DEPRECATED FIXME
syn match modula2TechDebtMarker "TODO[:]\?" contained

" -----------------------------------------------------------------------------
" Disabled Code Sections
" -----------------------------------------------------------------------------
syn region modula2DisabledCode start="^?<" end="^>?"

" -----------------------------------------------------------------------------
" Headers
" -----------------------------------------------------------------------------
" !!! this section must be second last !!!

" new module header
syn match modula2ModuleHeader
  \ "MODULE\( [A-Z][a-zA-Z0-9]*\)\?"
  \ contains = modula2ReswordModule, modula2ModuleIdent

syn match modula2ModuleIdent
  \ "[A-Z][a-zA-Z0-9]*" contained

syn match modula2ModuleTail
  \ "END [A-Z][a-zA-Z0-9]*\.$"
  \ contains = modula2ReswordEnd, modula2ModuleIdent, modula2Punctuation

" new procedure header
syn match modula2ProcedureHeader
  \ "PROCEDURE\( [a-zA-Z][a-zA-Z0-9]*\(_[a-zA-Z0-9]\+\)*\)\?"
  \ contains = modula2ReswordProcedure,
  \ modula2ProcedureIdent, modula2ProcedureLowlineIdent, modula2IllegalChar, modula2IllegalIdent

syn match modula2ProcedureIdent
  \ "\([a-zA-Z]\)\([a-zA-Z0-9]*\)" contained

syn match modula2ProcedureLowlineIdent
  \ "[a-zA-Z][a-zA-Z0-9]*\(_[a-zA-Z0-9]\+\)\+" contained

syn match modula2ProcedureTail
  \ "END\( \([a-zA-Z][a-zA-Z0-9]*\(_[a-zA-Z0-9]\+\)*\)[.;]$\)\?"
  \ contains = modula2ReswordEnd,
  \ modula2ProcedureIdent, modula2ProcedureLowLineIdent,
  \ modula2Punctuation, modula2IllegalChar, modula2IllegalIdent

syn keyword modula2ReswordModule contained MODULE
syn keyword modula2ReswordProcedure contained PROCEDURE
syn keyword modula2ReswordEnd contained END

" -----------------------------------------------------------------------------
" Illegal Symbols
" -----------------------------------------------------------------------------
" !!! this section must be last !!!

" any '`' '!' '$' '%' or '\'
syn match modula2IllegalChar "[`!$%\\]"

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
highlight default link modula2UnsafeIdentStyle Question
highlight default link modula2NonPortableIdentStyle Question
highlight default link modula2StringLiteralStyle String
highlight default link modula2CommentStyle Comment
highlight default link modula2PragmaStyle PreProc
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
highlight default link modula2ModuleHeader Normal
highlight default link modula2ModuleTail Normal
highlight default link modula2ProcedureHeader Normal
highlight default link modula2ProcedureTail Normal

" lowline identifiers are rendered as errors if g:modula2_gnu_allow_lowline is unset
if exists("g:modula2_gnu_allow_lowline")
  if g:modula2_gnu_allow_lowline != 0
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

" predefined identifiers
highlight default link modula2ConstIdent modula2ConstIdentStyle
highlight default link modula2TypeIdent modula2TypeIdentStyle
highlight default link modula2ProcIdent modula2ProcIdentStyle
highlight default link modula2FuncIdent modula2FuncIdentStyle
highlight default link modula2MacroIdent modula2MacroIdentStyle

" unsafe and non-portable identifiers
highlight default link modula2UnsafeIdent modula2UnsafeIdentStyle
highlight default link modula2NonPortableIdent modula2NonPortableIdentStyle

" user defined identifiers
highlight default link modula2Ident modula2UserDefIdentStyle

" lowline identifiers are rendered as errors if g:modula2_gnu_allow_lowline is unset
if exists("g:modula2_gnu_allow_lowline")
  if g:modula2_gnu_allow_lowline != 0
    highlight default link modula2LowLineIdent modula2UserDefIdentStyle
  else
    highlight default link modula2LowLineIdent Error
  endif
else
  highlight default link modula2LowLineIdent modula2UserDefIdentStyle
endif

" literals
highlight default link modula2String modula2StringLiteralStyle
highlight default link modula2Num modula2NumericLiteralStyle

" octal literals are rendered as errors if g:modula2_gnu_disallow_octals is set
if exists("g:modula2_gnu_disallow_octals")
  if g:modula2_gnu_disallow_octals != 0
    highlight default link modula2Octal Error
  else
    highlight default link modula2Octal modula2NumericLiteralStyle
  endif
else
  highlight default link modula2Octal modula2NumericLiteralStyle
endif

" punctuation
highlight default link modula2Punctuation modula2PunctuationStyle

" synonyms & and ~ are rendered as errors if g:modula2_gnu_disallow_synonyms is set
if exists("g:modula2_gnu_disallow_synonyms")
  if g:modula2_gnu_disallow_synonyms != 0
    highlight default link modula2Synonym Error
  else
    highlight default link modula2Synonym modula2PunctuationStyle
  endif
else
  highlight default link modula2Synonym modula2PunctuationStyle
endif

" pragmas
highlight default link modula2Pragma modula2PragmaStyle
highlight default link modula2DialectTag modula2DialectTagStyle

" comments
highlight default link modula2Comment modula2CommentStyle
highlight default link modula2CommentKey modula2CommentKeyStyle

" technical debt markers
highlight default link modula2TechDebtMarker modula2TechDebtMarkerStyle

" disabled code
highlight default link modula2DisabledCode modula2DisabledCodeStyle

" illegal symbols
highlight default link modula2IllegalChar Error
highlight default link modula2IllegalIdent Error

let b:current_syntax = "modula2"

" vim: ts=2

" END OF FILE
