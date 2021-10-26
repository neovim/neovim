" Vim syntax file
" Language:     TypeScript and TypeScriptReact
" Maintainer:   Bram Moolenaar, Herrington Darkholme
" Last Change:	2021 Sep 22
" Based On:     Herrington Darkholme's yats.vim
" Changes:      See https:github.com/HerringtonDarkholme/yats.vim
" Credits:      See yats.vim on github

if &cpo =~ 'C'
  let s:cpo_save = &cpo
  set cpo&vim
endif


" NOTE: this results in accurate highlighting, but can be slow.
syntax sync fromstart

"Dollar sign is permitted anywhere in an identifier
setlocal iskeyword-=$
if main_syntax == 'typescript' || main_syntax == 'typescriptreact'
  setlocal iskeyword+=$
  " syntax cluster htmlJavaScript                 contains=TOP
endif
" For private field added from TypeScript 3.8
setlocal iskeyword+=#

" lowest priority on least used feature
syntax match   typescriptLabel                /[a-zA-Z_$]\k*:/he=e-1 contains=typescriptReserved nextgroup=@typescriptStatement skipwhite skipempty

" other keywords like return,case,yield uses containedin
syntax region  typescriptBlock                 matchgroup=typescriptBraces start=/{/ end=/}/ contains=@typescriptStatement,@typescriptComments fold
syntax cluster afterIdentifier contains=
  \ typescriptDotNotation,
  \ typescriptFuncCallArg,
  \ typescriptTemplate,
  \ typescriptIndexExpr,
  \ @typescriptSymbols,
  \ typescriptTypeArguments

syntax match   typescriptIdentifierName        /\<\K\k*/
  \ nextgroup=@afterIdentifier
  \ transparent
  \ contains=@_semantic
  \ skipnl skipwhite

syntax match   typescriptProp contained /\K\k*!\?/
  \ transparent
  \ contains=@props
  \ nextgroup=@afterIdentifier
  \ skipwhite skipempty

syntax region  typescriptIndexExpr      contained matchgroup=typescriptProperty start=/\[/rs=s+1 end=/]/he=e-1 contains=@typescriptValue nextgroup=@typescriptSymbols,typescriptDotNotation,typescriptFuncCallArg skipwhite skipempty

