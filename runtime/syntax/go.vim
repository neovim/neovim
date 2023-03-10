" Copyright 2009 The Go Authors. All rights reserved.
" Use of this source code is governed by a BSD-style
" license that can be found in the LICENSE file.
"
" go.vim: Vim syntax file for Go.
" Language:             Go
" Maintainer:           Billie Cleek <bhcleek@gmail.com>
" Latest Revision:      2023-02-19
" License:              BSD-style. See LICENSE file in source repository.
" Repository:           https://github.com/fatih/vim-go

" Quit when a (custom) syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:keepcpo = &cpo
set cpo&vim

function! s:FoldEnable(...) abort
  if a:0 > 0
    return index(s:FoldEnable(), a:1) > -1
  endif
  return get(g:, 'go_fold_enable', ['block', 'import', 'varconst', 'package_comment'])
endfunction

function! s:HighlightArrayWhitespaceError() abort
  return get(g:, 'go_highlight_array_whitespace_error', 0)
endfunction

function! s:HighlightChanWhitespaceError() abort
  return get(g:, 'go_highlight_chan_whitespace_error', 0)
endfunction

function! s:HighlightExtraTypes() abort
  return get(g:, 'go_highlight_extra_types', 0)
endfunction

function! s:HighlightSpaceTabError() abort
  return get(g:, 'go_highlight_space_tab_error', 0)
endfunction

function! s:HighlightTrailingWhitespaceError() abort
  return get(g:, 'go_highlight_trailing_whitespace_error', 0)
endfunction

function! s:HighlightOperators() abort
  return get(g:, 'go_highlight_operators', 0)
endfunction

function! s:HighlightFunctions() abort
  return get(g:, 'go_highlight_functions', 0)
endfunction

function! s:HighlightFunctionParameters() abort
  return get(g:, 'go_highlight_function_parameters', 0)
endfunction

function! s:HighlightFunctionCalls() abort
  return get(g:, 'go_highlight_function_calls', 0)
endfunction

function! s:HighlightFields() abort
  return get(g:, 'go_highlight_fields', 0)
endfunction

function! s:HighlightTypes() abort
  return get(g:, 'go_highlight_types', 0)
endfunction

function! s:HighlightBuildConstraints() abort
  return get(g:, 'go_highlight_build_constraints', 0)
endfunction

function! s:HighlightStringSpellcheck() abort
  return get(g:, 'go_highlight_string_spellcheck', 1)
endfunction

function! s:HighlightFormatStrings() abort
  return get(g:, 'go_highlight_format_strings', 1)
endfunction

function! s:HighlightGenerateTags() abort
  return get(g:, 'go_highlight_generate_tags', 0)
endfunction

function! s:HighlightVariableAssignments() abort
  return get(g:, 'go_highlight_variable_assignments', 0)
endfunction

function! s:HighlightVariableDeclarations() abort
  return get(g:, 'go_highlight_variable_declarations', 0)
endfunction

syn case match

syn keyword     goPackage           package
syn keyword     goImport            import    contained
syn keyword     goVar               var       contained
syn keyword     goConst             const     contained

hi def link     goPackage           Statement
hi def link     goImport            Statement
hi def link     goVar               Keyword
hi def link     goConst             Keyword
hi def link     goDeclaration       Keyword

" Keywords within functions
syn keyword     goStatement         defer go goto return break continue fallthrough
syn keyword     goConditional       if else switch select
syn keyword     goLabel             case default
syn keyword     goRepeat            for range

hi def link     goStatement         Statement
hi def link     goConditional       Conditional
hi def link     goLabel             Label
hi def link     goRepeat            Repeat

" Predefined types
syn keyword     goType              chan map bool string error any comparable
syn keyword     goSignedInts        int int8 int16 int32 int64 rune
syn keyword     goUnsignedInts      byte uint uint8 uint16 uint32 uint64 uintptr
syn keyword     goFloats            float32 float64
syn keyword     goComplexes         complex64 complex128

hi def link     goType              Type
hi def link     goSignedInts        Type
hi def link     goUnsignedInts      Type
hi def link     goFloats            Type
hi def link     goComplexes         Type

