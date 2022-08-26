" Vim syntax file
"
" Language:     CFML (ColdFusion)
" Author:       Ernst M. van der Linden <ernst.vanderlinden@ernestoz.com>
" License:      The MIT License (MIT)
"
" Maintainer:   Ernst M. van der Linden <ernst.vanderlinden@ernestoz.com>
" URL:          https://github.com/ernstvanderlinden/vim-coldfusion
" Last Change:  2017 Nov 28
"
" Filenames:    *.cfc *.cfm

" Quit when a syntax file was already loaded.
if exists("b:current_syntax")
  finish
endif

" Using line continuation here.
let s:cpo_save=&cpo
set cpo-=C

sy sync fromstart
" 20171126: disabled as we have fast computers now.
"sy sync maxlines=2000
sy case ignore

" INCLUDES {{{
sy include @sqlSyntax $VIMRUNTIME/syntax/sql.vim
" 20161010: Disabled include html highlighting as it contains huge keywords
" regex, so it will have impact on performance.  Use own simple SGML tag
" coloring instead.
"runtime! syntax/html.vim
" / INCLUDES }}}

" NUMBER {{{
sy match cfmlNumber
    \ "\v<\d+>"
" / NUMBER }}}

" EQUAL SIGN {{{
sy match cfmlEqualSign
    \ "\v\="
" / EQUAL SIGN }}}

" BOOLEAN {{{
sy match cfmlBoolean
    \ "\v<(true|false)>"
" / BOOLEAN }}}

" HASH SURROUNDED {{{
sy region cfmlHashSurround
  \ keepend
  \ oneline
  \ start="#"
  \ end="#"
  \ skip="##"
    \ contains=
      \@cfmlOperator,
      \@cfmlPunctuation,
      \cfmlBoolean,
      \cfmlCoreKeyword,
      \cfmlCoreScope,
      \cfmlCustomKeyword,
      \cfmlCustomScope,
      \cfmlEqualSign,
      \cfmlFunctionName,
      \cfmlNumber
" / HASH SURROUNDED }}}

" OPERATOR {{{

" OPERATOR - ARITHMETIC {{{
" +7 -7
" ++i --i
" i++ i--
" + - * / %
" += -= *= /= %=
" ^ mod
sy match cfmlArithmeticOperator
  \ "\v
  \(\+|-)\ze\d
  \|(\+\+|--)\ze\w
  \|\w\zs(\+\+|--)
  \|(\s(
  \(\+|-|\*|\/|\%){1}\={,1}
  \|\^
  \|mod
  \)\s)
  \"
" / OPERATOR - ARITHMETIC }}}

" OPERATOR - BOOLEAN {{{
" not and or xor eqv imp
" ! && ||
sy match cfmlBooleanOperator
  \ "\v\s
  \(not|and|or|xor|eqv|imp
  \|\!|\&\&|\|\|
  \)(\s|\))
  \|\s\!\ze\w
  \"
" / OPERATOR - BOOLEAN }}}

" OPERATOR - DECISION {{{
"is|equal|eq
"is not|not equal|neq
"contains|does not contain
"greater than|gt
"less than|lt
"greater than or equal to|gte|ge
"less than or equal to|lte|le
"==|!=|>|<|>=|<=
sy match cfmlDecisionOperator
  \ "\v\s
  \(is|equal|eq
  \|is not|not equal|neq
  \|contains|does not contain
  \|greater than|gt
  \|less than|lt
  \|greater than or equal to|gte|ge
  \|less than or equal to|lte|le
  \|(!|\<|\>|\=){1}\=
  \|\<
  \|\>
  \)\s"
" / OPERATOR - DECISION }}}

" OPERATOR - STRING {{{
" &
" &=
sy match cfmlStringOperator
    \ "\v\s\&\={,1}\s"
" / OPERATOR - STRING }}}

" OPERATOR - TERNARY {{{
" ? :
sy match cfmlTernaryOperator
  \ "\v\s
  \\?|\:
  \\s"