syntax match   typescriptDotNotation           /\.\|?\.\|!\./ nextgroup=typescriptProp skipnl
syntax match   typescriptDotStyleNotation      /\.style\./ nextgroup=typescriptDOMStyle transparent
" syntax match   typescriptFuncCall              contained /[a-zA-Z]\k*\ze(/ nextgroup=typescriptFuncCallArg
syntax region  typescriptParenExp              matchgroup=typescriptParens start=/(/ end=/)/ contains=@typescriptComments,@typescriptValue,typescriptCastKeyword nextgroup=@typescriptSymbols skipwhite skipempty
syntax region  typescriptFuncCallArg           contained matchgroup=typescriptParens start=/(/ end=/)/ contains=@typescriptValue,@typescriptComments nextgroup=@typescriptSymbols,typescriptDotNotation skipwhite skipempty skipnl
syntax region  typescriptEventFuncCallArg      contained matchgroup=typescriptParens start=/(/ end=/)/ contains=@typescriptEventExpression
syntax region  typescriptEventString           contained start=/\z(["']\)/  skip=/\\\\\|\\\z1\|\\\n/  end=/\z1\|$/ contains=typescriptASCII,@events

syntax region  typescriptDestructureString
  \ start=/\z(["']\)/  skip=/\\\\\|\\\z1\|\\\n/  end=/\z1\|$/
  \ contains=typescriptASCII
  \ nextgroup=typescriptDestructureAs
  \ contained skipwhite skipempty

syntax cluster typescriptVariableDeclarations
  \ contains=typescriptVariableDeclaration,@typescriptDestructures

syntax match typescriptVariableDeclaration /[A-Za-z_$]\k*/
  \ nextgroup=typescriptTypeAnnotation,typescriptAssign
  \ contained skipwhite skipempty

syntax cluster typescriptDestructureVariables contains=
  \ typescriptRestOrSpread,
  \ typescriptDestructureComma,
  \ typescriptDestructureLabel,
  \ typescriptDestructureVariable,
  \ @typescriptDestructures

syntax match typescriptDestructureVariable    /[A-Za-z_$]\k*/ contained
  \ nextgroup=typescriptDefaultParam
  \ contained skipwhite skipempty

syntax match typescriptDestructureLabel       /[A-Za-z_$]\k*\ze\_s*:/
  \ nextgroup=typescriptDestructureAs
  \ contained skipwhite skipempty

syntax match typescriptDestructureAs /:/
  \ nextgroup=typescriptDestructureVariable,@typescriptDestructures
  \ contained skipwhite skipempty

syntax match typescriptDestructureComma /,/ contained

syntax cluster typescriptDestructures contains=
  \ typescriptArrayDestructure,
  \ typescriptObjectDestructure

syntax region typescriptArrayDestructure matchgroup=typescriptBraces
  \ start=/\[/ end=/]/
  \ contains=@typescriptDestructureVariables,@typescriptComments
  \ nextgroup=typescriptTypeAnnotation,typescriptAssign
  \ transparent contained skipwhite skipempty fold

syntax region typescriptObjectDestructure matchgroup=typescriptBraces
  \ start=/{/ end=/}/
  \ contains=typescriptDestructureString,@typescriptDestructureVariables,@typescriptComments
  \ nextgroup=typescriptTypeAnnotation,typescriptAssign
  \ transparent contained skipwhite skipempty fold

"Syntax in the JavaScript code

" String
syntax match   typescriptASCII                 contained /\\\d\d\d/

syntax region  typescriptTemplateSubstitution matchgroup=typescriptTemplateSB
  \ start=/\${/ end=/}/
  \ contains=@typescriptValue
  \ contained


syntax region  typescriptString 
  \ start=+\z(["']\)+  skip=+\\\%(\z1\|$\)+  end=+\z1+ end=+$+
  \ contains=typescriptSpecial,@Spell
  \ extend

syntax match   typescriptSpecial            contained "\v\\%(x\x\x|u%(\x{4}|\{\x{1,6}})|c\u|.)"

" From vim runtime
" <https://github.com/vim/vim/blob/master/runtime/syntax/javascript.vim#L48>
syntax region  typescriptRegexpString          start=+/[^/*]+me=e-1 skip=+\\\\\|\\/+ end=+/[gimuy]\{0,5\}\s*$+ end=+/[gimuy]\{0,5\}\s*[;.,)\]}:]+me=e-1 nextgroup=typescriptDotNotation oneline

syntax region  typescriptTemplate
  \ start=/`/  skip=/\\\\\|\\`\|\n/  end=/`\|$/
  \ contains=typescriptTemplateSubstitution,typescriptSpecial,@Spell
  \ nextgroup=@typescriptSymbols
  \ skipwhite skipempty

"Array
syntax region  typescriptArray matchgroup=typescriptBraces
  \ start=/\[/ end=/]/
  \ contains=@typescriptValue,@typescriptComments
  \ nextgroup=@typescriptSymbols,typescriptDotNotation
  \ skipwhite skipempty fold

" Number
syntax match typescriptNumber /\<0[bB][01][01_]*\>/        nextgroup=@typescriptSymbols skipwhite skipempty
syntax match typescriptNumber /\<0[oO][0-7][0-7_]*\>/       nextgroup=@typescriptSymbols skipwhite skipempty
syntax match typescriptNumber /\<0[xX][0-9a-fA-F][0-9a-fA-F_]*\>/ nextgroup=@typescriptSymbols skipwhite skipempty
syntax match typescriptNumber /\<\%(\d[0-9_]*\%(\.\d[0-9_]*\)\=\|\.\d[0-9_]*\)\%([eE][+-]\=\d[0-9_]*\)\=\>/
  \ nextgroup=typescriptSymbols skipwhite skipempty

syntax region  typescriptObjectLiteral         matchgroup=typescriptBraces
  \ start=/{/ end=/}/
  \ contains=@typescriptComments,typescriptObjectLabel,typescriptStringProperty,typescriptComputedPropertyName,typescriptObjectAsyncKeyword
  \ fold contained

syntax keyword typescriptObjectAsyncKeyword async contained

syntax match   typescriptObjectLabel  contained /\k\+\_s*/
  \ nextgroup=typescriptObjectColon,@typescriptCallImpl
  \ skipwhite skipempty

syntax region  typescriptStringProperty   contained
  \ start=/\z(["']\)/  skip=/\\\\\|\\\z1\|\\\n/  end=/\z1/
  \ nextgroup=typescriptObjectColon,@typescriptCallImpl
  \ skipwhite skipempty

" syntax region  typescriptPropertyName    contained start=/\z(["']\)/  skip=/\\\\\|\\\z1\|\\\n/  end=/\z1(/me=e-1 nextgroup=@typescriptCallSignature skipwhite skipempty oneline
syntax region  typescriptComputedPropertyName  contained matchgroup=typescriptBraces
  \ start=/\[/rs=s+1 end=/]/
  \ contains=@typescriptValue
  \ nextgroup=typescriptObjectColon,@typescriptCallImpl
  \ skipwhite skipempty

" syntax region  typescriptComputedPropertyName  contained matchgroup=typescriptPropertyName start=/\[/rs=s+1 end=/]\_s*:/he=e-1 contains=@typescriptValue nextgroup=@typescriptValue skipwhite skipempty
" syntax region  typescriptComputedPropertyName  contained matchgroup=typescriptPropertyName start=/\[/rs=s+1 end=/]\_s*(/me=e-1 contains=@typescriptValue nextgroup=@typescriptCallSignature skipwhite skipempty
" Value for object, statement for label statement
syntax match typescriptRestOrSpread /\.\.\./ contained
syntax match typescriptObjectSpread /\.\.\./ contained containedin=typescriptObjectLiteral,typescriptArray nextgroup=@typescriptValue

syntax match typescriptObjectColon contained /:/ nextgroup=@typescriptValue skipwhite skipempty

" + - ^ ~
syntax match typescriptUnaryOp /[+\-~!]/
 \ nextgroup=@typescriptValue
 \ skipwhite

syntax region typescriptTernary matchgroup=typescriptTernaryOp start=/?[.?]\@!/ end=/:/ contained contains=@typescriptValue,@typescriptComments nextgroup=@typescriptValue skipwhite skipempty

syntax match   typescriptAssign  /=/ nextgroup=@typescriptValue
  \ skipwhite skipempty

" 2: ==, ===
syntax match   typescriptBinaryOp contained /===\?/ nextgroup=@typescriptValue skipwhite skipempty
" 6: >>>=, >>>, >>=, >>, >=, >
syntax match   typescriptBinaryOp contained />\(>>=\|>>\|>=\|>\|=\)\?/ nextgroup=@typescriptValue skipwhite skipempty
" 4: <<=, <<, <=, <
syntax match   typescriptBinaryOp contained /<\(<=\|<\|=\)\?/ nextgroup=@typescriptValue skipwhite skipempty
" 3: ||, |=, |, ||=
syntax match   typescriptBinaryOp contained /||\?=\?/ nextgroup=@typescriptValue skipwhite skipempty
" 4: &&, &=, &, &&=
syntax match   typescriptBinaryOp contained /&&\?=\?/ nextgroup=@typescriptValue skipwhite skipempty
" 2: ??, ??=
syntax match   typescriptBinaryOp contained /??=\?/ nextgroup=@typescriptValue skipwhite skipempty
" 2: *=, *
syntax match   typescriptBinaryOp contained /\*=\?/ nextgroup=@typescriptValue skipwhite skipempty
" 2: %=, %
syntax match   typescriptBinaryOp contained /%=\?/ nextgroup=@typescriptValue skipwhite skipempty
" 2: /=, /
syntax match   typescriptBinaryOp contained +/\(=\|[^\*/]\@=\)+ nextgroup=@typescriptValue skipwhite skipempty
syntax match   typescriptBinaryOp contained /!==\?/ nextgroup=@typescriptValue skipwhite skipempty
" 2: !=, !==
syntax match   typescriptBinaryOp contained /+\(+\|=\)\?/ nextgroup=@typescriptValue skipwhite skipempty
" 3: +, ++, +=
syntax match   typescriptBinaryOp contained /-\(-\|=\)\?/ nextgroup=@typescriptValue skipwhite skipempty
" 3: -, --, -=

" exponentiation operator
" 2: **, **=
syntax match typescriptBinaryOp contained /\*\*=\?/ nextgroup=@typescriptValue

syntax cluster typescriptSymbols               contains=typescriptBinaryOp,typescriptKeywordOp,typescriptTernary,typescriptAssign,typescriptCastKeyword

" runtime syntax/basic/reserved.vim
"Import
syntax keyword typescriptImport                from as
syntax keyword typescriptImport                import
  \ nextgroup=typescriptImportType
  \ skipwhite
syntax keyword typescriptImportType            type
  \ contained
syntax keyword typescriptExport                export
  \ nextgroup=typescriptExportType
  \ skipwhite
syntax match typescriptExportType              /\<type\s*{\@=/
  \ contained skipwhite skipempty skipnl
syntax keyword typescriptModule                namespace module

"this

"JavaScript Prototype
syntax keyword typescriptPrototype             prototype
  \ nextgroup=@afterIdentifier

syntax keyword typescriptCastKeyword           as
  \ nextgroup=@typescriptType
  \ skipwhite

"Program Keywords
syntax keyword typescriptIdentifier            arguments this super
  \ nextgroup=@afterIdentifier

syntax keyword typescriptVariable              let var
  \ nextgroup=@typescriptVariableDeclarations
  \ skipwhite skipempty

syntax keyword typescriptVariable const
  \ nextgroup=typescriptEnum,@typescriptVariableDeclarations
  \ skipwhite skipempty

syntax region typescriptEnum matchgroup=typescriptEnumKeyword start=/enum / end=/\ze{/
  \ nextgroup=typescriptBlock
  \ skipwhite

syntax keyword typescriptKeywordOp
  \ contained in instanceof nextgroup=@typescriptValue
syntax keyword typescriptOperator              delete new typeof void
  \ nextgroup=@typescriptValue
  \ skipwhite skipempty

syntax keyword typescriptForOperator           contained in of
syntax keyword typescriptBoolean               true false nextgroup=@typescriptSymbols skipwhite skipempty
syntax keyword typescriptNull                  null undefined nextgroup=@typescriptSymbols skipwhite skipempty
syntax keyword typescriptMessage               alert confirm prompt status
  \ nextgroup=typescriptDotNotation,typescriptFuncCallArg
syntax keyword typescriptGlobal                self top parent
  \ nextgroup=@afterIdentifier

"Statement Keywords
syntax keyword typescriptConditional           if else switch
  \ nextgroup=typescriptConditionalParen
  \ skipwhite skipempty skipnl
syntax keyword typescriptConditionalElse       else
syntax keyword typescriptRepeat                do while for nextgroup=typescriptLoopParen skipwhite skipempty
syntax keyword typescriptRepeat                for nextgroup=typescriptLoopParen,typescriptAsyncFor skipwhite skipempty
syntax keyword typescriptBranch                break continue containedin=typescriptBlock
syntax keyword typescriptCase                  case nextgroup=@typescriptPrimitive skipwhite containedin=typescriptBlock
syntax keyword typescriptDefault               default containedin=typescriptBlock nextgroup=@typescriptValue,typescriptClassKeyword,typescriptInterfaceKeyword skipwhite oneline
syntax keyword typescriptStatementKeyword      with
syntax keyword typescriptStatementKeyword      yield skipwhite nextgroup=@typescriptValue containedin=typescriptBlock
syntax keyword typescriptStatementKeyword      return skipwhite contained nextgroup=@typescriptValue containedin=typescriptBlock

syntax keyword typescriptTry                   try
syntax keyword typescriptExceptions            catch throw finally
syntax keyword typescriptDebugger              debugger

syntax keyword typescriptAsyncFor              await nextgroup=typescriptLoopParen skipwhite skipempty contained

syntax region  typescriptLoopParen             contained matchgroup=typescriptParens
  \ start=/(/ end=/)/
  \ contains=typescriptVariable,typescriptForOperator,typescriptEndColons,@typescriptValue,@typescriptComments
  \ nextgroup=typescriptBlock
  \ skipwhite skipempty
syntax region  typescriptConditionalParen             contained matchgroup=typescriptParens
  \ start=/(/ end=/)/
  \ contains=@typescriptValue,@typescriptComments
  \ nextgroup=typescriptBlock
  \ skipwhite skipempty
syntax match   typescriptEndColons             /[;,]/ contained

syntax keyword typescriptAmbientDeclaration declare nextgroup=@typescriptAmbients
  \ skipwhite skipempty

syntax cluster typescriptAmbients contains=
  \ typescriptVariable,
  \ typescriptFuncKeyword,
  \ typescriptClassKeyword,
  \ typescriptAbstract,
  \ typescriptEnumKeyword,typescriptEnum,
  \ typescriptModule

"Syntax coloring for Node.js shebang line
syntax match   shellbang "^#!.*node\>"
syntax match   shellbang "^#!.*iojs\>"


"JavaScript comments
syntax keyword typescriptCommentTodo TODO FIXME XXX TBD
syntax match typescriptMagicComment "@ts-\%(ignore\|expect-error\)\>"
syntax match   typescriptLineComment "//.*"
  \ contains=@Spell,typescriptCommentTodo,typescriptRef,typescriptMagicComment
syntax region  typescriptComment
  \ start="/\*"  end="\*/"
  \ contains=@Spell,typescriptCommentTodo extend
syntax cluster typescriptComments
  \ contains=typescriptDocComment,typescriptComment,typescriptLineComment

syntax match   typescriptRef  +///\s*<reference\s\+.*\/>$+
  \ contains=typescriptString
syntax match   typescriptRef  +///\s*<amd-dependency\s\+.*\/>$+
  \ contains=typescriptString
syntax match   typescriptRef  +///\s*<amd-module\s\+.*\/>$+
  \ contains=typescriptString

"JSDoc
syntax case ignore

syntax region  typescriptDocComment            matchgroup=typescriptComment
  \ start="/\*\*"  end="\*/"
  \ contains=typescriptDocNotation,typescriptCommentTodo,@Spell
  \ fold keepend
syntax match   typescriptDocNotation           contained /@/ nextgroup=typescriptDocTags

syntax keyword typescriptDocTags               contained constant constructor constructs function ignore inner private public readonly static
syntax keyword typescriptDocTags               contained const dict expose inheritDoc interface nosideeffects override protected struct internal
syntax keyword typescriptDocTags               contained example global
syntax keyword typescriptDocTags               contained alpha beta defaultValue eventProperty experimental label
syntax keyword typescriptDocTags               contained packageDocumentation privateRemarks remarks sealed typeParam

" syntax keyword typescriptDocTags               contained ngdoc nextgroup=typescriptDocNGDirective
syntax keyword typescriptDocTags               contained ngdoc scope priority animations
syntax keyword typescriptDocTags               contained ngdoc restrict methodOf propertyOf eventOf eventType nextgroup=typescriptDocParam skipwhite
syntax keyword typescriptDocNGDirective        contained overview service object function method property event directive filter inputType error

syntax keyword typescriptDocTags               contained abstract virtual access augments

syntax keyword typescriptDocTags               contained arguments callback lends memberOf name type kind link mixes mixin tutorial nextgroup=typescriptDocParam skipwhite
syntax keyword typescriptDocTags               contained variation nextgroup=typescriptDocNumParam skipwhite

syntax keyword typescriptDocTags               contained author class classdesc copyright default defaultvalue nextgroup=typescriptDocDesc skipwhite
syntax keyword typescriptDocTags               contained deprecated description external host nextgroup=typescriptDocDesc skipwhite
syntax keyword typescriptDocTags               contained file fileOverview overview namespace requires since version nextgroup=typescriptDocDesc skipwhite
syntax keyword typescriptDocTags               contained summary todo license preserve nextgroup=typescriptDocDesc skipwhite

syntax keyword typescriptDocTags               contained borrows exports nextgroup=typescriptDocA skipwhite
syntax keyword typescriptDocTags               contained param arg argument property prop module nextgroup=typescriptDocNamedParamType,typescriptDocParamName skipwhite
syntax keyword typescriptDocTags               contained define enum extends implements this typedef nextgroup=typescriptDocParamType skipwhite
syntax keyword typescriptDocTags               contained return returns throws exception nextgroup=typescriptDocParamType,typescriptDocParamName skipwhite
syntax keyword typescriptDocTags               contained see nextgroup=typescriptDocRef skipwhite

syntax keyword typescriptDocTags               contained function func method nextgroup=typescriptDocName skipwhite
syntax match   typescriptDocName               contained /\h\w*/

syntax keyword typescriptDocTags               contained fires event nextgroup=typescriptDocEventRef skipwhite
syntax match   typescriptDocEventRef           contained /\h\w*#\(\h\w*\:\)\?\h\w*/

syntax match   typescriptDocNamedParamType     contained /{.\+}/ nextgroup=typescriptDocParamName skipwhite
syntax match   typescriptDocParamName          contained /\[\?0-9a-zA-Z_\.]\+\]\?/ nextgroup=typescriptDocDesc skipwhite
syntax match   typescriptDocParamType          contained /{.\+}/ nextgroup=typescriptDocDesc skipwhite
syntax match   typescriptDocA                  contained /\%(#\|\w\|\.\|:\|\/\)\+/ nextgroup=typescriptDocAs skipwhite
syntax match   typescriptDocAs                 contained /\s*as\s*/ nextgroup=typescriptDocB skipwhite
syntax match   typescriptDocB                  contained /\%(#\|\w\|\.\|:\|\/\)\+/
syntax match   typescriptDocParam              contained /\%(#\|\w\|\.\|:\|\/\|-\)\+/
syntax match   typescriptDocNumParam           contained /\d\+/
syntax match   typescriptDocRef                contained /\%(#\|\w\|\.\|:\|\/\)\+/
syntax region  typescriptDocLinkTag            contained matchgroup=typescriptDocLinkTag start=/{/ end=/}/ contains=typescriptDocTags

syntax cluster typescriptDocs                  contains=typescriptDocParamType,typescriptDocNamedParamType,typescriptDocParam

if exists("main_syntax") && main_syntax == "typescript"
  syntax sync clear
  syntax sync ccomment typescriptComment minlines=200
endif

syntax case match

" Types
syntax match typescriptOptionalMark /?/ contained

syntax cluster typescriptTypeParameterCluster contains=
  \ typescriptTypeParameter,
  \ typescriptGenericDefault

syntax region typescriptTypeParameters matchgroup=typescriptTypeBrackets
  \ start=/</ end=/>/
  \ contains=@typescriptTypeParameterCluster
  \ contained

syntax match typescriptTypeParameter /\K\k*/
  \ nextgroup=typescriptConstraint
  \ contained skipwhite skipnl

syntax keyword typescriptConstraint extends
  \ nextgroup=@typescriptType
  \ contained skipwhite skipnl

syntax match typescriptGenericDefault /=/
  \ nextgroup=@typescriptType
  \ contained skipwhite

"><
" class A extend B<T> {} // ClassBlock
" func<T>() // FuncCallArg
syntax region typescriptTypeArguments matchgroup=typescriptTypeBrackets
  \ start=/\></ end=/>/
  \ contains=@typescriptType
  \ nextgroup=typescriptFuncCallArg,@typescriptTypeOperator
  \ contained skipwhite


syntax cluster typescriptType contains=
  \ @typescriptPrimaryType,
  \ typescriptUnion,
  \ @typescriptFunctionType,
  \ typescriptConstructorType

" array type: A[]
" type indexing A['key']
syntax region typescriptTypeBracket contained
  \ start=/\[/ end=/\]/
  \ contains=typescriptString,typescriptNumber
  \ nextgroup=@typescriptTypeOperator
  \ skipwhite skipempty

syntax cluster typescriptPrimaryType contains=
  \ typescriptParenthesizedType,
  \ typescriptPredefinedType,
  \ typescriptTypeReference,
  \ typescriptObjectType,
  \ typescriptTupleType,
  \ typescriptTypeQuery,
  \ typescriptStringLiteralType,
  \ typescriptTemplateLiteralType,
  \ typescriptReadonlyArrayKeyword,
  \ typescriptAssertType

syntax region  typescriptStringLiteralType contained
  \ start=/\z(["']\)/  skip=/\\\\\|\\\z1\|\\\n/  end=/\z1\|$/
  \ nextgroup=typescriptUnion
  \ skipwhite skipempty

syntax region  typescriptTemplateLiteralType contained
  \ start=/`/  skip=/\\\\\|\\`\|\n/  end=/`\|$/
  \ contains=typescriptTemplateSubstitutionType
  \ nextgroup=typescriptTypeOperator
  \ skipwhite skipempty

syntax region  typescriptTemplateSubstitutionType matchgroup=typescriptTemplateSB
  \ start=/\${/ end=/}/
  \ contains=@typescriptType
  \ contained

syntax region typescriptParenthesizedType matchgroup=typescriptParens
  \ start=/(/ end=/)/
  \ contains=@typescriptType
  \ nextgroup=@typescriptTypeOperator
  \ contained skipwhite skipempty fold

syntax match typescriptTypeReference /\K\k*\(\.\K\k*\)*/
  \ nextgroup=typescriptTypeArguments,@typescriptTypeOperator,typescriptUserDefinedType
  \ skipwhite contained skipempty

syntax keyword typescriptPredefinedType any number boolean string void never undefined null object unknown
  \ nextgroup=@typescriptTypeOperator
  \ contained skipwhite skipempty

syntax match typescriptPredefinedType /unique symbol/
  \ nextgroup=@typescriptTypeOperator
  \ contained skipwhite skipempty

syntax region typescriptObjectType matchgroup=typescriptBraces
  \ start=/{/ end=/}/
  \ contains=@typescriptTypeMember,typescriptEndColons,@typescriptComments,typescriptAccessibilityModifier,typescriptReadonlyModifier
  \ nextgroup=@typescriptTypeOperator
  \ contained skipwhite skipnl fold

syntax cluster typescriptTypeMember contains=
  \ @typescriptCallSignature,
  \ typescriptConstructSignature,
  \ typescriptIndexSignature,
  \ @typescriptMembers

syntax match typescriptTupleLable /\K\k*?\?:/
    \ contained

syntax region typescriptTupleType matchgroup=typescriptBraces
  \ start=/\[/ end=/\]/
  \ contains=@typescriptType,@typescriptComments,typescriptRestOrSpread,typescriptTupleLable
  \ contained skipwhite

syntax cluster typescriptTypeOperator
  \ contains=typescriptUnion,typescriptTypeBracket,typescriptConstraint,typescriptConditionalType

syntax match typescriptUnion /|\|&/ contained nextgroup=@typescriptPrimaryType skipwhite skipempty

syntax match typescriptConditionalType /?\|:/ contained nextgroup=@typescriptPrimaryType skipwhite skipempty

syntax cluster typescriptFunctionType contains=typescriptGenericFunc,typescriptFuncType
syntax region typescriptGenericFunc matchgroup=typescriptTypeBrackets
  \ start=/</ end=/>/
  \ contains=typescriptTypeParameter
  \ nextgroup=typescriptFuncType
  \ containedin=typescriptFunctionType
  \ contained skipwhite skipnl

syntax region typescriptFuncType matchgroup=typescriptParens
  \ start=/(/ end=/)\s*=>/me=e-2
  \ contains=@typescriptParameterList
  \ nextgroup=typescriptFuncTypeArrow
  \ contained skipwhite skipnl oneline

syntax match typescriptFuncTypeArrow /=>/
  \ nextgroup=@typescriptType
  \ containedin=typescriptFuncType
  \ contained skipwhite skipnl


syntax keyword typescriptConstructorType new
  \ nextgroup=@typescriptFunctionType
  \ contained skipwhite skipnl

syntax keyword typescriptUserDefinedType is
  \ contained nextgroup=@typescriptType skipwhite skipempty

syntax keyword typescriptTypeQuery typeof keyof
  \ nextgroup=typescriptTypeReference
  \ contained skipwhite skipnl

syntax keyword typescriptAssertType asserts
  \ nextgroup=typescriptTypeReference
  \ contained skipwhite skipnl

syntax cluster typescriptCallSignature contains=typescriptGenericCall,typescriptCall
syntax region typescriptGenericCall matchgroup=typescriptTypeBrackets
  \ start=/</ end=/>/
  \ contains=typescriptTypeParameter
  \ nextgroup=typescriptCall
  \ contained skipwhite skipnl
syntax region typescriptCall matchgroup=typescriptParens
  \ start=/(/ end=/)/
  \ contains=typescriptDecorator,@typescriptParameterList,@typescriptComments
  \ nextgroup=typescriptTypeAnnotation,typescriptBlock
  \ contained skipwhite skipnl

syntax match typescriptTypeAnnotation /:/
  \ nextgroup=@typescriptType
  \ contained skipwhite skipnl

syntax cluster typescriptParameterList contains=
  \ typescriptTypeAnnotation,
  \ typescriptAccessibilityModifier,
  \ typescriptReadonlyModifier,
  \ typescriptOptionalMark,
  \ typescriptRestOrSpread,
  \ typescriptFuncComma,
  \ typescriptDefaultParam

syntax match typescriptFuncComma /,/ contained

syntax match typescriptDefaultParam /=/
  \ nextgroup=@typescriptValue
  \ contained skipwhite

syntax keyword typescriptConstructSignature new
  \ nextgroup=@typescriptCallSignature
  \ contained skipwhite

syntax region typescriptIndexSignature matchgroup=typescriptBraces
  \ start=/\[/ end=/\]/
  \ contains=typescriptPredefinedType,typescriptMappedIn,typescriptString
  \ nextgroup=typescriptTypeAnnotation
  \ contained skipwhite oneline

syntax keyword typescriptMappedIn in
  \ nextgroup=@typescriptType
  \ contained skipwhite skipnl skipempty

syntax keyword typescriptAliasKeyword type
  \ nextgroup=typescriptAliasDeclaration
  \ skipwhite skipnl skipempty

syntax region typescriptAliasDeclaration matchgroup=typescriptUnion
  \ start=/ / end=/=/
  \ nextgroup=@typescriptType
  \ contains=typescriptConstraint,typescriptTypeParameters
  \ contained skipwhite skipempty

syntax keyword typescriptReadonlyArrayKeyword readonly
  \ nextgroup=@typescriptPrimaryType
  \ skipwhite


" extension
if get(g:, 'yats_host_keyword', 1)
  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Function Boolean
  " use of nextgroup Suggested by Doug Kearns
  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Error EvalError nextgroup=typescriptFuncCallArg
  syntax keyword typescriptGlobal containedin=typescriptIdentifierName InternalError
  syntax keyword typescriptGlobal containedin=typescriptIdentifierName RangeError ReferenceError
  syntax keyword typescriptGlobal containedin=typescriptIdentifierName StopIteration
  syntax keyword typescriptGlobal containedin=typescriptIdentifierName SyntaxError TypeError
  syntax keyword typescriptGlobal containedin=typescriptIdentifierName URIError Date
  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Float32Array
  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Float64Array
  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Int16Array Int32Array
  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Int8Array Uint16Array
  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Uint32Array Uint8Array
  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Uint8ClampedArray
  syntax keyword typescriptGlobal containedin=typescriptIdentifierName ParallelArray
  syntax keyword typescriptGlobal containedin=typescriptIdentifierName ArrayBuffer DataView
  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Iterator Generator
  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Reflect Proxy
  syntax keyword typescriptGlobal containedin=typescriptIdentifierName arguments
  hi def link typescriptGlobal Structure
  syntax keyword typescriptGlobalMethod containedin=typescriptIdentifierName eval uneval nextgroup=typescriptFuncCallArg
  syntax keyword typescriptGlobalMethod containedin=typescriptIdentifierName isFinite nextgroup=typescriptFuncCallArg
  syntax keyword typescriptGlobalMethod containedin=typescriptIdentifierName isNaN parseFloat nextgroup=typescriptFuncCallArg
  syntax keyword typescriptGlobalMethod containedin=typescriptIdentifierName parseInt nextgroup=typescriptFuncCallArg
  syntax keyword typescriptGlobalMethod containedin=typescriptIdentifierName decodeURI nextgroup=typescriptFuncCallArg
  syntax keyword typescriptGlobalMethod containedin=typescriptIdentifierName decodeURIComponent nextgroup=typescriptFuncCallArg
  syntax keyword typescriptGlobalMethod containedin=typescriptIdentifierName encodeURI nextgroup=typescriptFuncCallArg
  syntax keyword typescriptGlobalMethod containedin=typescriptIdentifierName encodeURIComponent nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptGlobalMethod
  hi def link typescriptGlobalMethod Structure

  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Number nextgroup=typescriptGlobalNumberDot,typescriptFuncCallArg
  syntax match   typescriptGlobalNumberDot /\./ contained nextgroup=typescriptNumberStaticProp,typescriptNumberStaticMethod,typescriptProp
  syntax keyword typescriptNumberStaticProp contained EPSILON MAX_SAFE_INTEGER MAX_VALUE
  syntax keyword typescriptNumberStaticProp contained MIN_SAFE_INTEGER MIN_VALUE NEGATIVE_INFINITY
  syntax keyword typescriptNumberStaticProp contained NaN POSITIVE_INFINITY
  hi def link typescriptNumberStaticProp Keyword
  syntax keyword typescriptNumberStaticMethod contained isFinite isInteger isNaN isSafeInteger nextgroup=typescriptFuncCallArg
  syntax keyword typescriptNumberStaticMethod contained parseFloat parseInt nextgroup=typescriptFuncCallArg
  hi def link typescriptNumberStaticMethod Keyword
  syntax keyword typescriptNumberMethod contained toExponential toFixed toLocaleString nextgroup=typescriptFuncCallArg
  syntax keyword typescriptNumberMethod contained toPrecision toSource toString valueOf nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptNumberMethod
  hi def link typescriptNumberMethod Keyword

  syntax keyword typescriptGlobal containedin=typescriptIdentifierName String nextgroup=typescriptGlobalStringDot,typescriptFuncCallArg
  syntax match   typescriptGlobalStringDot /\./ contained nextgroup=typescriptStringStaticMethod,typescriptProp
  syntax keyword typescriptStringStaticMethod contained fromCharCode fromCodePoint raw nextgroup=typescriptFuncCallArg
  hi def link typescriptStringStaticMethod Keyword
  syntax keyword typescriptStringMethod contained anchor charAt charCodeAt codePointAt nextgroup=typescriptFuncCallArg
  syntax keyword typescriptStringMethod contained concat endsWith includes indexOf lastIndexOf nextgroup=typescriptFuncCallArg
  syntax keyword typescriptStringMethod contained link localeCompare match normalize nextgroup=typescriptFuncCallArg
  syntax keyword typescriptStringMethod contained padStart padEnd repeat replace search nextgroup=typescriptFuncCallArg
  syntax keyword typescriptStringMethod contained slice split startsWith substr substring nextgroup=typescriptFuncCallArg
  syntax keyword typescriptStringMethod contained toLocaleLowerCase toLocaleUpperCase nextgroup=typescriptFuncCallArg
  syntax keyword typescriptStringMethod contained toLowerCase toString toUpperCase trim nextgroup=typescriptFuncCallArg
  syntax keyword typescriptStringMethod contained valueOf nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptStringMethod
  hi def link typescriptStringMethod Keyword

  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Array nextgroup=typescriptGlobalArrayDot,typescriptFuncCallArg
  syntax match   typescriptGlobalArrayDot /\./ contained nextgroup=typescriptArrayStaticMethod,typescriptProp
  syntax keyword typescriptArrayStaticMethod contained from isArray of nextgroup=typescriptFuncCallArg
  hi def link typescriptArrayStaticMethod Keyword
  syntax keyword typescriptArrayMethod contained concat copyWithin entries every fill nextgroup=typescriptFuncCallArg
  syntax keyword typescriptArrayMethod contained filter find findIndex forEach indexOf nextgroup=typescriptFuncCallArg
  syntax keyword typescriptArrayMethod contained includes join keys lastIndexOf map nextgroup=typescriptFuncCallArg
  syntax keyword typescriptArrayMethod contained pop push reduce reduceRight reverse nextgroup=typescriptFuncCallArg
  syntax keyword typescriptArrayMethod contained shift slice some sort splice toLocaleString nextgroup=typescriptFuncCallArg
  syntax keyword typescriptArrayMethod contained toSource toString unshift nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptArrayMethod
  hi def link typescriptArrayMethod Keyword

  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Object nextgroup=typescriptGlobalObjectDot,typescriptFuncCallArg
  syntax match   typescriptGlobalObjectDot /\./ contained nextgroup=typescriptObjectStaticMethod,typescriptProp
  syntax keyword typescriptObjectStaticMethod contained create defineProperties defineProperty nextgroup=typescriptFuncCallArg
  syntax keyword typescriptObjectStaticMethod contained entries freeze getOwnPropertyDescriptors nextgroup=typescriptFuncCallArg
  syntax keyword typescriptObjectStaticMethod contained getOwnPropertyDescriptor getOwnPropertyNames nextgroup=typescriptFuncCallArg
  syntax keyword typescriptObjectStaticMethod contained getOwnPropertySymbols getPrototypeOf nextgroup=typescriptFuncCallArg
  syntax keyword typescriptObjectStaticMethod contained is isExtensible isFrozen isSealed nextgroup=typescriptFuncCallArg
  syntax keyword typescriptObjectStaticMethod contained keys preventExtensions values nextgroup=typescriptFuncCallArg
  hi def link typescriptObjectStaticMethod Keyword
  syntax keyword typescriptObjectMethod contained getOwnPropertyDescriptors hasOwnProperty nextgroup=typescriptFuncCallArg
  syntax keyword typescriptObjectMethod contained isPrototypeOf propertyIsEnumerable nextgroup=typescriptFuncCallArg
  syntax keyword typescriptObjectMethod contained toLocaleString toString valueOf seal nextgroup=typescriptFuncCallArg
  syntax keyword typescriptObjectMethod contained setPrototypeOf nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptObjectMethod
  hi def link typescriptObjectMethod Keyword

  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Symbol nextgroup=typescriptGlobalSymbolDot,typescriptFuncCallArg
  syntax match   typescriptGlobalSymbolDot /\./ contained nextgroup=typescriptSymbolStaticProp,typescriptSymbolStaticMethod,typescriptProp
  syntax keyword typescriptSymbolStaticProp contained length iterator match replace
  syntax keyword typescriptSymbolStaticProp contained search split hasInstance isConcatSpreadable
  syntax keyword typescriptSymbolStaticProp contained unscopables species toPrimitive
  syntax keyword typescriptSymbolStaticProp contained toStringTag
  hi def link typescriptSymbolStaticProp Keyword
  syntax keyword typescriptSymbolStaticMethod contained for keyFor nextgroup=typescriptFuncCallArg
  hi def link typescriptSymbolStaticMethod Keyword

  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Function
  syntax keyword typescriptFunctionMethod contained apply bind call nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptFunctionMethod
  hi def link typescriptFunctionMethod Keyword

  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Math nextgroup=typescriptGlobalMathDot,typescriptFuncCallArg
  syntax match   typescriptGlobalMathDot /\./ contained nextgroup=typescriptMathStaticProp,typescriptMathStaticMethod,typescriptProp
  syntax keyword typescriptMathStaticProp contained E LN10 LN2 LOG10E LOG2E PI SQRT1_2
  syntax keyword typescriptMathStaticProp contained SQRT2
  hi def link typescriptMathStaticProp Keyword
  syntax keyword typescriptMathStaticMethod contained abs acos acosh asin asinh atan nextgroup=typescriptFuncCallArg
  syntax keyword typescriptMathStaticMethod contained atan2 atanh cbrt ceil clz32 cos nextgroup=typescriptFuncCallArg
  syntax keyword typescriptMathStaticMethod contained cosh exp expm1 floor fround hypot nextgroup=typescriptFuncCallArg
  syntax keyword typescriptMathStaticMethod contained imul log log10 log1p log2 max nextgroup=typescriptFuncCallArg
  syntax keyword typescriptMathStaticMethod contained min pow random round sign sin nextgroup=typescriptFuncCallArg
  syntax keyword typescriptMathStaticMethod contained sinh sqrt tan tanh trunc nextgroup=typescriptFuncCallArg
  hi def link typescriptMathStaticMethod Keyword

  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Date nextgroup=typescriptGlobalDateDot,typescriptFuncCallArg
  syntax match   typescriptGlobalDateDot /\./ contained nextgroup=typescriptDateStaticMethod,typescriptProp
  syntax keyword typescriptDateStaticMethod contained UTC now parse nextgroup=typescriptFuncCallArg
  hi def link typescriptDateStaticMethod Keyword
  syntax keyword typescriptDateMethod contained getDate getDay getFullYear getHours nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDateMethod contained getMilliseconds getMinutes getMonth nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDateMethod contained getSeconds getTime getTimezoneOffset nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDateMethod contained getUTCDate getUTCDay getUTCFullYear nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDateMethod contained getUTCHours getUTCMilliseconds getUTCMinutes nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDateMethod contained getUTCMonth getUTCSeconds setDate setFullYear nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDateMethod contained setHours setMilliseconds setMinutes nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDateMethod contained setMonth setSeconds setTime setUTCDate nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDateMethod contained setUTCFullYear setUTCHours setUTCMilliseconds nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDateMethod contained setUTCMinutes setUTCMonth setUTCSeconds nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDateMethod contained toDateString toISOString toJSON toLocaleDateString nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDateMethod contained toLocaleFormat toLocaleString toLocaleTimeString nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDateMethod contained toSource toString toTimeString toUTCString nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDateMethod contained valueOf nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptDateMethod
  hi def link typescriptDateMethod Keyword

  syntax keyword typescriptGlobal containedin=typescriptIdentifierName JSON nextgroup=typescriptGlobalJSONDot,typescriptFuncCallArg
  syntax match   typescriptGlobalJSONDot /\./ contained nextgroup=typescriptJSONStaticMethod,typescriptProp
  syntax keyword typescriptJSONStaticMethod contained parse stringify nextgroup=typescriptFuncCallArg
  hi def link typescriptJSONStaticMethod Keyword

  syntax keyword typescriptGlobal containedin=typescriptIdentifierName RegExp nextgroup=typescriptGlobalRegExpDot,typescriptFuncCallArg
  syntax match   typescriptGlobalRegExpDot /\./ contained nextgroup=typescriptRegExpStaticProp,typescriptProp
  syntax keyword typescriptRegExpStaticProp contained lastIndex
  hi def link typescriptRegExpStaticProp Keyword
  syntax keyword typescriptRegExpProp contained global ignoreCase multiline source sticky
  syntax cluster props add=typescriptRegExpProp
  hi def link typescriptRegExpProp Keyword
  syntax keyword typescriptRegExpMethod contained exec test nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptRegExpMethod
  hi def link typescriptRegExpMethod Keyword

  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Map WeakMap
  syntax keyword typescriptES6MapProp contained size
  syntax cluster props add=typescriptES6MapProp
  hi def link typescriptES6MapProp Keyword
  syntax keyword typescriptES6MapMethod contained clear delete entries forEach get has nextgroup=typescriptFuncCallArg
  syntax keyword typescriptES6MapMethod contained keys set values nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptES6MapMethod
  hi def link typescriptES6MapMethod Keyword

  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Set WeakSet
  syntax keyword typescriptES6SetProp contained size
  syntax cluster props add=typescriptES6SetProp
  hi def link typescriptES6SetProp Keyword
  syntax keyword typescriptES6SetMethod contained add clear delete entries forEach has nextgroup=typescriptFuncCallArg
  syntax keyword typescriptES6SetMethod contained values nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptES6SetMethod
  hi def link typescriptES6SetMethod Keyword

  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Proxy
  syntax keyword typescriptProxyAPI contained getOwnPropertyDescriptor getOwnPropertyNames
  syntax keyword typescriptProxyAPI contained defineProperty deleteProperty freeze seal
  syntax keyword typescriptProxyAPI contained preventExtensions has hasOwn get set enumerate
  syntax keyword typescriptProxyAPI contained iterate ownKeys apply construct
  hi def link typescriptProxyAPI Keyword

  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Promise nextgroup=typescriptGlobalPromiseDot,typescriptFuncCallArg
  syntax match   typescriptGlobalPromiseDot /\./ contained nextgroup=typescriptPromiseStaticMethod,typescriptProp
  syntax keyword typescriptPromiseStaticMethod contained resolve reject all race nextgroup=typescriptFuncCallArg
  hi def link typescriptPromiseStaticMethod Keyword
  syntax keyword typescriptPromiseMethod contained then catch finally nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptPromiseMethod
  hi def link typescriptPromiseMethod Keyword

  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Reflect
  syntax keyword typescriptReflectMethod contained apply construct defineProperty deleteProperty nextgroup=typescriptFuncCallArg
  syntax keyword typescriptReflectMethod contained enumerate get getOwnPropertyDescriptor nextgroup=typescriptFuncCallArg
  syntax keyword typescriptReflectMethod contained getPrototypeOf has isExtensible ownKeys nextgroup=typescriptFuncCallArg
  syntax keyword typescriptReflectMethod contained preventExtensions set setPrototypeOf nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptReflectMethod
  hi def link typescriptReflectMethod Keyword

  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Intl
  syntax keyword typescriptIntlMethod contained Collator DateTimeFormat NumberFormat nextgroup=typescriptFuncCallArg
  syntax keyword typescriptIntlMethod contained PluralRules nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptIntlMethod
  hi def link typescriptIntlMethod Keyword

  syntax keyword typescriptNodeGlobal containedin=typescriptIdentifierName global process
  syntax keyword typescriptNodeGlobal containedin=typescriptIdentifierName console Buffer
  syntax keyword typescriptNodeGlobal containedin=typescriptIdentifierName module exports
  syntax keyword typescriptNodeGlobal containedin=typescriptIdentifierName setTimeout
  syntax keyword typescriptNodeGlobal containedin=typescriptIdentifierName clearTimeout
  syntax keyword typescriptNodeGlobal containedin=typescriptIdentifierName setInterval
  syntax keyword typescriptNodeGlobal containedin=typescriptIdentifierName clearInterval
  hi def link typescriptNodeGlobal Structure

  syntax keyword typescriptTestGlobal containedin=typescriptIdentifierName describe
  syntax keyword typescriptTestGlobal containedin=typescriptIdentifierName it test before
  syntax keyword typescriptTestGlobal containedin=typescriptIdentifierName after beforeEach
  syntax keyword typescriptTestGlobal containedin=typescriptIdentifierName afterEach
  syntax keyword typescriptTestGlobal containedin=typescriptIdentifierName beforeAll
  syntax keyword typescriptTestGlobal containedin=typescriptIdentifierName afterAll
  syntax keyword typescriptTestGlobal containedin=typescriptIdentifierName expect assert

  syntax keyword typescriptBOM containedin=typescriptIdentifierName AbortController
  syntax keyword typescriptBOM containedin=typescriptIdentifierName AbstractWorker AnalyserNode
  syntax keyword typescriptBOM containedin=typescriptIdentifierName App Apps ArrayBuffer
  syntax keyword typescriptBOM containedin=typescriptIdentifierName ArrayBufferView
  syntax keyword typescriptBOM containedin=typescriptIdentifierName Attr AudioBuffer
  syntax keyword typescriptBOM containedin=typescriptIdentifierName AudioBufferSourceNode
  syntax keyword typescriptBOM containedin=typescriptIdentifierName AudioContext AudioDestinationNode
  syntax keyword typescriptBOM containedin=typescriptIdentifierName AudioListener AudioNode
  syntax keyword typescriptBOM containedin=typescriptIdentifierName AudioParam BatteryManager
  syntax keyword typescriptBOM containedin=typescriptIdentifierName BiquadFilterNode
  syntax keyword typescriptBOM containedin=typescriptIdentifierName BlobEvent BluetoothAdapter
  syntax keyword typescriptBOM containedin=typescriptIdentifierName BluetoothDevice
  syntax keyword typescriptBOM containedin=typescriptIdentifierName BluetoothManager
  syntax keyword typescriptBOM containedin=typescriptIdentifierName CameraCapabilities
  syntax keyword typescriptBOM containedin=typescriptIdentifierName CameraControl CameraManager
  syntax keyword typescriptBOM containedin=typescriptIdentifierName CanvasGradient CanvasImageSource
  syntax keyword typescriptBOM containedin=typescriptIdentifierName CanvasPattern CanvasRenderingContext2D
  syntax keyword typescriptBOM containedin=typescriptIdentifierName CaretPosition CDATASection
  syntax keyword typescriptBOM containedin=typescriptIdentifierName ChannelMergerNode
  syntax keyword typescriptBOM containedin=typescriptIdentifierName ChannelSplitterNode
  syntax keyword typescriptBOM containedin=typescriptIdentifierName CharacterData ChildNode
  syntax keyword typescriptBOM containedin=typescriptIdentifierName ChromeWorker Comment
  syntax keyword typescriptBOM containedin=typescriptIdentifierName Connection Console
  syntax keyword typescriptBOM containedin=typescriptIdentifierName ContactManager Contacts
  syntax keyword typescriptBOM containedin=typescriptIdentifierName ConvolverNode Coordinates
  syntax keyword typescriptBOM containedin=typescriptIdentifierName CSS CSSConditionRule
  syntax keyword typescriptBOM containedin=typescriptIdentifierName CSSGroupingRule
  syntax keyword typescriptBOM containedin=typescriptIdentifierName CSSKeyframeRule
  syntax keyword typescriptBOM containedin=typescriptIdentifierName CSSKeyframesRule
  syntax keyword typescriptBOM containedin=typescriptIdentifierName CSSMediaRule CSSNamespaceRule
  syntax keyword typescriptBOM containedin=typescriptIdentifierName CSSPageRule CSSRule
  syntax keyword typescriptBOM containedin=typescriptIdentifierName CSSRuleList CSSStyleDeclaration
  syntax keyword typescriptBOM containedin=typescriptIdentifierName CSSStyleRule CSSStyleSheet
  syntax keyword typescriptBOM containedin=typescriptIdentifierName CSSSupportsRule
  syntax keyword typescriptBOM containedin=typescriptIdentifierName DataTransfer DataView
  syntax keyword typescriptBOM containedin=typescriptIdentifierName DedicatedWorkerGlobalScope
  syntax keyword typescriptBOM containedin=typescriptIdentifierName DelayNode DeviceAcceleration
  syntax keyword typescriptBOM containedin=typescriptIdentifierName DeviceRotationRate
  syntax keyword typescriptBOM containedin=typescriptIdentifierName DeviceStorage DirectoryEntry
  syntax keyword typescriptBOM containedin=typescriptIdentifierName DirectoryEntrySync
  syntax keyword typescriptBOM containedin=typescriptIdentifierName DirectoryReader
  syntax keyword typescriptBOM containedin=typescriptIdentifierName DirectoryReaderSync
  syntax keyword typescriptBOM containedin=typescriptIdentifierName Document DocumentFragment
  syntax keyword typescriptBOM containedin=typescriptIdentifierName DocumentTouch DocumentType
  syntax keyword typescriptBOM containedin=typescriptIdentifierName DOMCursor DOMError
  syntax keyword typescriptBOM containedin=typescriptIdentifierName DOMException DOMHighResTimeStamp
  syntax keyword typescriptBOM containedin=typescriptIdentifierName DOMImplementation
  syntax keyword typescriptBOM containedin=typescriptIdentifierName DOMImplementationRegistry
  syntax keyword typescriptBOM containedin=typescriptIdentifierName DOMParser DOMRequest
  syntax keyword typescriptBOM containedin=typescriptIdentifierName DOMString DOMStringList
  syntax keyword typescriptBOM containedin=typescriptIdentifierName DOMStringMap DOMTimeStamp
  syntax keyword typescriptBOM containedin=typescriptIdentifierName DOMTokenList DynamicsCompressorNode
  syntax keyword typescriptBOM containedin=typescriptIdentifierName Element Entry EntrySync
  syntax keyword typescriptBOM containedin=typescriptIdentifierName Extensions FileException
  syntax keyword typescriptBOM containedin=typescriptIdentifierName Float32Array Float64Array
  syntax keyword typescriptBOM containedin=typescriptIdentifierName FMRadio FormData
  syntax keyword typescriptBOM containedin=typescriptIdentifierName GainNode Gamepad
  syntax keyword typescriptBOM containedin=typescriptIdentifierName GamepadButton Geolocation
  syntax keyword typescriptBOM containedin=typescriptIdentifierName History HTMLAnchorElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLAreaElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLAudioElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLBaseElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLBodyElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLBRElement HTMLButtonElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLCanvasElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLCollection HTMLDataElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLDataListElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLDivElement HTMLDListElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLDocument HTMLElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLEmbedElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLFieldSetElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLFormControlsCollection
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLFormElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLHeadElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLHeadingElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLHRElement HTMLHtmlElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLIFrameElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLImageElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLInputElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLKeygenElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLLabelElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLLegendElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLLIElement HTMLLinkElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLMapElement HTMLMediaElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLMetaElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLMeterElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLModElement HTMLObjectElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLOListElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLOptGroupElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLOptionElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLOptionsCollection
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLOutputElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLParagraphElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLParamElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLPreElement HTMLProgressElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLQuoteElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLScriptElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLSelectElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLSourceElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLSpanElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLStyleElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLTableCaptionElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLTableCellElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLTableColElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLTableDataCellElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLTableElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLTableHeaderCellElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLTableRowElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLTableSectionElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLTextAreaElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLTimeElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLTitleElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLTrackElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLUListElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLUnknownElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName HTMLVideoElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName IDBCursor IDBCursorSync
  syntax keyword typescriptBOM containedin=typescriptIdentifierName IDBCursorWithValue
  syntax keyword typescriptBOM containedin=typescriptIdentifierName IDBDatabase IDBDatabaseSync
  syntax keyword typescriptBOM containedin=typescriptIdentifierName IDBEnvironment IDBEnvironmentSync
  syntax keyword typescriptBOM containedin=typescriptIdentifierName IDBFactory IDBFactorySync
  syntax keyword typescriptBOM containedin=typescriptIdentifierName IDBIndex IDBIndexSync
  syntax keyword typescriptBOM containedin=typescriptIdentifierName IDBKeyRange IDBObjectStore
  syntax keyword typescriptBOM containedin=typescriptIdentifierName IDBObjectStoreSync
  syntax keyword typescriptBOM containedin=typescriptIdentifierName IDBOpenDBRequest
  syntax keyword typescriptBOM containedin=typescriptIdentifierName IDBRequest IDBTransaction
  syntax keyword typescriptBOM containedin=typescriptIdentifierName IDBTransactionSync
  syntax keyword typescriptBOM containedin=typescriptIdentifierName IDBVersionChangeEvent
  syntax keyword typescriptBOM containedin=typescriptIdentifierName ImageData IndexedDB
  syntax keyword typescriptBOM containedin=typescriptIdentifierName Int16Array Int32Array
  syntax keyword typescriptBOM containedin=typescriptIdentifierName Int8Array L10n LinkStyle
  syntax keyword typescriptBOM containedin=typescriptIdentifierName LocalFileSystem
  syntax keyword typescriptBOM containedin=typescriptIdentifierName LocalFileSystemSync
  syntax keyword typescriptBOM containedin=typescriptIdentifierName Location LockedFile
  syntax keyword typescriptBOM containedin=typescriptIdentifierName MediaQueryList MediaQueryListListener
  syntax keyword typescriptBOM containedin=typescriptIdentifierName MediaRecorder MediaSource
  syntax keyword typescriptBOM containedin=typescriptIdentifierName MediaStream MediaStreamTrack
  syntax keyword typescriptBOM containedin=typescriptIdentifierName MutationObserver
  syntax keyword typescriptBOM containedin=typescriptIdentifierName Navigator NavigatorGeolocation
  syntax keyword typescriptBOM containedin=typescriptIdentifierName NavigatorID NavigatorLanguage
  syntax keyword typescriptBOM containedin=typescriptIdentifierName NavigatorOnLine
  syntax keyword typescriptBOM containedin=typescriptIdentifierName NavigatorPlugins
  syntax keyword typescriptBOM containedin=typescriptIdentifierName Node NodeFilter
  syntax keyword typescriptBOM containedin=typescriptIdentifierName NodeIterator NodeList
  syntax keyword typescriptBOM containedin=typescriptIdentifierName Notification OfflineAudioContext
  syntax keyword typescriptBOM containedin=typescriptIdentifierName OscillatorNode PannerNode
  syntax keyword typescriptBOM containedin=typescriptIdentifierName ParentNode Performance
  syntax keyword typescriptBOM containedin=typescriptIdentifierName PerformanceNavigation
  syntax keyword typescriptBOM containedin=typescriptIdentifierName PerformanceTiming
  syntax keyword typescriptBOM containedin=typescriptIdentifierName Permissions PermissionSettings
  syntax keyword typescriptBOM containedin=typescriptIdentifierName Plugin PluginArray
  syntax keyword typescriptBOM containedin=typescriptIdentifierName Position PositionError
  syntax keyword typescriptBOM containedin=typescriptIdentifierName PositionOptions
  syntax keyword typescriptBOM containedin=typescriptIdentifierName PowerManager ProcessingInstruction
  syntax keyword typescriptBOM containedin=typescriptIdentifierName PromiseResolver
  syntax keyword typescriptBOM containedin=typescriptIdentifierName PushManager Range
  syntax keyword typescriptBOM containedin=typescriptIdentifierName RTCConfiguration
  syntax keyword typescriptBOM containedin=typescriptIdentifierName RTCPeerConnection
  syntax keyword typescriptBOM containedin=typescriptIdentifierName RTCPeerConnectionErrorCallback
  syntax keyword typescriptBOM containedin=typescriptIdentifierName RTCSessionDescription
  syntax keyword typescriptBOM containedin=typescriptIdentifierName RTCSessionDescriptionCallback
  syntax keyword typescriptBOM containedin=typescriptIdentifierName ScriptProcessorNode
  syntax keyword typescriptBOM containedin=typescriptIdentifierName Selection SettingsLock
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SettingsManager
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SharedWorker StyleSheet
  syntax keyword typescriptBOM containedin=typescriptIdentifierName StyleSheetList SVGAElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGAngle SVGAnimateColorElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGAnimatedAngle
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGAnimatedBoolean
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGAnimatedEnumeration
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGAnimatedInteger
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGAnimatedLength
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGAnimatedLengthList
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGAnimatedNumber
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGAnimatedNumberList
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGAnimatedPoints
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGAnimatedPreserveAspectRatio
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGAnimatedRect
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGAnimatedString
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGAnimatedTransformList
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGAnimateElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGAnimateMotionElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGAnimateTransformElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGAnimationElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGCircleElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGClipPathElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGCursorElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGDefsElement SVGDescElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGElement SVGEllipseElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGFilterElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGFontElement SVGFontFaceElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGFontFaceFormatElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGFontFaceNameElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGFontFaceSrcElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGFontFaceUriElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGForeignObjectElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGGElement SVGGlyphElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGGradientElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGHKernElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGImageElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGLength SVGLengthList
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGLinearGradientElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGLineElement SVGMaskElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGMatrix SVGMissingGlyphElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGMPathElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGNumber SVGNumberList
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGPathElement SVGPatternElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGPoint SVGPolygonElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGPolylineElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGPreserveAspectRatio
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGRadialGradientElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGRect SVGRectElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGScriptElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGSetElement SVGStopElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGStringList SVGStylable
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGStyleElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGSVGElement SVGSwitchElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGSymbolElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGTests SVGTextElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGTextPositioningElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGTitleElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGTransform SVGTransformable
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGTransformList
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGTRefElement SVGTSpanElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGUseElement SVGViewElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName SVGVKernElement
  syntax keyword typescriptBOM containedin=typescriptIdentifierName TCPServerSocket
  syntax keyword typescriptBOM containedin=typescriptIdentifierName TCPSocket Telephony
  syntax keyword typescriptBOM containedin=typescriptIdentifierName TelephonyCall Text
  syntax keyword typescriptBOM containedin=typescriptIdentifierName TextDecoder TextEncoder
  syntax keyword typescriptBOM containedin=typescriptIdentifierName TextMetrics TimeRanges
  syntax keyword typescriptBOM containedin=typescriptIdentifierName Touch TouchList
  syntax keyword typescriptBOM containedin=typescriptIdentifierName Transferable TreeWalker
  syntax keyword typescriptBOM containedin=typescriptIdentifierName Uint16Array Uint32Array
  syntax keyword typescriptBOM containedin=typescriptIdentifierName Uint8Array Uint8ClampedArray
  syntax keyword typescriptBOM containedin=typescriptIdentifierName URLSearchParams
  syntax keyword typescriptBOM containedin=typescriptIdentifierName URLUtilsReadOnly
  syntax keyword typescriptBOM containedin=typescriptIdentifierName UserProximityEvent
  syntax keyword typescriptBOM containedin=typescriptIdentifierName ValidityState VideoPlaybackQuality
  syntax keyword typescriptBOM containedin=typescriptIdentifierName WaveShaperNode WebBluetooth
  syntax keyword typescriptBOM containedin=typescriptIdentifierName WebGLRenderingContext
  syntax keyword typescriptBOM containedin=typescriptIdentifierName WebSMS WebSocket
  syntax keyword typescriptBOM containedin=typescriptIdentifierName WebVTT WifiManager
  syntax keyword typescriptBOM containedin=typescriptIdentifierName Window Worker WorkerConsole
  syntax keyword typescriptBOM containedin=typescriptIdentifierName WorkerLocation WorkerNavigator
  syntax keyword typescriptBOM containedin=typescriptIdentifierName XDomainRequest XMLDocument
  syntax keyword typescriptBOM containedin=typescriptIdentifierName XMLHttpRequestEventTarget
  hi def link typescriptBOM Structure

  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName applicationCache
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName closed
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName Components
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName controllers
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName dialogArguments
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName document
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName frameElement
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName frames
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName fullScreen
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName history
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName innerHeight
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName innerWidth
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName length
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName location
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName locationbar
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName menubar
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName messageManager
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName name navigator
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName opener
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName outerHeight
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName outerWidth
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName pageXOffset
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName pageYOffset
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName parent
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName performance
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName personalbar
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName returnValue
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName screen
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName screenX
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName screenY
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName scrollbars
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName scrollMaxX
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName scrollMaxY
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName scrollX
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName scrollY
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName self sidebar
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName status
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName statusbar
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName toolbar
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName top visualViewport
  syntax keyword typescriptBOMWindowProp containedin=typescriptIdentifierName window
  syntax cluster props add=typescriptBOMWindowProp
  hi def link typescriptBOMWindowProp Structure
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName alert nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName atob nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName blur nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName btoa nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName clearImmediate nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName clearInterval nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName clearTimeout nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName close nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName confirm nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName dispatchEvent nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName find nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName focus nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName getAttention nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName getAttentionWithCycleCount nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName getComputedStyle nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName getDefaulComputedStyle nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName getSelection nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName matchMedia nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName maximize nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName moveBy nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName moveTo nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName open nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName openDialog nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName postMessage nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName print nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName prompt nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName removeEventListener nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName resizeBy nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName resizeTo nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName restore nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName scroll nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName scrollBy nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName scrollByLines nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName scrollByPages nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName scrollTo nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName setCursor nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName setImmediate nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName setInterval nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName setResizable nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName setTimeout nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName showModalDialog nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName sizeToContent nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName stop nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMWindowMethod containedin=typescriptIdentifierName updateCommands nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptBOMWindowMethod
  hi def link typescriptBOMWindowMethod Structure
  syntax keyword typescriptBOMWindowEvent contained onabort onbeforeunload onblur onchange
  syntax keyword typescriptBOMWindowEvent contained onclick onclose oncontextmenu ondevicelight
  syntax keyword typescriptBOMWindowEvent contained ondevicemotion ondeviceorientation
  syntax keyword typescriptBOMWindowEvent contained ondeviceproximity ondragdrop onerror
  syntax keyword typescriptBOMWindowEvent contained onfocus onhashchange onkeydown onkeypress
  syntax keyword typescriptBOMWindowEvent contained onkeyup onload onmousedown onmousemove
  syntax keyword typescriptBOMWindowEvent contained onmouseout onmouseover onmouseup
  syntax keyword typescriptBOMWindowEvent contained onmozbeforepaint onpaint onpopstate
  syntax keyword typescriptBOMWindowEvent contained onreset onresize onscroll onselect
  syntax keyword typescriptBOMWindowEvent contained onsubmit onunload onuserproximity
  syntax keyword typescriptBOMWindowEvent contained onpageshow onpagehide
  hi def link typescriptBOMWindowEvent Keyword
  syntax keyword typescriptBOMWindowCons containedin=typescriptIdentifierName DOMParser
  syntax keyword typescriptBOMWindowCons containedin=typescriptIdentifierName QueryInterface
  syntax keyword typescriptBOMWindowCons containedin=typescriptIdentifierName XMLSerializer
  hi def link typescriptBOMWindowCons Structure

  syntax keyword typescriptBOMNavigatorProp contained battery buildID connection cookieEnabled
  syntax keyword typescriptBOMNavigatorProp contained doNotTrack maxTouchPoints oscpu
  syntax keyword typescriptBOMNavigatorProp contained productSub push serviceWorker
  syntax keyword typescriptBOMNavigatorProp contained vendor vendorSub
  syntax cluster props add=typescriptBOMNavigatorProp
  hi def link typescriptBOMNavigatorProp Keyword
  syntax keyword typescriptBOMNavigatorMethod contained addIdleObserver geolocation nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMNavigatorMethod contained getDeviceStorage getDeviceStorages nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMNavigatorMethod contained getGamepads getUserMedia registerContentHandler nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMNavigatorMethod contained removeIdleObserver requestWakeLock nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMNavigatorMethod contained share vibrate watch registerProtocolHandler nextgroup=typescriptFuncCallArg
  syntax keyword typescriptBOMNavigatorMethod contained sendBeacon nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptBOMNavigatorMethod
  hi def link typescriptBOMNavigatorMethod Keyword
  syntax keyword typescriptServiceWorkerMethod contained register nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptServiceWorkerMethod
  hi def link typescriptServiceWorkerMethod Keyword

  syntax keyword typescriptBOMLocationProp contained href protocol host hostname port
  syntax keyword typescriptBOMLocationProp contained pathname search hash username password
  syntax keyword typescriptBOMLocationProp contained origin
  syntax cluster props add=typescriptBOMLocationProp
  hi def link typescriptBOMLocationProp Keyword
  syntax keyword typescriptBOMLocationMethod contained assign reload replace toString nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptBOMLocationMethod
  hi def link typescriptBOMLocationMethod Keyword

  syntax keyword typescriptBOMHistoryProp contained length current next previous state
  syntax keyword typescriptBOMHistoryProp contained scrollRestoration
  syntax cluster props add=typescriptBOMHistoryProp
  hi def link typescriptBOMHistoryProp Keyword
  syntax keyword typescriptBOMHistoryMethod contained back forward go pushState replaceState nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptBOMHistoryMethod
  hi def link typescriptBOMHistoryMethod Keyword

  syntax keyword typescriptGlobal containedin=typescriptIdentifierName console
  syntax keyword typescriptConsoleMethod contained count dir error group groupCollapsed nextgroup=typescriptFuncCallArg
  syntax keyword typescriptConsoleMethod contained groupEnd info log time timeEnd trace nextgroup=typescriptFuncCallArg
  syntax keyword typescriptConsoleMethod contained warn nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptConsoleMethod
  hi def link typescriptConsoleMethod Keyword

  syntax keyword typescriptXHRGlobal containedin=typescriptIdentifierName XMLHttpRequest
  hi def link typescriptXHRGlobal Structure
  syntax keyword typescriptXHRProp contained onreadystatechange readyState response
  syntax keyword typescriptXHRProp contained responseText responseType responseXML status
  syntax keyword typescriptXHRProp contained statusText timeout ontimeout upload withCredentials
  syntax cluster props add=typescriptXHRProp
  hi def link typescriptXHRProp Keyword
  syntax keyword typescriptXHRMethod contained abort getAllResponseHeaders getResponseHeader nextgroup=typescriptFuncCallArg
  syntax keyword typescriptXHRMethod contained open overrideMimeType send setRequestHeader nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptXHRMethod
  hi def link typescriptXHRMethod Keyword

  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Blob BlobBuilder
  syntax keyword typescriptGlobal containedin=typescriptIdentifierName File FileReader
  syntax keyword typescriptGlobal containedin=typescriptIdentifierName FileReaderSync
  syntax keyword typescriptGlobal containedin=typescriptIdentifierName URL nextgroup=typescriptGlobalURLDot,typescriptFuncCallArg
  syntax match   typescriptGlobalURLDot /\./ contained nextgroup=typescriptURLStaticMethod,typescriptProp
  syntax keyword typescriptGlobal containedin=typescriptIdentifierName URLUtils
  syntax keyword typescriptFileMethod contained readAsArrayBuffer readAsBinaryString nextgroup=typescriptFuncCallArg
  syntax keyword typescriptFileMethod contained readAsDataURL readAsText nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptFileMethod
  hi def link typescriptFileMethod Keyword
  syntax keyword typescriptFileReaderProp contained error readyState result
  syntax cluster props add=typescriptFileReaderProp
  hi def link typescriptFileReaderProp Keyword
  syntax keyword typescriptFileReaderMethod contained abort readAsArrayBuffer readAsBinaryString nextgroup=typescriptFuncCallArg
  syntax keyword typescriptFileReaderMethod contained readAsDataURL readAsText nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptFileReaderMethod
  hi def link typescriptFileReaderMethod Keyword
  syntax keyword typescriptFileListMethod contained item nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptFileListMethod
  hi def link typescriptFileListMethod Keyword
  syntax keyword typescriptBlobMethod contained append getBlob getFile nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptBlobMethod
  hi def link typescriptBlobMethod Keyword
  syntax keyword typescriptURLUtilsProp contained hash host hostname href origin password
  syntax keyword typescriptURLUtilsProp contained pathname port protocol search searchParams
  syntax keyword typescriptURLUtilsProp contained username
  syntax cluster props add=typescriptURLUtilsProp
  hi def link typescriptURLUtilsProp Keyword
  syntax keyword typescriptURLStaticMethod contained createObjectURL revokeObjectURL nextgroup=typescriptFuncCallArg
  hi def link typescriptURLStaticMethod Keyword

  syntax keyword typescriptCryptoGlobal containedin=typescriptIdentifierName crypto
  hi def link typescriptCryptoGlobal Structure
  syntax keyword typescriptSubtleCryptoMethod contained encrypt decrypt sign verify nextgroup=typescriptFuncCallArg
  syntax keyword typescriptSubtleCryptoMethod contained digest nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptSubtleCryptoMethod
  hi def link typescriptSubtleCryptoMethod Keyword
  syntax keyword typescriptCryptoProp contained subtle
  syntax cluster props add=typescriptCryptoProp
  hi def link typescriptCryptoProp Keyword
  syntax keyword typescriptCryptoMethod contained getRandomValues nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptCryptoMethod
  hi def link typescriptCryptoMethod Keyword

  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Headers Request
  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Response
  syntax keyword typescriptGlobalMethod containedin=typescriptIdentifierName fetch nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptGlobalMethod
  hi def link typescriptGlobalMethod Structure
  syntax keyword typescriptHeadersMethod contained append delete get getAll has set nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptHeadersMethod
  hi def link typescriptHeadersMethod Keyword
  syntax keyword typescriptRequestProp contained method url headers context referrer
  syntax keyword typescriptRequestProp contained mode credentials cache
  syntax cluster props add=typescriptRequestProp
  hi def link typescriptRequestProp Keyword
  syntax keyword typescriptRequestMethod contained clone nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptRequestMethod
  hi def link typescriptRequestMethod Keyword
  syntax keyword typescriptResponseProp contained type url status statusText headers
  syntax keyword typescriptResponseProp contained redirected
  syntax cluster props add=typescriptResponseProp
  hi def link typescriptResponseProp Keyword
  syntax keyword typescriptResponseMethod contained clone nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptResponseMethod
  hi def link typescriptResponseMethod Keyword

  syntax keyword typescriptServiceWorkerProp contained controller ready
  syntax cluster props add=typescriptServiceWorkerProp
  hi def link typescriptServiceWorkerProp Keyword
  syntax keyword typescriptServiceWorkerMethod contained register getRegistration nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptServiceWorkerMethod
  hi def link typescriptServiceWorkerMethod Keyword
  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Cache
  syntax keyword typescriptCacheMethod contained match matchAll add addAll put delete nextgroup=typescriptFuncCallArg
  syntax keyword typescriptCacheMethod contained keys nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptCacheMethod
  hi def link typescriptCacheMethod Keyword

  syntax keyword typescriptEncodingGlobal containedin=typescriptIdentifierName TextEncoder
  syntax keyword typescriptEncodingGlobal containedin=typescriptIdentifierName TextDecoder
  hi def link typescriptEncodingGlobal Structure
  syntax keyword typescriptEncodingProp contained encoding fatal ignoreBOM
  syntax cluster props add=typescriptEncodingProp
  hi def link typescriptEncodingProp Keyword
  syntax keyword typescriptEncodingMethod contained encode decode nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptEncodingMethod
  hi def link typescriptEncodingMethod Keyword

  syntax keyword typescriptGlobal containedin=typescriptIdentifierName Geolocation
  syntax keyword typescriptGeolocationMethod contained getCurrentPosition watchPosition nextgroup=typescriptFuncCallArg
  syntax keyword typescriptGeolocationMethod contained clearWatch nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptGeolocationMethod
  hi def link typescriptGeolocationMethod Keyword

  syntax keyword typescriptGlobal containedin=typescriptIdentifierName NetworkInformation
  syntax keyword typescriptBOMNetworkProp contained downlink downlinkMax effectiveType
  syntax keyword typescriptBOMNetworkProp contained rtt type
  syntax cluster props add=typescriptBOMNetworkProp
  hi def link typescriptBOMNetworkProp Keyword

  syntax keyword typescriptGlobal containedin=typescriptIdentifierName PaymentRequest
  syntax keyword typescriptPaymentMethod contained show abort canMakePayment nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptPaymentMethod
  hi def link typescriptPaymentMethod Keyword
  syntax keyword typescriptPaymentProp contained shippingAddress shippingOption result
  syntax cluster props add=typescriptPaymentProp
  hi def link typescriptPaymentProp Keyword
  syntax keyword typescriptPaymentEvent contained onshippingaddresschange onshippingoptionchange
  hi def link typescriptPaymentEvent Keyword
  syntax keyword typescriptPaymentResponseMethod contained complete nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptPaymentResponseMethod
  hi def link typescriptPaymentResponseMethod Keyword
  syntax keyword typescriptPaymentResponseProp contained details methodName payerEmail
  syntax keyword typescriptPaymentResponseProp contained payerPhone shippingAddress
  syntax keyword typescriptPaymentResponseProp contained shippingOption
  syntax cluster props add=typescriptPaymentResponseProp
  hi def link typescriptPaymentResponseProp Keyword
  syntax keyword typescriptPaymentAddressProp contained addressLine careOf city country
  syntax keyword typescriptPaymentAddressProp contained country dependentLocality languageCode
  syntax keyword typescriptPaymentAddressProp contained organization phone postalCode
  syntax keyword typescriptPaymentAddressProp contained recipient region sortingCode
  syntax cluster props add=typescriptPaymentAddressProp
  hi def link typescriptPaymentAddressProp Keyword
  syntax keyword typescriptPaymentShippingOptionProp contained id label amount selected
  syntax cluster props add=typescriptPaymentShippingOptionProp
  hi def link typescriptPaymentShippingOptionProp Keyword

  syntax keyword typescriptDOMNodeProp contained attributes baseURI baseURIObject childNodes
  syntax keyword typescriptDOMNodeProp contained firstChild lastChild localName namespaceURI
  syntax keyword typescriptDOMNodeProp contained nextSibling nodeName nodePrincipal
  syntax keyword typescriptDOMNodeProp contained nodeType nodeValue ownerDocument parentElement
  syntax keyword typescriptDOMNodeProp contained parentNode prefix previousSibling textContent
  syntax cluster props add=typescriptDOMNodeProp
  hi def link typescriptDOMNodeProp Keyword
  syntax keyword typescriptDOMNodeMethod contained appendChild cloneNode compareDocumentPosition nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDOMNodeMethod contained getUserData hasAttributes hasChildNodes nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDOMNodeMethod contained insertBefore isDefaultNamespace isEqualNode nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDOMNodeMethod contained isSameNode isSupported lookupNamespaceURI nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDOMNodeMethod contained lookupPrefix normalize removeChild nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDOMNodeMethod contained replaceChild setUserData nextgroup=typescriptFuncCallArg
  syntax match typescriptDOMNodeMethod contained /contains/
  syntax cluster props add=typescriptDOMNodeMethod
  hi def link typescriptDOMNodeMethod Keyword
  syntax keyword typescriptDOMNodeType contained ELEMENT_NODE ATTRIBUTE_NODE TEXT_NODE
  syntax keyword typescriptDOMNodeType contained CDATA_SECTION_NODEN_NODE ENTITY_REFERENCE_NODE
  syntax keyword typescriptDOMNodeType contained ENTITY_NODE PROCESSING_INSTRUCTION_NODEN_NODE
  syntax keyword typescriptDOMNodeType contained COMMENT_NODE DOCUMENT_NODE DOCUMENT_TYPE_NODE
  syntax keyword typescriptDOMNodeType contained DOCUMENT_FRAGMENT_NODE NOTATION_NODE
  hi def link typescriptDOMNodeType Keyword

  syntax keyword typescriptDOMElemAttrs contained accessKey clientHeight clientLeft
  syntax keyword typescriptDOMElemAttrs contained clientTop clientWidth id innerHTML
  syntax keyword typescriptDOMElemAttrs contained length onafterscriptexecute onbeforescriptexecute
  syntax keyword typescriptDOMElemAttrs contained oncopy oncut onpaste onwheel scrollHeight
  syntax keyword typescriptDOMElemAttrs contained scrollLeft scrollTop scrollWidth tagName
  syntax keyword typescriptDOMElemAttrs contained classList className name outerHTML
  syntax keyword typescriptDOMElemAttrs contained style
  hi def link typescriptDOMElemAttrs Keyword
  syntax keyword typescriptDOMElemFuncs contained getAttributeNS getAttributeNode getAttributeNodeNS
  syntax keyword typescriptDOMElemFuncs contained getBoundingClientRect getClientRects
  syntax keyword typescriptDOMElemFuncs contained getElementsByClassName getElementsByTagName
  syntax keyword typescriptDOMElemFuncs contained getElementsByTagNameNS hasAttribute
  syntax keyword typescriptDOMElemFuncs contained hasAttributeNS insertAdjacentHTML
  syntax keyword typescriptDOMElemFuncs contained matches querySelector querySelectorAll
  syntax keyword typescriptDOMElemFuncs contained removeAttribute removeAttributeNS
  syntax keyword typescriptDOMElemFuncs contained removeAttributeNode requestFullscreen
  syntax keyword typescriptDOMElemFuncs contained requestPointerLock scrollIntoView
  syntax keyword typescriptDOMElemFuncs contained setAttribute setAttributeNS setAttributeNode
  syntax keyword typescriptDOMElemFuncs contained setAttributeNodeNS setCapture supports
  syntax keyword typescriptDOMElemFuncs contained getAttribute
  hi def link typescriptDOMElemFuncs Keyword

  syntax keyword typescriptDOMDocProp contained activeElement body cookie defaultView
  syntax keyword typescriptDOMDocProp contained designMode dir domain embeds forms head
  syntax keyword typescriptDOMDocProp contained images lastModified links location plugins
  syntax keyword typescriptDOMDocProp contained postMessage readyState referrer registerElement
  syntax keyword typescriptDOMDocProp contained scripts styleSheets title vlinkColor
  syntax keyword typescriptDOMDocProp contained xmlEncoding characterSet compatMode
  syntax keyword typescriptDOMDocProp contained contentType currentScript doctype documentElement
  syntax keyword typescriptDOMDocProp contained documentURI documentURIObject firstChild
  syntax keyword typescriptDOMDocProp contained implementation lastStyleSheetSet namespaceURI
  syntax keyword typescriptDOMDocProp contained nodePrincipal ononline pointerLockElement
  syntax keyword typescriptDOMDocProp contained popupNode preferredStyleSheetSet selectedStyleSheetSet
  syntax keyword typescriptDOMDocProp contained styleSheetSets textContent tooltipNode
  syntax cluster props add=typescriptDOMDocProp
  hi def link typescriptDOMDocProp Keyword
  syntax keyword typescriptDOMDocMethod contained caretPositionFromPoint close createNodeIterator nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDOMDocMethod contained createRange createTreeWalker elementFromPoint nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDOMDocMethod contained getElementsByName adoptNode createAttribute nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDOMDocMethod contained createCDATASection createComment createDocumentFragment nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDOMDocMethod contained createElement createElementNS createEvent nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDOMDocMethod contained createExpression createNSResolver nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDOMDocMethod contained createProcessingInstruction createTextNode nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDOMDocMethod contained enableStyleSheetsForSet evaluate execCommand nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDOMDocMethod contained exitPointerLock getBoxObjectFor getElementById nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDOMDocMethod contained getElementsByClassName getElementsByTagName nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDOMDocMethod contained getElementsByTagNameNS getSelection nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDOMDocMethod contained hasFocus importNode loadOverlay open nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDOMDocMethod contained queryCommandSupported querySelector nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDOMDocMethod contained querySelectorAll write writeln nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptDOMDocMethod
  hi def link typescriptDOMDocMethod Keyword

  syntax keyword typescriptDOMEventTargetMethod contained addEventListener removeEventListener nextgroup=typescriptEventFuncCallArg
  syntax keyword typescriptDOMEventTargetMethod contained dispatchEvent waitUntil nextgroup=typescriptEventFuncCallArg
  syntax cluster props add=typescriptDOMEventTargetMethod
  hi def link typescriptDOMEventTargetMethod Keyword
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName AnimationEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName AudioProcessingEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName BeforeInputEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName BeforeUnloadEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName BlobEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName ClipboardEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName CloseEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName CompositionEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName CSSFontFaceLoadEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName CustomEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName DeviceLightEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName DeviceMotionEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName DeviceOrientationEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName DeviceProximityEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName DOMTransactionEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName DragEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName EditingBeforeInputEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName ErrorEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName FocusEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName GamepadEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName HashChangeEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName IDBVersionChangeEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName KeyboardEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName MediaStreamEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName MessageEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName MouseEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName MutationEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName OfflineAudioCompletionEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName PageTransitionEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName PointerEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName PopStateEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName ProgressEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName RelatedEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName RTCPeerConnectionIceEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName SensorEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName StorageEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName SVGEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName SVGZoomEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName TimeEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName TouchEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName TrackEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName TransitionEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName UIEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName UserProximityEvent
  syntax keyword typescriptDOMEventCons containedin=typescriptIdentifierName WheelEvent
  hi def link typescriptDOMEventCons Structure
  syntax keyword typescriptDOMEventProp contained bubbles cancelable currentTarget defaultPrevented
  syntax keyword typescriptDOMEventProp contained eventPhase target timeStamp type isTrusted
  syntax keyword typescriptDOMEventProp contained isReload
  syntax cluster props add=typescriptDOMEventProp
  hi def link typescriptDOMEventProp Keyword
  syntax keyword typescriptDOMEventMethod contained initEvent preventDefault stopImmediatePropagation nextgroup=typescriptEventFuncCallArg
  syntax keyword typescriptDOMEventMethod contained stopPropagation respondWith default nextgroup=typescriptEventFuncCallArg
  syntax cluster props add=typescriptDOMEventMethod
  hi def link typescriptDOMEventMethod Keyword

  syntax keyword typescriptDOMStorage contained sessionStorage localStorage
  hi def link typescriptDOMStorage Keyword
  syntax keyword typescriptDOMStorageProp contained length
  syntax cluster props add=typescriptDOMStorageProp
  hi def link typescriptDOMStorageProp Keyword
  syntax keyword typescriptDOMStorageMethod contained getItem key setItem removeItem nextgroup=typescriptFuncCallArg
  syntax keyword typescriptDOMStorageMethod contained clear nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptDOMStorageMethod
  hi def link typescriptDOMStorageMethod Keyword

  syntax keyword typescriptDOMFormProp contained acceptCharset action elements encoding
  syntax keyword typescriptDOMFormProp contained enctype length method name target
  syntax cluster props add=typescriptDOMFormProp
  hi def link typescriptDOMFormProp Keyword
  syntax keyword typescriptDOMFormMethod contained reportValidity reset submit nextgroup=typescriptFuncCallArg
  syntax cluster props add=typescriptDOMFormMethod
  hi def link typescriptDOMFormMethod Keyword

  syntax keyword typescriptDOMStyle contained alignContent alignItems alignSelf animation
  syntax keyword typescriptDOMStyle contained animationDelay animationDirection animationDuration
  syntax keyword typescriptDOMStyle contained animationFillMode animationIterationCount
  syntax keyword typescriptDOMStyle contained animationName animationPlayState animationTimingFunction
  syntax keyword typescriptDOMStyle contained appearance backfaceVisibility background
  syntax keyword typescriptDOMStyle contained backgroundAttachment backgroundBlendMode
  syntax keyword typescriptDOMStyle contained backgroundClip backgroundColor backgroundImage
  syntax keyword typescriptDOMStyle contained backgroundOrigin backgroundPosition backgroundRepeat
  syntax keyword typescriptDOMStyle contained backgroundSize border borderBottom borderBottomColor
  syntax keyword typescriptDOMStyle contained borderBottomLeftRadius borderBottomRightRadius
  syntax keyword typescriptDOMStyle contained borderBottomStyle borderBottomWidth borderCollapse
  syntax keyword typescriptDOMStyle contained borderColor borderImage borderImageOutset
  syntax keyword typescriptDOMStyle contained borderImageRepeat borderImageSlice borderImageSource
  syntax keyword typescriptDOMStyle contained borderImageWidth borderLeft borderLeftColor
  syntax keyword typescriptDOMStyle contained borderLeftStyle borderLeftWidth borderRadius
  syntax keyword typescriptDOMStyle contained borderRight borderRightColor borderRightStyle
  syntax keyword typescriptDOMStyle contained borderRightWidth borderSpacing borderStyle
  syntax keyword typescriptDOMStyle contained borderTop borderTopColor borderTopLeftRadius
  syntax keyword typescriptDOMStyle contained borderTopRightRadius borderTopStyle borderTopWidth
  syntax keyword typescriptDOMStyle contained borderWidth bottom boxDecorationBreak
  syntax keyword typescriptDOMStyle contained boxShadow boxSizing breakAfter breakBefore
  syntax keyword typescriptDOMStyle contained breakInside captionSide caretColor caretShape
  syntax keyword typescriptDOMStyle contained caret clear clip clipPath color columns
  syntax keyword typescriptDOMStyle contained columnCount columnFill columnGap columnRule
  syntax keyword typescriptDOMStyle contained columnRuleColor columnRuleStyle columnRuleWidth
  syntax keyword typescriptDOMStyle contained columnSpan columnWidth content counterIncrement
  syntax keyword typescriptDOMStyle contained counterReset cursor direction display
  syntax keyword typescriptDOMStyle contained emptyCells flex flexBasis flexDirection
  syntax keyword typescriptDOMStyle contained flexFlow flexGrow flexShrink flexWrap
  syntax keyword typescriptDOMStyle contained float font fontFamily fontFeatureSettings
  syntax keyword typescriptDOMStyle contained fontKerning fontLanguageOverride fontSize
  syntax keyword typescriptDOMStyle contained fontSizeAdjust fontStretch fontStyle fontSynthesis
  syntax keyword typescriptDOMStyle contained fontVariant fontVariantAlternates fontVariantCaps
  syntax keyword typescriptDOMStyle contained fontVariantEastAsian fontVariantLigatures
  syntax keyword typescriptDOMStyle contained fontVariantNumeric fontVariantPosition
  syntax keyword typescriptDOMStyle contained fontWeight grad grid gridArea gridAutoColumns
  syntax keyword typescriptDOMStyle contained gridAutoFlow gridAutoPosition gridAutoRows
  syntax keyword typescriptDOMStyle contained gridColumn gridColumnStart gridColumnEnd
  syntax keyword typescriptDOMStyle contained gridRow gridRowStart gridRowEnd gridTemplate
  syntax keyword typescriptDOMStyle contained gridTemplateAreas gridTemplateRows gridTemplateColumns
  syntax keyword typescriptDOMStyle contained height hyphens imageRendering imageResolution
  syntax keyword typescriptDOMStyle contained imageOrientation imeMode inherit justifyContent
  syntax keyword typescriptDOMStyle contained left letterSpacing lineBreak lineHeight
  syntax keyword typescriptDOMStyle contained listStyle listStyleImage listStylePosition
  syntax keyword typescriptDOMStyle contained listStyleType margin marginBottom marginLeft
  syntax keyword typescriptDOMStyle contained marginRight marginTop marks mask maskType
  syntax keyword typescriptDOMStyle contained maxHeight maxWidth minHeight minWidth
  syntax keyword typescriptDOMStyle contained mixBlendMode objectFit objectPosition
  syntax keyword typescriptDOMStyle contained opacity order orphans outline outlineColor
  syntax keyword typescriptDOMStyle contained outlineOffset outlineStyle outlineWidth
  syntax keyword typescriptDOMStyle contained overflow overflowWrap overflowX overflowY
  syntax keyword typescriptDOMStyle contained overflowClipBox padding paddingBottom
  syntax keyword typescriptDOMStyle contained paddingLeft paddingRight paddingTop pageBreakAfter
  syntax keyword typescriptDOMStyle contained pageBreakBefore pageBreakInside perspective
  syntax keyword typescriptDOMStyle contained perspectiveOrigin pointerEvents position
  syntax keyword typescriptDOMStyle contained quotes resize right shapeImageThreshold
  syntax keyword typescriptDOMStyle contained shapeMargin shapeOutside tableLayout tabSize
  syntax keyword typescriptDOMStyle contained textAlign textAlignLast textCombineHorizontal
  syntax keyword typescriptDOMStyle contained textDecoration textDecorationColor textDecorationLine
  syntax keyword typescriptDOMStyle contained textDecorationStyle textIndent textOrientation
  syntax keyword typescriptDOMStyle contained textOverflow textRendering textShadow
  syntax keyword typescriptDOMStyle contained textTransform textUnderlinePosition top
  syntax keyword typescriptDOMStyle contained touchAction transform transformOrigin
  syntax keyword typescriptDOMStyle contained transformStyle transition transitionDelay
  syntax keyword typescriptDOMStyle contained transitionDuration transitionProperty
  syntax keyword typescriptDOMStyle contained transitionTimingFunction unicodeBidi unicodeRange
  syntax keyword typescriptDOMStyle contained userSelect userZoom verticalAlign visibility
  syntax keyword typescriptDOMStyle contained whiteSpace width willChange wordBreak
  syntax keyword typescriptDOMStyle contained wordSpacing wordWrap writingMode zIndex
  hi def link typescriptDOMStyle Keyword



  let typescript_props = 1
  syntax keyword typescriptAnimationEvent contained animationend animationiteration
  syntax keyword typescriptAnimationEvent contained animationstart beginEvent endEvent
  syntax keyword typescriptAnimationEvent contained repeatEvent
  syntax cluster events add=typescriptAnimationEvent
  hi def link typescriptAnimationEvent Title
  syntax keyword typescriptCSSEvent contained CssRuleViewRefreshed CssRuleViewChanged
  syntax keyword typescriptCSSEvent contained CssRuleViewCSSLinkClicked transitionend
  syntax cluster events add=typescriptCSSEvent
  hi def link typescriptCSSEvent Title
  syntax keyword typescriptDatabaseEvent contained blocked complete error success upgradeneeded
  syntax keyword typescriptDatabaseEvent contained versionchange
  syntax cluster events add=typescriptDatabaseEvent
  hi def link typescriptDatabaseEvent Title
  syntax keyword typescriptDocumentEvent contained DOMLinkAdded DOMLinkRemoved DOMMetaAdded
  syntax keyword typescriptDocumentEvent contained DOMMetaRemoved DOMWillOpenModalDialog
  syntax keyword typescriptDocumentEvent contained DOMModalDialogClosed unload
  syntax cluster events add=typescriptDocumentEvent
  hi def link typescriptDocumentEvent Title
  syntax keyword typescriptDOMMutationEvent contained DOMAttributeNameChanged DOMAttrModified
  syntax keyword typescriptDOMMutationEvent contained DOMCharacterDataModified DOMContentLoaded
  syntax keyword typescriptDOMMutationEvent contained DOMElementNameChanged DOMNodeInserted
  syntax keyword typescriptDOMMutationEvent contained DOMNodeInsertedIntoDocument DOMNodeRemoved
  syntax keyword typescriptDOMMutationEvent contained DOMNodeRemovedFromDocument DOMSubtreeModified
  syntax cluster events add=typescriptDOMMutationEvent
  hi def link typescriptDOMMutationEvent Title
  syntax keyword typescriptDragEvent contained drag dragdrop dragend dragenter dragexit
  syntax keyword typescriptDragEvent contained draggesture dragleave dragover dragstart
  syntax keyword typescriptDragEvent contained drop
  syntax cluster events add=typescriptDragEvent
  hi def link typescriptDragEvent Title
  syntax keyword typescriptElementEvent contained invalid overflow underflow DOMAutoComplete
  syntax keyword typescriptElementEvent contained command commandupdate
  syntax cluster events add=typescriptElementEvent
  hi def link typescriptElementEvent Title
  syntax keyword typescriptFocusEvent contained blur change DOMFocusIn DOMFocusOut focus
  syntax keyword typescriptFocusEvent contained focusin focusout
  syntax cluster events add=typescriptFocusEvent
  hi def link typescriptFocusEvent Title
  syntax keyword typescriptFormEvent contained reset submit
  syntax cluster events add=typescriptFormEvent
  hi def link typescriptFormEvent Title
  syntax keyword typescriptFrameEvent contained DOMFrameContentLoaded
  syntax cluster events add=typescriptFrameEvent
  hi def link typescriptFrameEvent Title
  syntax keyword typescriptInputDeviceEvent contained click contextmenu DOMMouseScroll
  syntax keyword typescriptInputDeviceEvent contained dblclick gamepadconnected gamepaddisconnected
  syntax keyword typescriptInputDeviceEvent contained keydown keypress keyup MozGamepadButtonDown
  syntax keyword typescriptInputDeviceEvent contained MozGamepadButtonUp mousedown mouseenter
  syntax keyword typescriptInputDeviceEvent contained mouseleave mousemove mouseout
  syntax keyword typescriptInputDeviceEvent contained mouseover mouseup mousewheel MozMousePixelScroll
  syntax keyword typescriptInputDeviceEvent contained pointerlockchange pointerlockerror
  syntax keyword typescriptInputDeviceEvent contained wheel
  syntax cluster events add=typescriptInputDeviceEvent
  hi def link typescriptInputDeviceEvent Title
  syntax keyword typescriptMediaEvent contained audioprocess canplay canplaythrough
  syntax keyword typescriptMediaEvent contained durationchange emptied ended ended loadeddata
  syntax keyword typescriptMediaEvent contained loadedmetadata MozAudioAvailable pause
  syntax keyword typescriptMediaEvent contained play playing ratechange seeked seeking
  syntax keyword typescriptMediaEvent contained stalled suspend timeupdate volumechange
  syntax keyword typescriptMediaEvent contained waiting complete
  syntax cluster events add=typescriptMediaEvent
  hi def link typescriptMediaEvent Title
  syntax keyword typescriptMenuEvent contained DOMMenuItemActive DOMMenuItemInactive
  syntax cluster events add=typescriptMenuEvent
  hi def link typescriptMenuEvent Title
  syntax keyword typescriptNetworkEvent contained datachange dataerror disabled enabled
  syntax keyword typescriptNetworkEvent contained offline online statuschange connectionInfoUpdate
  syntax cluster events add=typescriptNetworkEvent
  hi def link typescriptNetworkEvent Title
  syntax keyword typescriptProgressEvent contained abort error load loadend loadstart
  syntax keyword typescriptProgressEvent contained progress timeout uploadprogress
  syntax cluster events add=typescriptProgressEvent
  hi def link typescriptProgressEvent Title
  syntax keyword typescriptResourceEvent contained cached error load
  syntax cluster events add=typescriptResourceEvent
  hi def link typescriptResourceEvent Title
  syntax keyword typescriptScriptEvent contained afterscriptexecute beforescriptexecute
  syntax cluster events add=typescriptScriptEvent
  hi def link typescriptScriptEvent Title
  syntax keyword typescriptSensorEvent contained compassneedscalibration devicelight
  syntax keyword typescriptSensorEvent contained devicemotion deviceorientation deviceproximity
  syntax keyword typescriptSensorEvent contained orientationchange userproximity
  syntax cluster events add=typescriptSensorEvent
  hi def link typescriptSensorEvent Title
  syntax keyword typescriptSessionHistoryEvent contained pagehide pageshow popstate
  syntax cluster events add=typescriptSessionHistoryEvent
  hi def link typescriptSessionHistoryEvent Title
  syntax keyword typescriptStorageEvent contained change storage
  syntax cluster events add=typescriptStorageEvent
  hi def link typescriptStorageEvent Title
  syntax keyword typescriptSVGEvent contained SVGAbort SVGError SVGLoad SVGResize SVGScroll
  syntax keyword typescriptSVGEvent contained SVGUnload SVGZoom
  syntax cluster events add=typescriptSVGEvent
  hi def link typescriptSVGEvent Title
  syntax keyword typescriptTabEvent contained visibilitychange
  syntax cluster events add=typescriptTabEvent
  hi def link typescriptTabEvent Title
  syntax keyword typescriptTextEvent contained compositionend compositionstart compositionupdate
  syntax keyword typescriptTextEvent contained copy cut paste select text
  syntax cluster events add=typescriptTextEvent
  hi def link typescriptTextEvent Title
  syntax keyword typescriptTouchEvent contained touchcancel touchend touchenter touchleave
  syntax keyword typescriptTouchEvent contained touchmove touchstart
  syntax cluster events add=typescriptTouchEvent
  hi def link typescriptTouchEvent Title
  syntax keyword typescriptUpdateEvent contained checking downloading error noupdate
  syntax keyword typescriptUpdateEvent contained obsolete updateready
  syntax cluster events add=typescriptUpdateEvent
  hi def link typescriptUpdateEvent Title
  syntax keyword typescriptValueChangeEvent contained hashchange input readystatechange
  syntax cluster events add=typescriptValueChangeEvent
  hi def link typescriptValueChangeEvent Title
  syntax keyword typescriptViewEvent contained fullscreen fullscreenchange fullscreenerror
  syntax keyword typescriptViewEvent contained resize scroll
  syntax cluster events add=typescriptViewEvent
  hi def link typescriptViewEvent Title
  syntax keyword typescriptWebsocketEvent contained close error message open
  syntax cluster events add=typescriptWebsocketEvent
  hi def link typescriptWebsocketEvent Title
  syntax keyword typescriptWindowEvent contained DOMWindowCreated DOMWindowClose DOMTitleChanged
  syntax cluster events add=typescriptWindowEvent
  hi def link typescriptWindowEvent Title
  syntax keyword typescriptUncategorizedEvent contained beforeunload message open show
  syntax cluster events add=typescriptUncategorizedEvent
  hi def link typescriptUncategorizedEvent Title
  syntax keyword typescriptServiceWorkerEvent contained install activate fetch
  syntax cluster events add=typescriptServiceWorkerEvent
  hi def link typescriptServiceWorkerEvent Title


endif

" patch
" patch for generated code
syntax keyword typescriptGlobal Promise
  \ nextgroup=typescriptGlobalPromiseDot,typescriptFuncCallArg,typescriptTypeArguments oneline
syntax keyword typescriptGlobal Map WeakMap
  \ nextgroup=typescriptGlobalPromiseDot,typescriptFuncCallArg,typescriptTypeArguments oneline

syntax keyword typescriptConstructor           contained constructor
  \ nextgroup=@typescriptCallSignature
  \ skipwhite skipempty


syntax cluster memberNextGroup contains=typescriptMemberOptionality,typescriptTypeAnnotation,@typescriptCallSignature

syntax match typescriptMember /#\?\K\k*/
  \ nextgroup=@memberNextGroup
  \ contained skipwhite

syntax match typescriptMethodAccessor contained /\v(get|set)\s\K/me=e-1
  \ nextgroup=@typescriptMembers

syntax cluster typescriptPropertyMemberDeclaration contains=
  \ typescriptClassStatic,
  \ typescriptAccessibilityModifier,
  \ typescriptReadonlyModifier,
  \ typescriptMethodAccessor,
  \ @typescriptMembers
  " \ typescriptMemberVariableDeclaration

syntax match typescriptMemberOptionality /?\|!/ contained
  \ nextgroup=typescriptTypeAnnotation,@typescriptCallSignature
  \ skipwhite skipempty

syntax cluster typescriptMembers contains=typescriptMember,typescriptStringMember,typescriptComputedMember

syntax keyword typescriptClassStatic static
  \ nextgroup=@typescriptMembers,typescriptAsyncFuncKeyword,typescriptReadonlyModifier
  \ skipwhite contained

syntax keyword typescriptAccessibilityModifier public private protected contained

syntax keyword typescriptReadonlyModifier readonly contained

syntax region  typescriptStringMember   contained
  \ start=/\z(["']\)/  skip=/\\\\\|\\\z1\|\\\n/  end=/\z1/
  \ nextgroup=@memberNextGroup
  \ skipwhite skipempty

syntax region  typescriptComputedMember   contained matchgroup=typescriptProperty
  \ start=/\[/rs=s+1 end=/]/
  \ contains=@typescriptValue,typescriptMember,typescriptMappedIn
  \ nextgroup=@memberNextGroup
  \ skipwhite skipempty

"don't add typescriptMembers to nextgroup, let outer scope match it
" so we won't match abstract method outside abstract class
syntax keyword typescriptAbstract              abstract
  \ nextgroup=typescriptClassKeyword
  \ skipwhite skipnl
syntax keyword typescriptClassKeyword          class
  \ nextgroup=typescriptClassName,typescriptClassExtends,typescriptClassBlock
  \ skipwhite

syntax match   typescriptClassName             contained /\K\k*/
  \ nextgroup=typescriptClassBlock,typescriptClassExtends,typescriptClassTypeParameter
  \ skipwhite skipnl

syntax region typescriptClassTypeParameter
  \ start=/</ end=/>/
  \ contains=@typescriptTypeParameterCluster
  \ nextgroup=typescriptClassBlock,typescriptClassExtends
  \ contained skipwhite skipnl

syntax keyword typescriptClassExtends          contained extends implements nextgroup=typescriptClassHeritage skipwhite skipnl

syntax match   typescriptClassHeritage         contained /\v(\k|\.|\(|\))+/
  \ nextgroup=typescriptClassBlock,typescriptClassExtends,typescriptMixinComma,typescriptClassTypeArguments
  \ contains=@typescriptValue
  \ skipwhite skipnl
  \ contained

syntax region typescriptClassTypeArguments matchgroup=typescriptTypeBrackets
  \ start=/</ end=/>/
  \ contains=@typescriptType
  \ nextgroup=typescriptClassExtends,typescriptClassBlock,typescriptMixinComma
  \ contained skipwhite skipnl

syntax match typescriptMixinComma /,/ contained nextgroup=typescriptClassHeritage skipwhite skipnl

" we need add arrowFunc to class block for high order arrow func
" see test case
syntax region  typescriptClassBlock matchgroup=typescriptBraces start=/{/ end=/}/
  \ contains=@typescriptPropertyMemberDeclaration,typescriptAbstract,@typescriptComments,typescriptBlock,typescriptAssign,typescriptDecorator,typescriptAsyncFuncKeyword,typescriptArrowFunc
  \ contained fold

syntax keyword typescriptInterfaceKeyword          interface nextgroup=typescriptInterfaceName skipwhite
syntax match   typescriptInterfaceName             contained /\k\+/
  \ nextgroup=typescriptObjectType,typescriptInterfaceExtends,typescriptInterfaceTypeParameter
  \ skipwhite skipnl
syntax region typescriptInterfaceTypeParameter
  \ start=/</ end=/>/
  \ contains=@typescriptTypeParameterCluster
  \ nextgroup=typescriptObjectType,typescriptInterfaceExtends
  \ contained
  \ skipwhite skipnl

syntax keyword typescriptInterfaceExtends          contained extends nextgroup=typescriptInterfaceHeritage skipwhite skipnl

syntax match typescriptInterfaceHeritage contained /\v(\k|\.)+/
  \ nextgroup=typescriptObjectType,typescriptInterfaceComma,typescriptInterfaceTypeArguments
  \ skipwhite

syntax region typescriptInterfaceTypeArguments matchgroup=typescriptTypeBrackets
  \ start=/</ end=/>/ skip=/\s*,\s*/
  \ contains=@typescriptType
  \ nextgroup=typescriptObjectType,typescriptInterfaceComma
  \ contained skipwhite

syntax match typescriptInterfaceComma /,/ contained nextgroup=typescriptInterfaceHeritage skipwhite skipnl

"Block VariableStatement EmptyStatement ExpressionStatement IfStatement IterationStatement ContinueStatement BreakStatement ReturnStatement WithStatement LabelledStatement SwitchStatement ThrowStatement TryStatement DebuggerStatement
syntax cluster typescriptStatement
  \ contains=typescriptBlock,typescriptVariable,
  \ @typescriptTopExpression,typescriptAssign,
  \ typescriptConditional,typescriptRepeat,typescriptBranch,
  \ typescriptLabel,typescriptStatementKeyword,
  \ typescriptFuncKeyword,
  \ typescriptTry,typescriptExceptions,typescriptDebugger,
  \ typescriptExport,typescriptInterfaceKeyword,typescriptEnum,
  \ typescriptModule,typescriptAliasKeyword,typescriptImport

syntax cluster typescriptPrimitive  contains=typescriptString,typescriptTemplate,typescriptRegexpString,typescriptNumber,typescriptBoolean,typescriptNull,typescriptArray

syntax cluster typescriptEventTypes            contains=typescriptEventString,typescriptTemplate,typescriptNumber,typescriptBoolean,typescriptNull

" top level expression: no arrow func
" also no func keyword. funcKeyword is contained in statement
" funcKeyword allows overloading (func without body)
" funcImpl requires body
syntax cluster typescriptTopExpression
  \ contains=@typescriptPrimitive,
  \ typescriptIdentifier,typescriptIdentifierName,
  \ typescriptOperator,typescriptUnaryOp,
  \ typescriptParenExp,typescriptRegexpString,
  \ typescriptGlobal,typescriptAsyncFuncKeyword,
  \ typescriptClassKeyword,typescriptTypeCast

" no object literal, used in type cast and arrow func
" TODO: change func keyword to funcImpl
syntax cluster typescriptExpression
  \ contains=@typescriptTopExpression,
  \ typescriptArrowFuncDef,
  \ typescriptFuncImpl

syntax cluster typescriptValue
  \ contains=@typescriptExpression,typescriptObjectLiteral

syntax cluster typescriptEventExpression       contains=typescriptArrowFuncDef,typescriptParenExp,@typescriptValue,typescriptRegexpString,@typescriptEventTypes,typescriptOperator,typescriptGlobal,jsxRegion

syntax keyword typescriptAsyncFuncKeyword      async
  \ nextgroup=typescriptFuncKeyword,typescriptArrowFuncDef
  \ skipwhite

syntax keyword typescriptAsyncFuncKeyword      await
  \ nextgroup=@typescriptValue
  \ skipwhite

syntax keyword typescriptFuncKeyword           function
  \ nextgroup=typescriptAsyncFunc,typescriptFuncName,@typescriptCallSignature
  \ skipwhite skipempty

syntax match   typescriptAsyncFunc             contained /*/
  \ nextgroup=typescriptFuncName,@typescriptCallSignature
  \ skipwhite skipempty

syntax match   typescriptFuncName              contained /\K\k*/
  \ nextgroup=@typescriptCallSignature
  \ skipwhite

" destructuring ({ a: ee }) =>
syntax match   typescriptArrowFuncDef          contained /(\(\s*\({\_[^}]*}\|\k\+\)\(:\_[^)]\)\?,\?\)\+)\s*=>/
  \ contains=typescriptArrowFuncArg,typescriptArrowFunc
  \ nextgroup=@typescriptExpression,typescriptBlock
  \ skipwhite skipempty

" matches `(a) =>` or `([a]) =>` or
" `(
"  a) =>`
syntax match   typescriptArrowFuncDef          contained /(\(\_s*[a-zA-Z\$_\[.]\_[^)]*\)*)\s*=>/
  \ contains=typescriptArrowFuncArg,typescriptArrowFunc
  \ nextgroup=@typescriptExpression,typescriptBlock
  \ skipwhite skipempty

syntax match   typescriptArrowFuncDef          contained /\K\k*\s*=>/
  \ contains=typescriptArrowFuncArg,typescriptArrowFunc
  \ nextgroup=@typescriptExpression,typescriptBlock
  \ skipwhite skipempty

" TODO: optimize this pattern
syntax region   typescriptArrowFuncDef          contained start=/(\_[^(^)]*):/ end=/=>/
  \ contains=typescriptArrowFuncArg,typescriptArrowFunc,typescriptTypeAnnotation
  \ nextgroup=@typescriptExpression,typescriptBlock
  \ skipwhite skipempty keepend

syntax match   typescriptArrowFunc             /=>/
syntax match   typescriptArrowFuncArg          contained /\K\k*/
syntax region  typescriptArrowFuncArg          contained start=/<\|(/ end=/\ze=>/ contains=@typescriptCallSignature

syntax region typescriptReturnAnnotation contained start=/:/ end=/{/me=e-1 contains=@typescriptType nextgroup=typescriptBlock


syntax region typescriptFuncImpl contained start=/function\>/ end=/{/me=e-1
  \ contains=typescriptFuncKeyword
  \ nextgroup=typescriptBlock

syntax cluster typescriptCallImpl contains=typescriptGenericImpl,typescriptParamImpl
syntax region typescriptGenericImpl matchgroup=typescriptTypeBrackets
  \ start=/</ end=/>/ skip=/\s*,\s*/
  \ contains=typescriptTypeParameter
  \ nextgroup=typescriptParamImpl
  \ contained skipwhite
syntax region typescriptParamImpl matchgroup=typescriptParens
  \ start=/(/ end=/)/
  \ contains=typescriptDecorator,@typescriptParameterList,@typescriptComments
  \ nextgroup=typescriptReturnAnnotation,typescriptBlock
  \ contained skipwhite skipnl

syntax match typescriptDecorator /@\([_$a-zA-Z][_$a-zA-Z0-9]*\.\)*[_$a-zA-Z][_$a-zA-Z0-9]*\>/
  \ nextgroup=typescriptFuncCallArg,typescriptTypeArguments
  \ contains=@_semantic,typescriptDotNotation

" Define the default highlighting.
hi def link typescriptReserved             Error

hi def link typescriptEndColons            Exception
hi def link typescriptSymbols              Normal
hi def link typescriptBraces               Function
hi def link typescriptParens               Normal
hi def link typescriptComment              Comment
hi def link typescriptLineComment          Comment
hi def link typescriptDocComment           Comment
hi def link typescriptCommentTodo          Todo
hi def link typescriptMagicComment         SpecialComment
hi def link typescriptRef                  Include
hi def link typescriptDocNotation          SpecialComment
hi def link typescriptDocTags              SpecialComment
hi def link typescriptDocNGParam           typescriptDocParam
hi def link typescriptDocParam             Function
hi def link typescriptDocNumParam          Function
hi def link typescriptDocEventRef          Function
hi def link typescriptDocNamedParamType    Type
hi def link typescriptDocParamName         Type
hi def link typescriptDocParamType         Type
hi def link typescriptString               String
hi def link typescriptSpecial              Special
hi def link typescriptStringLiteralType    String
hi def link typescriptTemplateLiteralType  String
hi def link typescriptStringMember         String
hi def link typescriptTemplate             String
hi def link typescriptEventString          String
hi def link typescriptDestructureString    String
hi def link typescriptASCII                Special
hi def link typescriptTemplateSB           Label
hi def link typescriptRegexpString         String
hi def link typescriptGlobal               Constant
hi def link typescriptTestGlobal           Function
hi def link typescriptPrototype            Type
hi def link typescriptConditional          Conditional
hi def link typescriptConditionalElse      Conditional
hi def link typescriptCase                 Conditional
hi def link typescriptDefault              typescriptCase
hi def link typescriptBranch               Conditional
hi def link typescriptIdentifier           Structure
hi def link typescriptVariable             Identifier
hi def link typescriptDestructureVariable  PreProc
hi def link typescriptEnumKeyword          Identifier
hi def link typescriptRepeat               Repeat
hi def link typescriptForOperator          Repeat
hi def link typescriptStatementKeyword     Statement
hi def link typescriptMessage              Keyword
hi def link typescriptOperator             Identifier
hi def link typescriptKeywordOp            Identifier
hi def link typescriptCastKeyword          Special
hi def link typescriptType                 Type
hi def link typescriptNull                 Boolean
hi def link typescriptNumber               Number
hi def link typescriptBoolean              Boolean
hi def link typescriptObjectLabel          typescriptLabel
hi def link typescriptDestructureLabel     Function
hi def link typescriptLabel                Label
hi def link typescriptTupleLable           Label
hi def link typescriptStringProperty       String
hi def link typescriptImport               Special
hi def link typescriptImportType           Special
hi def link typescriptAmbientDeclaration   Special
hi def link typescriptExport               Special
hi def link typescriptExportType           Special
hi def link typescriptModule               Special
hi def link typescriptTry                  Special
hi def link typescriptExceptions           Special

hi def link typescriptMember              Function
hi def link typescriptMethodAccessor       Operator

hi def link typescriptAsyncFuncKeyword     Keyword
hi def link typescriptObjectAsyncKeyword   Keyword
hi def link typescriptAsyncFor             Keyword
hi def link typescriptFuncKeyword          Keyword
hi def link typescriptAsyncFunc            Keyword
hi def link typescriptArrowFunc            Type
hi def link typescriptFuncName             Function
hi def link typescriptFuncArg              PreProc
hi def link typescriptArrowFuncArg         PreProc
hi def link typescriptFuncComma            Operator

hi def link typescriptClassKeyword         Keyword
hi def link typescriptClassExtends         Keyword
" hi def link typescriptClassName            Function
hi def link typescriptAbstract             Special
" hi def link typescriptClassHeritage        Function
" hi def link typescriptInterfaceHeritage    Function
hi def link typescriptClassStatic          StorageClass
hi def link typescriptReadonlyModifier     Keyword
hi def link typescriptInterfaceKeyword     Keyword
hi def link typescriptInterfaceExtends     Keyword
hi def link typescriptInterfaceName        Function

hi def link shellbang                      Comment

hi def link typescriptTypeParameter         Identifier
hi def link typescriptConstraint            Keyword
hi def link typescriptPredefinedType        Type
hi def link typescriptReadonlyArrayKeyword  Keyword
hi def link typescriptUnion                 Operator
hi def link typescriptFuncTypeArrow         Function
hi def link typescriptConstructorType       Function
hi def link typescriptTypeQuery             Keyword
hi def link typescriptAccessibilityModifier Keyword
hi def link typescriptOptionalMark          PreProc
hi def link typescriptFuncType              Special
hi def link typescriptMappedIn              Special
hi def link typescriptCall                  PreProc
hi def link typescriptParamImpl             PreProc
hi def link typescriptConstructSignature    Identifier
hi def link typescriptAliasDeclaration      Identifier
hi def link typescriptAliasKeyword          Keyword
hi def link typescriptUserDefinedType       Keyword
hi def link typescriptTypeReference         Identifier
hi def link typescriptConstructor           Keyword
hi def link typescriptDecorator             Special
hi def link typescriptAssertType            Keyword

hi link typeScript             NONE

if exists('s:cpo_save')
  let &cpo = s:cpo_save
  unlet s:cpo_save
endif
