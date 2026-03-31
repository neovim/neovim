" Vim syntax file
"
" Language:        unison
" Maintainer:      Anton Parkhomenko <anton@chuwy.me>
" Last Change:     Oct 25, 2025
" Original Author: John Williams, Paul Chiusano and Rúnar Bjarnason

if exists("b:current_syntax")
  finish
endif

syntax include @markdown $VIMRUNTIME/syntax/markdown.vim

syn cluster markdownLikeDocs contains=markdownBold,markdownItalic,markdownLinkText,markdownListMarker,markdownOrderedListMarker,markdownH1,markdownH2,markdownH3,markdownH4,markdownH5,markdownH6

syn match unisonOperator "[-!#$%&\*\+/<=>\?@\\^|~]"
syn match unisonDelimiter "[\[\](){},.]"

" Strings and constants
syn match   unisonSpecialChar	contained "\\\([0-9]\+\|o[0-7]\+\|x[0-9a-fA-F]\+\|[\"\\'&\\abfnrtv]\|^[A-Z^_\[\\\]]\)"
syn match   unisonSpecialChar	contained "\\\(NUL\|SOH\|STX\|ETX\|EOT\|ENQ\|ACK\|BEL\|BS\|HT\|LF\|VT\|FF\|CR\|SO\|SI\|DLE\|DC1\|DC2\|DC3\|DC4\|NAK\|SYN\|ETB\|CAN\|EM\|SUB\|ESC\|FS\|GS\|RS\|US\|SP\|DEL\)"
syn match   unisonSpecialCharError	contained "\\&\|'''\+"
syn region  unisonString		start=+"+  skip=+\\\\\|\\"+  end=+"+  contains=unisonSpecialChar
syn match   unisonCharacter		"[^a-zA-Z0-9_']'\([^\\]\|\\[^']\+\|\\'\)'"lc=1 contains=unisonSpecialChar,unisonSpecialCharError
syn match   unisonCharacter		"^'\([^\\]\|\\[^']\+\|\\'\)'" contains=unisonSpecialChar,unisonSpecialCharError
syn match   unisonNumber		"\<[0-9]\+\>\|\<0[xX][0-9a-fA-F]\+\>\|\<0[oO][0-7]\+\>\|\<0[bB][01]\+\>"
syn match   unisonFloat		"\<[0-9]\+\.[0-9]\+\([eE][-+]\=[0-9]\+\)\=\>"

" Keyword definitions. These must be patterns instead of keywords
" because otherwise they would match as keywords at the start of a
" "literate" comment (see lu.vim).
syn match unisonModule		"\<namespace\>"
syn match unisonImport		"\<use\>"
syn match unisonTypedef		"\<\(unique\|structural\|∀\|forall\)\>"
syn match unisonStatement		"\<\(ability\|do\|type\|where\|match\|cases\|;\|let\|with\|handle\)\>"
syn match unisonConditional		"\<\(if\|else\|then\)\>"

syn match unisonBoolean "\<\(true\|false\)\>"

syn match unisonType "\<\C[A-Z][0-9A-Za-z_'!]*\>"
syn match unisonName "\<\C[a-z_][0-9A-Za-z_'!]*\>" contains=ALL
syn match unisonDef "^\C[A-Za-z_][0-9A-Za-z_'!]*:"

" Comments
syn match   unisonLineComment      "---*\([^-!#$%&\*\+./<=>\?@\\^|~].*\)\?$"
syn region  unisonBlockComment     start="{-"  end="-}" contains=unisonBlockComment
syn region  unisonBelowFold	   start="^---" skip="." end="." contains=unisonBelowFold

" Docs
syn region  unisonDocBlock         matchgroup=unisonDoc start="{{" end="}}" contains=unisonDocTypecheck,unisonDocQuasiquote,unisonDocDirective,unisonDocCode,unisonDocCodeInline,unisonDocCodeRaw,unisonDocMono,@markdownLikeDocs
syn region  unisonDocQuasiquote    contained matchgroup=unisonDocQuote start="{{" end= "}}" contains=TOP
syn region  unisonDocCode          contained matchgroup=unisonDocCode start="^\s*```\s*$" end="^\s*```\s*$" contains=TOP
syn region  unisonDocTypecheck     contained matchgroup=unisonDocCode start="^\s*@typecheck\s*```\s*$" end="^\s*```\s*$" contains=TOP
syn region  unisonDocCodeRaw       contained matchgroup=unisonDocCode start="^\s*```\s*raw\s*$" end="^\s*```\s*$" contains=NoSyntax
syn region  unisonDocCodeInline    contained matchgroup=unisonDocCode start="`\@<!``" end="`\@<!``" contains=TOP
syn match   unisonDocMono          "''[^']*''"
syn region  unisonDocDirective     contained matchgroup=unisonDocDirective start="\(@\([a-zA-Z0-9_']*\)\)\?{{\@!" end="}" contains=TOP

syn match unisonDebug "\<\(todo\|bug\|Debug.trace\|Debug.evalToText\)\>"

" things like
"    > my_func 1 3
"    test> Function.tap.tests.t1 = check let
"      use Nat == +
"      ( 99, 100 ) === (withInitialValue 0 do
"          :      :      :
syn match unisonWatch "^[A-Za-z]*>"

hi def link       unisonWatch                           Debug
hi def link       unisonDocMono                         Delimiter
hi def link       unisonDocDirective                    Import
hi def link       unisonDocQuote                        Delimiter
hi def link       unisonDocCode                         Delimiter
hi def link       unisonDoc                             String
hi def link       unisonBelowFold                       Comment
hi def link       unisonBlockComment                    Comment
hi def link       unisonBoolean                         Boolean
hi def link       unisonCharacter                       Character
hi def link       unisonComment                         Comment
hi def link       unisonConditional                     Conditional
hi def link       unisonConditional                     Conditional
hi def link       unisonDebug                           Debug
hi def link       unisonDelimiter                       Delimiter
hi def link       unisonDocBlock                        String
hi def link       unisonDocDirective                    Import
hi def link       unisonDocIncluded                     Import
hi def link       unisonFloat                           Float
hi def link       unisonImport                          Include
hi def link       unisonLineComment                     Comment
hi def link       unisonLink                            Type
hi def link       unisonName                            Identifier
hi def link       unisonDef                             Typedef
hi def link       unisonNumber                          Number
hi def link       unisonOperator                        Operator
hi def link       unisonSpecialChar                     SpecialChar
hi def link       unisonSpecialCharError                Error
hi def link       unisonStatement                       Statement
hi def link       unisonString                          String
hi def link       unisonType                            Type
hi def link       unisonTypedef                         Typedef


let b:current_syntax = "unison"

" Options for vi: ts=8 sw=2 sts=2 nowrap noexpandtab ft=vim