" Predefined functions and values
syn keyword     goBuiltins                 append cap close complex copy delete imag len
syn keyword     goBuiltins                 make new panic print println real recover
syn keyword     goBoolean                  true false
syn keyword     goPredefinedIdentifiers    nil iota

hi def link     goBuiltins                 Identifier
hi def link     goPredefinedIdentifiers    Constant
" Boolean links to Constant by default by vim: goBoolean and goPredefinedIdentifiers
" will be highlighted the same, but having the separate groups allows users to
" have separate highlighting for them if they desire.
hi def link     goBoolean                  Boolean

" Comments; their contents
syn keyword     goTodo              contained TODO FIXME XXX BUG
syn cluster     goCommentGroup      contains=goTodo

syn region      goComment           start="//" end="$" contains=goGenerate,@goCommentGroup,@Spell
if s:FoldEnable('comment')
  syn region    goComment           start="/\*" end="\*/" contains=@goCommentGroup,@Spell fold
  syn match     goComment           "\v(^\s*//.*\n)+" contains=goGenerate,@goCommentGroup,@Spell fold
else
  syn region    goComment           start="/\*" end="\*/" contains=@goCommentGroup,@Spell
endif

hi def link     goComment           Comment
hi def link     goTodo              Todo

if s:HighlightGenerateTags()
  syn match       goGenerateVariables contained /\%(\$GOARCH\|\$GOOS\|\$GOFILE\|\$GOLINE\|\$GOPACKAGE\|\$DOLLAR\)\>/
  syn region      goGenerate          start="^\s*//go:generate" end="$" contains=goGenerateVariables
  hi def link     goGenerate          PreProc
  hi def link     goGenerateVariables Special
endif