" / OPERATOR - TERNARY }}}

sy cluster cfmlOperator
  \ contains=
    \cfmlArithmeticOperator,
    \cfmlBooleanOperator,
    \cfmlDecisionOperator,
    \cfmlStringOperator,
    \cfmlTernaryOperator
" / OPERATOR }}}

" PARENTHESIS {{{
sy cluster cfmlParenthesisRegionContains
  \ contains=
    \@cfmlAttribute,
    \@cfmlComment,
    \@cfmlFlowStatement,
    \@cfmlOperator,
    \@cfmlPunctuation,
    \cfmlBoolean,
    \cfmlBrace,
    \cfmlCoreKeyword,
    \cfmlCoreScope,
    \cfmlCustomKeyword,
    \cfmlCustomScope,
    \cfmlEqualSign,
    \cfmlFunctionName,
    \cfmlNumber,
    \cfmlStorageKeyword,
    \cfmlStorageType

sy region cfmlParenthesisRegion1
  \ extend
  \ matchgroup=cfmlParenthesis1
  \ transparent
  \ start=/(/
  \ end=/)/
  \ contains=
    \cfmlParenthesisRegion2,
    \@cfmlParenthesisRegionContains
sy region cfmlParenthesisRegion2
  \ matchgroup=cfmlParenthesis2
  \ transparent
  \ start=/(/
  \ end=/)/
  \ contains=
    \cfmlParenthesisRegion3,
    \@cfmlParenthesisRegionContains
sy region cfmlParenthesisRegion3
  \ matchgroup=cfmlParenthesis3
  \ transparent
  \ start=/(/
  \ end=/)/
  \ contains=
    \cfmlParenthesisRegion1,
    \@cfmlParenthesisRegionContains
sy cluster cfmlParenthesisRegion
  \ contains=
    \cfmlParenthesisRegion1,
    \cfmlParenthesisRegion2,
    \cfmlParenthesisRegion3
" / PARENTHESIS }}}

" BRACE {{{
sy match cfmlBrace
    \ "{\|}"

sy region cfmlBraceRegion
  \ extend
  \ fold
  \ keepend
  \ transparent
  \ start="{"
  \ end="}"
" / BRACE }}}

" PUNCTUATION {{{

" PUNCTUATION - BRACKET {{{
sy match cfmlBracket
  \ "\(\[\|\]\)"
  \ contained
" / PUNCTUATION - BRACKET }}}

" PUNCTUATION - CHAR {{{
sy match cfmlComma ","
sy match cfmlDot "\."
sy match cfmlSemiColon ";"

" / PUNCTUATION - CHAR }}}

" PUNCTUATION - QUOTE {{{
sy region cfmlSingleQuotedValue
  \ matchgroup=cfmlSingleQuote
  \ start=/'/
  \ skip=/''/
  \ end=/'/
  \ contains=
    \cfmlHashSurround

sy region cfmlDoubleQuotedValue
  \ matchgroup=cfmlDoubleQuote
  \ start=/"/
  \ skip=/""/
  \ end=/"/
  \ contains=
    \cfmlHashSurround

sy cluster cfmlQuotedValue
  \ contains=
    \cfmlDoubleQuotedValue,
    \cfmlSingleQuotedValue

sy cluster cfmlQuote
  \ contains=
    \cfmlDoubleQuote,
    \cfmlSingleQuote
" / PUNCTUATION - QUOTE }}}

sy cluster cfmlPunctuation
  \ contains=
    \@cfmlQuote,
    \@cfmlQuotedValue,
    \cfmlBracket,
    \cfmlComma,
    \cfmlDot,
    \cfmlSemiColon

" / PUNCTUATION }}}

" TAG START AND END {{{
" tag start
" <cf...>
" s^^   e
sy region cfmlTagStart
  \ keepend
  \ transparent
  \ start="\c<cf_*"
  \ end=">"
\ contains=
  \@cfmlAttribute,
  \@cfmlComment,
  \@cfmlOperator,
  \@cfmlParenthesisRegion,
  \@cfmlPunctuation,
  \@cfmlQuote,
  \@cfmlQuotedValue,
  \cfmlAttrEqualSign,
  \cfmlBoolean,
  \cfmlBrace,
  \cfmlCoreKeyword,
  \cfmlCoreScope,
  \cfmlCustomKeyword,
  \cfmlCustomScope,
  \cfmlEqualSign,
  \cfmlFunctionName,
  \cfmlNumber,
  \cfmlStorageKeyword,
  \cfmlStorageType,
  \cfmlTagBracket,
  \cfmlTagName

" tag end
" </cf...>
" s^^^   e
sy match cfmlTagEnd
  \ transparent
  \ "\c</cf_*[^>]*>"
  \ contains=
    \cfmlTagBracket,
    \cfmlTagName

" tag bracket
" </...>
" ^^   ^
sy match cfmlTagBracket
  \ contained
  \ "\(<\|>\|\/\)"

" tag name
" <cf...>
"  s^^^e
sy match cfmlTagName
  \ contained
  \ "\v<\/*\zs\ccf\w*"
" / TAG START AND END }}}

" ATTRIBUTE NAME AND VALUE {{{
sy match cfmlAttrName
  \ contained
  \ "\v(var\s)@<!\w+\ze\s*\=([^\=])+"

sy match cfmlAttrValue
  \ contained
  \ "\v(\=\"*)\zs\s*\w*"

sy match cfmlAttrEqualSign
  \ contained
  \ "\v\="

sy cluster cfmlAttribute
\ contains=
  \@cfmlQuotedValue,
  \cfmlAttrEqualSign,
  \cfmlAttrName,
  \cfmlAttrValue,
  \cfmlCoreKeyword,
  \cfmlCoreScope
" / ATTRIBUTE NAME AND VALUE }}}

" TAG REGION AND FOLDING {{{

" CFCOMPONENT REGION AND FOLD {{{
" <cfcomponent
" s^^^^^^^^^^^
" </cfcomponent>
" ^^^^^^^^^^^^^e
sy region cfmlComponentTagRegion
  \ fold
  \ keepend
  \ transparent
  \ start="\c<cfcomponent"
  \ end="\c</cfcomponent>"

" / CFCOMPONENT REGION AND FOLD }}}

" CFFUNCTION REGION AND FOLD {{{
" <cffunction
" s^^^^^^^^^^
" </cffunction>
" ^^^^^^^^^^^^e
sy region cfmlFunctionTagRegion
  \ fold
  \ keepend
  \ transparent
  \ start="\c<cffunction"
  \ end="\c</cffunction>"
" / CFFUNCTION REGION AND FOLD }}}

" CFIF REGION AND FOLD {{{
" <cfif
" s^^^^
" </cfif>
" ^^^^^^e
sy region cfmlIfTagRegion
  \ fold
  \ keepend
  \ transparent
  \ start="\c<cfif"
  \ end="\c</cfif>"
" / CFIF REGION AND FOLD }}}

" CFLOOP REGION AND FOLD {{{
" <cfloop
" s^^^^^^
" </cfloop>
" ^^^^^^^^e
sy region cfmlLoopTagRegion
  \ fold
  \ keepend
  \ transparent
  \ start="\c<cfloop"
  \ end="\c</cfloop>"
" / CFLOOP REGION AND FOLD }}}

" CFOUTPUT REGION AND FOLD {{{
" <cfoutput
" s^^^^^^^^
" </cfoutput>
" ^^^^^^^^^^e
sy region cfmlOutputTagRegion
  \ fold
  \ keepend
  \ transparent
  \ start="\c<cfoutput"
  \ end="\c</cfoutput>"
" / CFOUTPUT REGION AND FOLD }}}

" CFQUERY REGION AND FOLD {{{
" <cfquery
" s^^^^^^^
" </cfquery>
" ^^^^^^^^^e
        "\@cfmlSqlStatement,