" Go escapes
syn match       goEscapeOctal       display contained "\\[0-7]\{3}"
syn match       goEscapeC           display contained +\\[abfnrtv\\'"]+
syn match       goEscapeX           display contained "\\x\x\{2}"
syn match       goEscapeU           display contained "\\u\x\{4}"
syn match       goEscapeBigU        display contained "\\U\x\{8}"
syn match       goEscapeError       display contained +\\[^0-7xuUabfnrtv\\'"]+

hi def link     goEscapeOctal       goSpecialString
hi def link     goEscapeC           goSpecialString
hi def link     goEscapeX           goSpecialString
hi def link     goEscapeU           goSpecialString
hi def link     goEscapeBigU        goSpecialString
hi def link     goSpecialString     Special
hi def link     goEscapeError       Error

" Strings and their contents
syn cluster     goStringGroup       contains=goEscapeOctal,goEscapeC,goEscapeX,goEscapeU,goEscapeBigU,goEscapeError
if s:HighlightStringSpellcheck()
  syn region      goString            start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=@goStringGroup,@Spell
  syn region      goRawString         start=+`+ end=+`+ contains=@Spell
else
  syn region      goString            start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=@goStringGroup
  syn region      goRawString         start=+`+ end=+`+
endif

syn match       goImportString      /^\%(\s\+\|import \)\(\h\w* \)\?\zs"[^"]\+"$/ contained containedin=goImport

if s:HighlightFormatStrings()
  " [n] notation is valid for specifying explicit argument indexes
  " 1. Match a literal % not preceded by a %.
  " 2. Match any number of -, #, 0, space, or +
  " 3. Match * or [n]* or any number or nothing before a .
  " 4. Match * or [n]* or any number or nothing after a .
  " 5. Match [n] or nothing before a verb
  " 6. Match a formatting verb
  syn match       goFormatSpecifier   /\
        \%([^%]\%(%%\)*\)\
        \@<=%[-#0 +]*\
        \%(\%(\%(\[\d\+\]\)\=\*\)\|\d\+\)\=\
        \%(\.\%(\%(\%(\[\d\+\]\)\=\*\)\|\d\+\)\=\)\=\
        \%(\[\d\+\]\)\=[vTtbcdoqxXUeEfFgGspw]/ contained containedin=goString,goRawString
  hi def link     goFormatSpecifier   goSpecialString
endif

hi def link     goImportString      String
hi def link     goString            String
hi def link     goRawString         String

" Characters; their contents
syn cluster     goCharacterGroup    contains=goEscapeOctal,goEscapeC,goEscapeX,goEscapeU,goEscapeBigU
syn region      goCharacter         start=+'+ skip=+\\\\\|\\'+ end=+'+ contains=@goCharacterGroup

hi def link     goCharacter         Character

" Regions
syn region      goParen             start='(' end=')' transparent
if s:FoldEnable('block')
  syn region    goBlock             start="{" end="}" transparent fold
else
  syn region    goBlock             start="{" end="}" transparent
endif

" import
if s:FoldEnable('import')
  syn region    goImport            start='import (' end=')' transparent fold contains=goImport,goImportString,goComment
else
  syn region    goImport            start='import (' end=')' transparent contains=goImport,goImportString,goComment
endif

" var, const
if s:FoldEnable('varconst')
  syn region    goVar               start='var ('   end='^\s*)$' transparent fold
                        \ contains=ALLBUT,goParen,goBlock,goFunction,goTypeName,goReceiverType,goReceiverVar,goParamName,goParamType,goSimpleParams,goPointerOperator
  syn region    goConst             start='const (' end='^\s*)$' transparent fold
                        \ contains=ALLBUT,goParen,goBlock,goFunction,goTypeName,goReceiverType,goReceiverVar,goParamName,goParamType,goSimpleParams,goPointerOperator
else
  syn region    goVar               start='var ('   end='^\s*)$' transparent
                        \ contains=ALLBUT,goParen,goBlock,goFunction,goTypeName,goReceiverType,goReceiverVar,goParamName,goParamType,goSimpleParams,goPointerOperator
  syn region    goConst             start='const (' end='^\s*)$' transparent
                        \ contains=ALLBUT,goParen,goBlock,goFunction,goTypeName,goReceiverType,goReceiverVar,goParamName,goParamType,goSimpleParams,goPointerOperator
endif

" Single-line var, const, and import.
syn match       goSingleDecl        /\%(import\|var\|const\) [^(]\@=/ contains=goImport,goVar,goConst

" Integers
syn match       goDecimalInt        "\<-\=\%(0\|\%(\d\|\d_\d\)\+\)\>"
syn match       goHexadecimalInt    "\<-\=0[xX]_\?\%(\x\|\x_\x\)\+\>"
syn match       goOctalInt          "\<-\=0[oO]\?_\?\%(\o\|\o_\o\)\+\>"
syn match       goBinaryInt         "\<-\=0[bB]_\?\%([01]\|[01]_[01]\)\+\>"

hi def link     goDecimalInt        Integer
hi def link     goDecimalError      Error
hi def link     goHexadecimalInt    Integer
hi def link     goHexadecimalError  Error
hi def link     goOctalInt          Integer
hi def link     goOctalError        Error
hi def link     goBinaryInt         Integer
hi def link     goBinaryError       Error
hi def link     Integer             Number

" Floating point
"float_lit         = decimal_float_lit | hex_float_lit .
"
"decimal_float_lit = decimal_digits "." [ decimal_digits ] [ decimal_exponent ] |
"                    decimal_digits decimal_exponent |
"                    "." decimal_digits [ decimal_exponent ] .
"decimal_exponent  = ( "e" | "E" ) [ "+" | "-" ] decimal_digits .
"
"hex_float_lit     = "0" ( "x" | "X" ) hex_mantissa hex_exponent .
"hex_mantissa      = [ "_" ] hex_digits "." [ hex_digits ] |
"                    [ "_" ] hex_digits |
"                    "." hex_digits .
"hex_exponent      = ( "p" | "P" ) [ "+" | "-" ] decimal_digits .
" decimal floats with a decimal point
syn match       goFloat             "\<-\=\%(0\|\%(\d\|\d_\d\)\+\)\.\%(\%(\%(\d\|\d_\d\)\+\)\=\%([Ee][-+]\=\%(\d\|\d_\d\)\+\)\=\>\)\="
syn match       goFloat             "\s\zs-\=\.\%(\d\|\d_\d\)\+\%(\%([Ee][-+]\=\%(\d\|\d_\d\)\+\)\>\)\="
" decimal floats without a decimal point
syn match       goFloat             "\<-\=\%(0\|\%(\d\|\d_\d\)\+\)[Ee][-+]\=\%(\d\|\d_\d\)\+\>"
" hexadecimal floats with a decimal point
syn match       goHexadecimalFloat  "\<-\=0[xX]\%(_\x\|\x\)\+\.\%(\%(\x\|\x_\x\)\+\)\=\%([Pp][-+]\=\%(\d\|\d_\d\)\+\)\=\>"
syn match       goHexadecimalFloat  "\<-\=0[xX]\.\%(\x\|\x_\x\)\+\%([Pp][-+]\=\%(\d\|\d_\d\)\+\)\=\>"
" hexadecimal floats without a decimal point
syn match       goHexadecimalFloat  "\<-\=0[xX]\%(_\x\|\x\)\+[Pp][-+]\=\%(\d\|\d_\d\)\+\>"

hi def link     goFloat             Float
hi def link     goHexadecimalFloat  Float

" Imaginary literals
syn match       goImaginaryDecimal        "\<-\=\%(0\|\%(\d\|\d_\d\)\+\)i\>"
syn match       goImaginaryHexadecimal    "\<-\=0[xX]_\?\%(\x\|\x_\x\)\+i\>"
syn match       goImaginaryOctal          "\<-\=0[oO]\?_\?\%(\o\|\o_\o\)\+i\>"
syn match       goImaginaryBinary         "\<-\=0[bB]_\?\%([01]\|[01]_[01]\)\+i\>"

" imaginary decimal floats with a decimal point
syn match       goImaginaryFloat             "\<-\=\%(0\|\%(\d\|\d_\d\)\+\)\.\%(\%(\%(\d\|\d_\d\)\+\)\=\%([Ee][-+]\=\%(\d\|\d_\d\)\+\)\=\)\=i\>"
syn match       goImaginaryFloat             "\s\zs-\=\.\%(\d\|\d_\d\)\+\%([Ee][-+]\=\%(\d\|\d_\d\)\+\)\=i\>"
" imaginary decimal floats without a decimal point
syn match       goImaginaryFloat             "\<-\=\%(0\|\%(\d\|\d_\d\)\+\)[Ee][-+]\=\%(\d\|\d_\d\)\+i\>"
" imaginary hexadecimal floats with a decimal point
syn match       goImaginaryHexadecimalFloat  "\<-\=0[xX]\%(_\x\|\x\)\+\.\%(\%(\x\|\x_\x\)\+\)\=\%([Pp][-+]\=\%(\d\|\d_\d\)\+\)\=i\>"
syn match       goImaginaryHexadecimalFloat  "\<-\=0[xX]\.\%(\x\|\x_\x\)\+\%([Pp][-+]\=\%(\d\|\d_\d\)\+\)\=i\>"
" imaginary hexadecimal floats without a decimal point
syn match       goImaginaryHexadecimalFloat  "\<-\=0[xX]\%(_\x\|\x\)\+[Pp][-+]\=\%(\d\|\d_\d\)\+i\>"

hi def link     goImaginaryDecimal             Number
hi def link     goImaginaryHexadecimal         Number
hi def link     goImaginaryOctal               Number
hi def link     goImaginaryBinary              Number
hi def link     goImaginaryFloat               Float
hi def link     goImaginaryHexadecimalFloat    Float

" Spaces after "[]"
if s:HighlightArrayWhitespaceError()
  syn match goSpaceError display "\%(\[\]\)\@<=\s\+"
endif

" Spacing errors around the 'chan' keyword
if s:HighlightChanWhitespaceError()
  " receive-only annotation on chan type
  "
  " \(\<chan\>\)\@<!<-  (only pick arrow when it doesn't come after a chan)
  " this prevents picking up 'chan<- chan<-' but not '<- chan'
  syn match goSpaceError display "\%(\%(\<chan\>\)\@<!<-\)\@<=\s\+\%(\<chan\>\)\@="

  " send-only annotation on chan type
  "
  " \(<-\)\@<!\<chan\>  (only pick chan when it doesn't come after an arrow)
  " this prevents picking up '<-chan <-chan' but not 'chan <-'
  syn match goSpaceError display "\%(\%(<-\)\@<!\<chan\>\)\@<=\s\+\%(<-\)\@="

  " value-ignoring receives in a few contexts
  syn match goSpaceError display "\%(\%(^\|[={(,;]\)\s*<-\)\@<=\s\+"
endif

" Extra types commonly seen
if s:HighlightExtraTypes()
  syn match goExtraType /\<bytes\.\%(Buffer\)\>/
  syn match goExtraType /\<context\.\%(Context\)\>/
  syn match goExtraType /\<io\.\%(Reader\|ReadSeeker\|ReadWriter\|ReadCloser\|ReadWriteCloser\|Writer\|WriteCloser\|Seeker\)\>/
  syn match goExtraType /\<reflect\.\%(Kind\|Type\|Value\)\>/
  syn match goExtraType /\<unsafe\.Pointer\>/
endif

" Space-tab error
if s:HighlightSpaceTabError()
  syn match goSpaceError display " \+\t"me=e-1
endif

" Trailing white space error
if s:HighlightTrailingWhitespaceError()
  syn match goSpaceError display excludenl "\s\+$"
endif

hi def link     goExtraType         Type
hi def link     goSpaceError        Error



" included from: https://github.com/athom/more-colorful.vim/blob/master/after/syntax/go.vim
"
" Comments; their contents
syn keyword     goTodo              contained NOTE
hi def link     goTodo              Todo

syn match goVarArgs /\.\.\./

" Operators;
if s:HighlightOperators()
  " match single-char operators:          - + % < > ! & | ^ * =
  " and corresponding two-char operators: -= += %= <= >= != &= |= ^= *= ==
  syn match goOperator /[-+%<>!&|^*=]=\?/
  " match / and /=
  syn match goOperator /\/\%(=\|\ze[^/*]\)/
  " match two-char operators:               << >> &^
  " and corresponding three-char operators: <<= >>= &^=
  syn match goOperator /\%(<<\|>>\|&^\)=\?/
  " match remaining two-char operators: := && || <- ++ --
  syn match goOperator /:=\|||\|<-\|++\|--/
  " match ~
  syn match goOperator /\~/
  " match ...

  hi def link     goPointerOperator   goOperator
  hi def link     goVarArgs           goOperator
endif
hi def link     goOperator          Operator

"                               -> type constraint opening bracket
"                               |-> start non-counting group
"                               ||  -> any word character
"                               ||  |  -> at least one, as many as possible
"                               ||  |  |    -> start non-counting group
"                               ||  |  |    |   -> match ~
"                               ||  |  |    |   | -> at most once
"                               ||  |  |    |   | |     -> allow a slice type
"                               ||  |  |    |   | |     |      -> any word character
"                               ||  |  |    |   | |     |      | -> start a non-counting group
"                               ||  |  |    |   | |     |      | | -> that matches word characters and |
"                               ||  |  |    |   | |     |      | | |     -> close the non-counting group
"                               ||  |  |    |   | |     |      | | |     | -> close the non-counting group
"                               ||  |  |    |   | |     |      | | |     | |-> any number of matches
"                               ||  |  |    |   | |     |      | | |     | || -> start a non-counting group
"                               ||  |  |    |   | |     |      | | |     | || | -> a comma and whitespace
"                               ||  |  |    |   | |     |      | | |     | || | |      -> at most once
"                               ||  |  |    |   | |     |      | | |     | || | |      | -> close the non-counting group
"                               ||  |  |    |   | |     |      | | |     | || | |      | | -> at least one of those non-counting groups, as many as possible
"                               ||  |  |    |   | | --------   | | |     | || | |      | | | -> type constraint closing bracket
"                               ||  |  |    |   | ||        |  | | |     | || | |      | | | |
syn match goTypeParams        /\[\%(\w\+\s\+\%(\~\?\%(\[]\)\?\w\%(\w\||\)\)*\%(,\s*\)\?\)\+\]/ nextgroup=goSimpleParams,goDeclType contained

" Functions;
if s:HighlightFunctions() || s:HighlightFunctionParameters()
  syn match goDeclaration       /\<func\>/ nextgroup=goReceiver,goFunction,goSimpleParams skipwhite skipnl
  syn match goReceiverDecl      /(\s*\zs\%(\%(\w\+\s\+\)\?\*\?\w\+\%(\[\%(\%(\[\]\)\?\w\+\%(,\s*\)\?\)\+\]\)\?\)\ze\s*)/ contained contains=goReceiverVar,goReceiverType,goPointerOperator
  syn match goReceiverVar       /\w\+\ze\s\+\%(\w\|\*\)/ nextgroup=goPointerOperator,goReceiverType skipwhite skipnl contained
  syn match goPointerOperator   /\*/ nextgroup=goReceiverType contained skipwhite skipnl
  syn match goFunction          /\w\+/ nextgroup=goSimpleParams,goTypeParams contained skipwhite skipnl
  syn match goReceiverType      /\w\+\%(\[\%(\%(\[\]\)\?\w\+\%(,\s*\)\?\)\+\]\)\?\ze\s*)/ contained
  if s:HighlightFunctionParameters()
    syn match goSimpleParams      /(\%(\w\|\_s\|[*\.\[\],\{\}<>-]\)*)/ contained contains=goParamName,goType nextgroup=goFunctionReturn skipwhite skipnl
    syn match goFunctionReturn   /(\%(\w\|\_s\|[*\.\[\],\{\}<>-]\)*)/ contained contains=goParamName,goType skipwhite skipnl
    syn match goParamName        /\w\+\%(\s*,\s*\w\+\)*\ze\s\+\%(\w\|\.\|\*\|\[\)/ contained nextgroup=goParamType skipwhite skipnl
    syn match goParamType        /\%([^,)]\|\_s\)\+,\?/ contained nextgroup=goParamName skipwhite skipnl
                          \ contains=goVarArgs,goType,goSignedInts,goUnsignedInts,goFloats,goComplexes,goDeclType,goBlock
    hi def link   goReceiverVar    goParamName
    hi def link   goParamName      Identifier
  endif
  syn match goReceiver          /(\s*\%(\w\+\s\+\)\?\*\?\s*\w\+\%(\[\%(\%(\[\]\)\?\w\+\%(,\s*\)\?\)\+\]\)\?\s*)\ze\s*\w/ contained nextgroup=goFunction contains=goReceiverDecl skipwhite skipnl
else
  syn keyword goDeclaration func
endif
hi def link     goFunction          Function

" Function calls;
if s:HighlightFunctionCalls()
  syn match goFunctionCall      /\w\+\ze\%(\[\%(\%(\[]\)\?\w\+\(,\s*\)\?\)\+\]\)\?(/ contains=goBuiltins,goDeclaration
endif
hi def link     goFunctionCall      Type

" Fields;
if s:HighlightFields()
  " 1. Match a sequence of word characters coming after a '.'
  " 2. Require the following but dont match it: ( \@= see :h E59)
  "    - The symbols: / - + * %   OR
  "    - The symbols: [] {} <> )  OR
  "    - The symbols: \n \r space OR
  "    - The symbols: , : .
  " 3. Have the start of highlight (hs) be the start of matched
  "    pattern (s) offsetted one to the right (+1) (see :h E401)
  syn match       goField   /\.\w\+\
        \%(\%([\/\-\+*%]\)\|\
        \%([\[\]{}<\>\)]\)\|\
        \%([\!=\^|&]\)\|\
        \%([\n\r\ ]\)\|\
        \%([,\:.]\)\)\@=/hs=s+1
endif
hi def link    goField              Identifier

" Structs & Interfaces;
if s:HighlightTypes()
  syn match goTypeConstructor      /\<\w\+{\@=/
  syn match goTypeDecl             /\<type\>/ nextgroup=goTypeName skipwhite skipnl
  syn match goTypeName             /\w\+/ contained nextgroup=goDeclType,goTypeParams skipwhite skipnl
  syn match goDeclType             /\<\%(interface\|struct\)\>/ skipwhite skipnl
  hi def link     goReceiverType      Type
else
  syn keyword goDeclType           struct interface
  syn keyword goDeclaration        type
endif
hi def link     goTypeConstructor   Type
hi def link     goTypeName          Type
hi def link     goTypeDecl          Keyword
hi def link     goDeclType          Keyword

" Variable Assignments
if s:HighlightVariableAssignments()
  syn match goVarAssign /\v[_.[:alnum:]]+(,\s*[_.[:alnum:]]+)*\ze(\s*([-^+|^\/%&]|\*|\<\<|\>\>|\&\^)?\=[^=])/
  hi def link   goVarAssign         Special
endif

" Variable Declarations
if s:HighlightVariableDeclarations()
  syn match goVarDefs /\v\w+(,\s*\w+)*\ze(\s*:\=)/
  hi def link   goVarDefs           Special
endif

" Build Constraints
if s:HighlightBuildConstraints()
  syn match   goBuildKeyword      display contained "+build\|go:build"
  " Highlight the known values of GOOS, GOARCH, and other +build options.
  syn keyword goBuildDirectives   contained
        \ android darwin dragonfly freebsd linux nacl netbsd openbsd plan9
        \ solaris windows 386 amd64 amd64p32 arm armbe arm64 arm64be ppc64
        \ ppc64le mips mipsle mips64 mips64le mips64p32 mips64p32le ppc
        \ s390 s390x sparc sparc64 cgo ignore race

  " Other words in the build directive are build tags not listed above, so
  " avoid highlighting them as comments by using a matchgroup just for the
  " start of the comment.
  " The rs=s+2 option lets the \s*+build portion be part of the inner region
  " instead of the matchgroup so it will be highlighted as a goBuildKeyword.
  syn region  goBuildComment      matchgroup=goBuildCommentStart
        \ start="//\(\s*+build\s\|go:build\)"rs=s+2 end="$"
        \ contains=goBuildKeyword,goBuildDirectives
  hi def link goBuildCommentStart Comment
  hi def link goBuildDirectives   Type
  hi def link goBuildKeyword      PreProc
endif

if s:HighlightBuildConstraints() || s:FoldEnable('package_comment')
  " One or more line comments that are followed immediately by a "package"
  " declaration are treated like package documentation, so these must be
  " matched as comments to avoid looking like working build constraints.
  " The he, me, and re options let the "package" itself be highlighted by
  " the usual rules.
  exe 'syn region  goPackageComment    start=/\v(\/\/.*\n)+\s*package/'
        \ . ' end=/\v\n\s*package/he=e-7,me=e-7,re=e-7'
        \ . ' contains=@goCommentGroup,@Spell'
        \ . (s:FoldEnable('package_comment') ? ' fold' : '')
  exe 'syn region  goPackageComment    start=/\v^\s*\/\*.*\n(.*\n)*\s*\*\/\npackage/'
        \ . ' end=/\v\*\/\n\s*package/he=e-7,me=e-7,re=e-7'
        \ . ' contains=@goCommentGroup,@Spell'
        \ . (s:FoldEnable('package_comment') ? ' fold' : '')
  hi def link goPackageComment    Comment
endif

" :GoCoverage commands
hi def link goCoverageNormalText Comment

" Search backwards for a global declaration to start processing the syntax.
"syn sync match goSync grouphere NONE /^\(const\|var\|type\|func\)\>/

" There's a bug in the implementation of grouphere. For now, use the
" following as a more expensive/less precise workaround.
syn sync minlines=500

let b:current_syntax = "go"

let &cpo = s:keepcpo
unlet s:keepcpo

" vim: sw=2 sts=2 et