sy region cfmlQueryTagRegion
  \ fold
  \ keepend
  \ transparent
  \ start="\c<cfquery"
  \ end="\c</cfquery>"
  \ contains=
    \@cfmlSqlStatement,
    \cfmlTagStart,
    \cfmlTagEnd,
    \cfmlTagComment
" / CFQUERY REGION AND FOLD }}}

" SAVECONTENT REGION AND FOLD {{{
" <savecontent
" s^^^^^^^^^^^
" </savecontent>
" ^^^^^^^^^^^^^e
sy region cfmlSavecontentTagRegion
  \ fold
  \ keepend
  \ transparent
  \ start="\c<cfsavecontent"
  \ end="\c</cfsavecontent>"
" / SAVECONTENT REGION AND FOLD }}}

" CFSCRIPT REGION AND FOLD {{{
" <cfscript>
" s^^^^^^^^^
" </cfscript>
" ^^^^^^^^^^e
"\cfmlCustomScope,
sy region cfmlScriptTagRegion
  \ fold
  \ keepend
  \ transparent
  \ start="\c<cfscript>"
  \ end="\c</cfscript>"
  \ contains=
    \@cfmlComment,
    \@cfmlFlowStatement,
    \cfmlHashSurround,
    \@cfmlOperator,
    \@cfmlParenthesisRegion,
    \@cfmlPunctuation,
    \cfmlBoolean,
    \cfmlBrace,
    \cfmlCoreKeyword,
    \cfmlCoreScope,
    \cfmlCustomKeyword,
    \cfmlCustomScope,
    \cfmlEqualSign,
    \cfmlFunctionDefinition,
    \cfmlFunctionName,
    \cfmlNumber,
    \cfmlOddFunction,
    \cfmlStorageKeyword,
    \cfmlTagEnd,
    \cfmlTagStart
" / CFSCRIPT REGION AND FOLD }}}

" CFSWITCH REGION AND FOLD {{{
" <cfswitch
" s^^^^^^^^
" </cfswitch>
" ^^^^^^^^^^e
sy region cfmlSwitchTagRegion
  \ fold
  \ keepend
  \ transparent
  \ start="\c<cfswitch"
  \ end="\c</cfswitch>"
" / CFSWITCH REGION AND FOLD }}}

" CFTRANSACTION REGION AND FOLD {{{
" <cftransaction
" s^^^^^^^^^^^^^
" </cftransaction>
" ^^^^^^^^^^^^^^^e
sy region cfmlTransactionTagRegion
  \ fold
  \ keepend
  \ transparent
  \ start="\c<cftransaction"
  \ end="\c</cftransaction>"
" / CFTRANSACTION REGION AND FOLD }}}

" CUSTOM TAG REGION AND FOLD {{{
" <cf_...>
" s^^^   ^
" </cf_...>
" ^^^^^   e
sy region cfmlCustomTagRegion
  \ fold
  \ keepend
  \ transparent
  \ start="\c<cf_[^>]*>"
  \ end="\c</cf_[^>]*>"
" / CUSTOM TAG REGION AND FOLD }}}

" / TAG REGION AND FOLDING }}}

" COMMENT {{{

" COMMENT BLOCK {{{
" /*...*/
" s^   ^e
sy region cfmlCommentBlock
  \ keepend
  \ start="/\*"
  \ end="\*/"
  \ contains=
    \cfmlMetaData
" / COMMENT BLOCK }}}

" COMMENT LINE {{{
" //...
" s^
sy match cfmlCommentLine
        \ "\/\/.*"
" / COMMENT LINE }}}

sy cluster cfmlComment
  \ contains=
    \cfmlCommentBlock,
    \cfmlCommentLine
" / COMMENT }}}

" TAG COMMENT {{{
" <!---...--->
" s^^^^   ^^^e
sy region cfmlTagComment
  \ keepend
    \ start="<!---"
    \ end="--->"
    \ contains=
      \cfmlTagComment
" / TAG COMMENT }}}

" FLOW STATEMENT {{{
" BRANCH FLOW KEYWORD {{{
sy keyword cfmlBranchFlowKeyword
  \ break
  \ continue
  \ return

" / BRANCH KEYWORD }}}

" DECISION FLOW KEYWORD {{{
sy keyword cfmlDecisionFlowKeyword
  \ case
  \ defaultcase
  \ else
  \ if
  \ switch

" / DECISION FLOW KEYWORD }}}

" LOOP FLOW KEYWORD {{{
sy keyword cfmlLoopFlowKeyword
  \ do
  \ for
  \ in
  \ while

" / LOOP FLOW KEYWORD }}}

" TRY FLOW KEYWORD {{{
sy keyword cfmlTryFlowKeyword
  \ catch
  \ finally
  \ rethrow
  \ throw
  \ try

" / TRY FLOW KEYWORD }}}

sy cluster cfmlFlowStatement
  \ contains=
    \cfmlBranchFlowKeyword,
    \cfmlDecisionFlowKeyword,
    \cfmlLoopFlowKeyword,
    \cfmlTryFlowKeyword

" / FLOW STATEMENT }}}

" STORAGE KEYWORD {{{
sy keyword cfmlStorageKeyword
    \ var
" / STORAGE KEYWORD }}}

" STORAGE TYPE {{{
sy match cfmlStorageType
  \ contained
  \ "\v<
    \(any
    \|array
    \|binary
    \|boolean
    \|date
    \|numeric
    \|query
    \|string
    \|struct
    \|uuid
    \|void
    \|xml
  \){1}\ze(\s*\=)@!"
" / STORAGE TYPE }}}

" CORE KEYWORD {{{
sy match cfmlCoreKeyword
  \ "\v<
    \(new
    \|required
    \)\ze\s"
" / CORE KEYWORD }}}

" CORE SCOPE {{{
sy match cfmlCoreScope
  \ "\v<
    \(application
    \|arguments
    \|attributes
    \|caller
    \|cfcatch
    \|cffile
    \|cfhttp
    \|cgi
    \|client
    \|cookie
    \|form
    \|local
    \|request
    \|server
    \|session
    \|super
    \|this
    \|thisTag
    \|thread
    \|variables
    \|url
    \){1}\ze(,|\.|\[|\)|\s)"
" / CORE SCOPE }}}

" SQL STATEMENT {{{
sy cluster cfmlSqlStatement
  \ contains=
    \@cfmlParenthesisRegion,
    \@cfmlQuote,
    \@cfmlQuotedValue,
    \@sqlSyntax,
    \cfmlBoolean,
    \cfmlDot,
    \cfmlEqualSign,
    \cfmlFunctionName,
    \cfmlHashSurround,
    \cfmlNumber
" / SQL STATEMENT }}}

" TAG IN SCRIPT {{{
sy match cfmlTagNameInScript
    \ "\vcf_*\w+\s*\ze\("
" / TAG IN SCRIPT }}}

" METADATA {{{
sy region cfmlMetaData
  \ contained
  \ keepend
  \ start="@\w\+"
  \ end="$"
  \ contains=
    \cfmlMetaDataName

sy match cfmlMetaDataName
    \ contained
    \ "@\w\+"
" / METADATA }}}

" COMPONENT DEFINITION {{{
sy region cfmlComponentDefinition
  \ start="component"
  \ end="{"me=e-1
  \ contains=
    \@cfmlAttribute,
    \cfmlComponentKeyword

sy match cfmlComponentKeyword
  \ contained
  \ "\v<component>"
" / COMPONENT DEFINITION }}}

" INTERFACE DEFINITION {{{
sy match cfmlInterfaceDefinition
  \ "interface\s.*{"me=e-1
  \ contains=
    \cfmlInterfaceKeyword

sy match cfmlInterfaceKeyword
    \ contained
    \ "\v<interface>"
" / INTERFACE DEFINITION }}}

" PROPERTY {{{
sy region cfmlProperty
  \ transparent
  \ start="\v<property>"
  \ end=";"me=e-1
  \ contains=
    \@cfmlQuotedValue,
    \cfmlAttrEqualSign,
    \cfmlAttrName,
    \cfmlAttrValue,
    \cfmlPropertyKeyword

sy match cfmlPropertyKeyword
        \ contained
        \ "\v<property>"
" / PROPERTY }}}

" FUNCTION DEFINITION {{{
sy match cfmlFunctionDefinition
  \ "\v
    \(<(public|private|package)\s){,1}
    \(<
      \(any
      \|array
      \|binary
      \|boolean
      \|date
      \|numeric
      \|query
      \|string
      \|struct
      \|uuid
      \|void
      \|xml
    \)\s){,1}
  \<function\s\w+\s*\("me=e-1
  \ contains=
    \cfmlFunctionKeyword,
    \cfmlFunctionModifier,
    \cfmlFunctionName,
    \cfmlFunctionReturnType

" FUNCTION KEYWORD {{{
sy match cfmlFunctionKeyword
  \ contained
  \ "\v<function>"
" / FUNCTION KEYWORD }}}

" FUNCTION MODIFIER {{{
sy match cfmlFunctionModifier
  \ contained
    \ "\v<
    \(public
    \|private
    \|package
    \)>"
" / FUNCTION MODIFIER }}}

" FUNCTION RETURN TYPE {{{
sy match cfmlFunctionReturnType
  \ contained
    \ "\v
    \(any
    \|array
    \|binary
    \|boolean
    \|date
    \|numeric
    \|query
    \|string
    \|struct
    \|uuid
    \|void
    \|xml
    \)"
" / FUNCTION RETURN TYPE }}}

" FUNCTION NAME {{{
" specific regex for core functions decreases performance
" so use the same highlighting for both function types
sy match cfmlFunctionName
    \ "\v<(cf|if|elseif|throw)@!\w+\s*\ze\("
" / FUNCTION NAME }}}

" / FUNCTION DEFINITION }}}

" ODD FUNCTION {{{
sy region cfmlOddFunction
  \ transparent
  \ start="\v<
    \(abort
    \|exit
    \|import
    \|include
    \|lock
    \|pageencoding
    \|param
    \|savecontent
    \|thread
    \|transaction
    \){1}"
  \ end="\v(\{|;)"me=e-1
  \ contains=
    \@cfmlQuotedValue,
    \cfmlAttrEqualSign,
    \cfmlAttrName,
    \cfmlAttrValue,
    \cfmlCoreKeyword,
    \cfmlOddFunctionKeyword,
    \cfmlCoreScope

" ODD FUNCTION KEYWORD {{{
sy match cfmlOddFunctionKeyword
  \ contained
    \ "\v<
    \(abort
    \|exit
    \|import
    \|include
    \|lock
    \|pageencoding
    \|param
    \|savecontent
    \|thread
    \|transaction
    \)\ze(\s|$|;)"
" / ODD FUNCTION KEYWORD }}}

" / ODD FUNCTION }}}

" CUSTOM {{{

" CUSTOM KEYWORD {{{
sy match cfmlCustomKeyword
  \ contained
    \ "\v<
    \(customKeyword1
    \|customKeyword2
    \|customKeyword3
    \)>"
" / CUSTOM KEYWORD }}}

" CUSTOM SCOPE {{{
sy match cfmlCustomScope
  \ contained
    \ "\v<
    \(prc
    \|rc
    \|event
    \|(\w+Service)
    \){1}\ze(\.|\[)"
" / CUSTOM SCOPE }}}

" / CUSTOM }}}

" SGML TAG START AND END {{{
" SGML tag start
" <...>
" s^^^e
sy region cfmlSGMLTagStart
  \ keepend
  \ transparent
  \ start="\v(\<cf)@!\zs\<\w+"
  \ end=">"
  \ contains=
    \@cfmlAttribute,
    \@cfmlComment,
    \@cfmlOperator,
    \@cfmlParenthesisRegion,
    \@cfmlPunctuation,
    \@cfmlQuote,
    \@cfmlQuotedValue,
    \cfmlAttrEqualSign,
    \cfmlBoolean,
    \cfmlBrace,
    \cfmlCoreKeyword,
    \cfmlCoreScope,
    \cfmlCustomKeyword,
    \cfmlCustomScope,
    \cfmlEqualSign,
    \cfmlFunctionName,
    \cfmlNumber,
    \cfmlStorageKeyword,
    \cfmlStorageType,
    \cfmlTagBracket,
    \cfmlSGMLTagName

" SGML tag end
" </...>
" s^^^^e
sy match cfmlSGMLTagEnd
  \ transparent
  \ "\v(\<\/cf)@!\zs\<\/\w+\>"
  \ contains=
    \cfmlTagBracket,
    \cfmlSGMLTagName

" SGML tag name
" <...>
" s^^^e
sy match cfmlSGMLTagName
  \ contained
  \ "\v(\<\/*)\zs\w+"

" / SGML TAG START AND END }}}

" HIGHLIGHTING {{{

hi link cfmlNumber Number
hi link cfmlBoolean Boolean
hi link cfmlEqualSign Keyword
" HASH SURROUND
hi link cfmlHash PreProc
hi link cfmlHashSurround PreProc
" OPERATOR
hi link cfmlArithmeticOperator Function
hi link cfmlBooleanOperator Function
hi link cfmlDecisionOperator Function
hi link cfmlStringOperator Function
hi link cfmlTernaryOperator Function
" PARENTHESIS
hi link cfmlParenthesis1 Statement
hi link cfmlParenthesis2 String
hi link cfmlParenthesis3 Delimiter
" BRACE
hi link cfmlBrace PreProc
" PUNCTUATION - BRACKET
hi link cfmlBracket Statement
" PUNCTUATION - CHAR
hi link cfmlComma Comment
hi link cfmlDot Comment
hi link cfmlSemiColon Comment
" PUNCTUATION - QUOTE
hi link cfmlDoubleQuote String
hi link cfmlDoubleQuotedValue String
hi link cfmlSingleQuote String
hi link cfmlSingleQuotedValue String
" TAG START AND END
hi link cfmlTagName Function
hi link cfmlTagBracket Comment
" ATTRIBUTE NAME AND VALUE
hi link cfmlAttrName Type
hi link cfmlAttrValue Special
" COMMENT
hi link cfmlCommentBlock Comment
hi link cfmlCommentLine Comment
hi link cfmlTagComment Comment
" FLOW STATEMENT
hi link cfmlDecisionFlowKeyword Conditional
hi link cfmlLoopFlowKeyword Repeat
hi link cfmlTryFlowKeyword Exception
hi link cfmlBranchFlowKeyword Keyword
" STORAGE KEYWORD
hi link cfmlStorageKeyword Keyword
" STORAGE TYPE
hi link cfmlStorageType Keyword
" CORE KEYWORD
hi link cfmlCoreKeyword PreProc
" CORE SCOPE
hi link cfmlCoreScope Keyword
" TAG IN SCRIPT
hi link cfmlTagNameInScript Function
" METADATA
" meta data value = cfmlMetaData
hi link cfmlMetaData String
hi link cfmlMetaDataName Type
" COMPONENT DEFINITION
hi link cfmlComponentKeyword Keyword
" INTERFACE DEFINITION
hi link cfmlInterfaceKeyword Keyword
" PROPERTY
hi link cfmlPropertyKeyword Keyword
" FUNCTION DEFINITION
hi link cfmlFunctionKeyword Keyword
hi link cfmlFunctionModifier Keyword
hi link cfmlFunctionReturnType Keyword
hi link cfmlFunctionName Function
" ODD FUNCTION
hi link cfmlOddFunctionKeyword Function
" CUSTOM
hi link cfmlCustomKeyword Keyword
hi link cfmlCustomScope Structure
" SGML TAG
hi link cfmlSGMLTagName Ignore

" / HIGHLIGHTING }}}

let b:current_syntax = "cfml"

let &cpo = s:cpo_save
unlet s:cpo_save
