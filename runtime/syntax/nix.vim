" Vim syntax file
" Language:        Nix
" Maintainer:	   James Fleming <james@electronic-quill.net>
" Original Author: Daiderd Jordan <daiderd@gmail.com>
" Acknowledgement: Based on vim-nix maintained by Daiderd Jordan <daiderd@gmail.com>
"                  https://github.com/LnL7/vim-nix
" License:         MIT
" Last Change:     2022 Dec 06

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword nixBoolean     true false
syn keyword nixNull        null
syn keyword nixRecKeyword  rec

syn keyword nixOperator or
syn match   nixOperator '!=\|!'
syn match   nixOperator '<=\?'
syn match   nixOperator '>=\?'
syn match   nixOperator '&&'
syn match   nixOperator '//\='
syn match   nixOperator '=='
syn match   nixOperator '?'
syn match   nixOperator '||'
syn match   nixOperator '++\='
syn match   nixOperator '-'
syn match   nixOperator '\*'
syn match   nixOperator '->'

syn match nixParen '[()]'
syn match nixInteger '\d\+'

syn keyword nixTodo FIXME NOTE TODO OPTIMIZE XXX HACK contained
syn match   nixComment '#.*' contains=nixTodo,@Spell
syn region  nixComment start=+/\*+ end=+\*/+ contains=nixTodo,@Spell

syn region nixInterpolation matchgroup=nixInterpolationDelimiter start="\${" end="}" contained contains=@nixExpr,nixInterpolationParam

syn match nixSimpleStringSpecial /\\\%([nrt"\\$]\|$\)/ contained
syn match nixStringSpecial /''['$]/ contained
syn match nixStringSpecial /\$\$/ contained
syn match nixStringSpecial /''\\[nrt]/ contained

syn match nixSimpleStringSpecial /\$\$/ contained

syn match nixInvalidSimpleStringEscape /\\[^nrt"\\$]/ contained
syn match nixInvalidStringEscape /''\\[^nrt]/ contained

syn region nixSimpleString matchgroup=nixStringDelimiter start=+"+ skip=+\\"+ end=+"+ contains=nixInterpolation,nixSimpleStringSpecial,nixInvalidSimpleStringEscape
syn region nixString matchgroup=nixStringDelimiter start=+''+ skip=+''['$\\]+ end=+''+ contains=nixInterpolation,nixStringSpecial,nixInvalidStringEscape

syn match nixFunctionCall "[a-zA-Z_][a-zA-Z0-9_'-]*"

syn match nixPath "[a-zA-Z0-9._+-]*\%(/[a-zA-Z0-9._+-]\+\)\+"
syn match nixHomePath "\~\%(/[a-zA-Z0-9._+-]\+\)\+"
syn match nixSearchPath "[a-zA-Z0-9._+-]\+\%(\/[a-zA-Z0-9._+-]\+\)*" contained
syn match nixPathDelimiter "[<>]" contained
syn match nixSearchPathRef "<[a-zA-Z0-9._+-]\+\%(\/[a-zA-Z0-9._+-]\+\)*>" contains=nixSearchPath,nixPathDelimiter
syn match nixURI "[a-zA-Z][a-zA-Z0-9.+-]*:[a-zA-Z0-9%/?:@&=$,_.!~*'+-]\+"

syn match nixAttributeDot "\." contained
syn match nixAttribute "[a-zA-Z_][a-zA-Z0-9_'-]*\ze\%([^a-zA-Z0-9_'.-]\|$\)" contained
syn region nixAttributeAssignment start="=" end="\ze;" contained contains=@nixExpr
syn region nixAttributeDefinition start=/\ze[a-zA-Z_"$]/ end=";" contained contains=nixComment,nixAttribute,nixInterpolation,nixSimpleString,nixAttributeDot,nixAttributeAssignment

syn region nixInheritAttributeScope start="(" end="\ze)" contained contains=@nixExpr
syn region nixAttributeDefinition matchgroup=nixInherit start="\<inherit\>" end=";" contained contains=nixComment,nixInheritAttributeScope,nixAttribute

syn region nixAttributeSet start="{" end="}" contains=nixComment,nixAttributeDefinition

"                                                                                                              vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
syn region nixArgumentDefinitionWithDefault matchgroup=nixArgumentDefinition start="[a-zA-Z_][a-zA-Z0-9_'-]*\ze\%(\s\|#.\{-\}\n\|\n\|/\*\_.\{-\}\*/\)*?\@=" matchgroup=NONE end="[,}]\@=" transparent contained contains=@nixExpr
"                                                           vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
syn match nixArgumentDefinition "[a-zA-Z_][a-zA-Z0-9_'-]*\ze\%(\s\|#.\{-\}\n\|\n\|/\*\_.\{-\}\*/\)*[,}]\@=" contained
syn match nixArgumentEllipsis "\.\.\." contained
syn match nixArgumentSeparator "," contained

"                          vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv                        vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
syn match nixArgOperator '@\%(\s\|#.\{-\}\n\|\n\|/\*\_.\{-\}\*/\)*[a-zA-Z_][a-zA-Z0-9_'-]*\%(\s\|#.\{-\}\n\|\n\|/\*\_.\{-\}\*/\)*:'he=s+1 contained contains=nixAttribute

"                                                 vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
syn match nixArgOperator '[a-zA-Z_][a-zA-Z0-9_'-]*\%(\s\|#.\{-\}\n\|\n\|/\*\_.\{-\}\*/\)*@'hs=e-1 contains=nixAttribute nextgroup=nixFunctionArgument

" This is a bit more complicated, because function arguments can be passed in a
" very similar form on how attribute sets are defined and two regions with the
" same start patterns will shadow each other. Instead of a region we could use a
" match on {\_.\{-\}}, which unfortunately doesn't take nesting into account.
"
" So what we do instead is that we look forward until we are sure that it's a
" function argument. Unfortunately, we need to catch comments and both vertical
" and horizontal white space, which the following regex should hopefully do:
"
" "\%(\s\|#.\{-\}\n\|\n\|/\*\_.\{-\}\*/\)*"
"
" It is also used throught the whole file and is marked with 'v's as well.
"
" Fortunately the matching rules for function arguments are much simpler than
" for real attribute sets, because we can stop when we hit the first ellipsis or
" default value operator, but we also need to paste the "whitespace & comments
" eating" regex all over the place (marked with 'v's):
"
" Region match 1: { foo ? ... } or { foo, ... } or { ... } (ellipsis)
"                                         vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv   {----- identifier -----}vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
syn region nixFunctionArgument start="{\ze\%(\s\|#.\{-\}\n\|\n\|/\*\_.\{-\}\*/\)*\%([a-zA-Z_][a-zA-Z0-9_'-]*\%(\s\|#.\{-\}\n\|\n\|/\*\_.\{-\}\*/\)*[,?}]\|\.\.\.\)" end="}" contains=nixComment,nixArgumentDefinitionWithDefault,nixArgumentDefinition,nixArgumentEllipsis,nixArgumentSeparator nextgroup=nixArgOperator

" Now it gets more tricky, because we need to look forward for the colon, but
" there could be something like "{}@foo:", even though it's highly unlikely.
"
" Region match 2: {}
"                                         vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv    vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv@vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv{----- identifier -----}  vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
syn region nixFunctionArgument start="{\ze\%(\s\|#.\{-\}\n\|\n\|/\*\_.\{-\}\*/\)*}\%(\%(\s\|#.\{-\}\n\|\n\|/\*\_.\{-\}\*/\)*@\%(\s\|#.\{-\}\n\|\n\|/\*\_.\{-\}\*/\)*[a-zA-Z_][a-zA-Z0-9_'-]*\)\%(\s\|#.\{-\}\n\|\n\|/\*\_.\{-\}\*/\)*:" end="}" contains=nixComment nextgroup=nixArgOperator

"                                                               vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
syn match nixSimpleFunctionArgument "[a-zA-Z_][a-zA-Z0-9_'-]*\ze\%(\s\|#.\{-\}\n\|\n\|/\*\_.\{-\}\*/\)*:\([\n ]\)\@="

syn region nixList matchgroup=nixListBracket start="\[" end="\]" contains=@nixExpr

syn region nixLetExpr matchgroup=nixLetExprKeyword start="\<let\>" end="\<in\>" contains=nixComment,nixAttributeDefinition

syn keyword nixIfExprKeyword then contained
syn region nixIfExpr matchgroup=nixIfExprKeyword start="\<if\>" end="\<else\>" contains=@nixExpr,nixIfExprKeyword

syn region nixWithExpr matchgroup=nixWithExprKeyword start="\<with\>" matchgroup=NONE end=";" contains=@nixExpr

syn region nixAssertExpr matchgroup=nixAssertKeyword start="\<assert\>" matchgroup=NONE end=";" contains=@nixExpr

syn cluster nixExpr contains=nixBoolean,nixNull,nixOperator,nixParen,nixInteger,nixRecKeyword,nixConditional,nixBuiltin,nixSimpleBuiltin,nixComment,nixFunctionCall,nixFunctionArgument,nixArgOperator,nixSimpleFunctionArgument,nixPath,nixHomePath,nixSearchPathRef,nixURI,nixAttributeSet,nixList,nixSimpleString,nixString,nixLetExpr,nixIfExpr,nixWithExpr,nixAssertExpr,nixInterpolation

" These definitions override @nixExpr and have to come afterwards:

syn match nixInterpolationParam "[a-zA-Z_][a-zA-Z0-9_'-]*\%(\.[a-zA-Z_][a-zA-Z0-9_'-]*\)*" contained

" Non-namespaced Nix builtins as of version 2.0:
syn keyword nixSimpleBuiltin
      \ abort baseNameOf derivation derivationStrict dirOf fetchGit
      \ fetchMercurial fetchTarball import isNull map mapAttrs placeholder removeAttrs
      \ scopedImport throw toString


" Namespaced and non-namespaced Nix builtins as of version 2.0:
syn keyword nixNamespacedBuiltin contained
      \ abort add addErrorContext all any attrNames attrValues baseNameOf
      \ catAttrs compareVersions concatLists concatStringsSep currentSystem
      \ currentTime deepSeq derivation derivationStrict dirOf div elem elemAt
      \ fetchGit fetchMercurial fetchTarball fetchurl filter \ filterSource
      \ findFile foldl' fromJSON functionArgs genList \ genericClosure getAttr
      \ getEnv hasAttr hasContext hashString head import intersectAttrs isAttrs
      \ isBool isFloat isFunction isInt isList isNull isString langVersion
      \ length lessThan listToAttrs map mapAttrs match mul nixPath nixVersion
      \ parseDrvName partition path pathExists placeholder readDir readFile
      \ removeAttrs replaceStrings scopedImport seq sort split splitVersion
      \ storeDir storePath stringLength sub substring tail throw toFile toJSON
      \ toPath toString toXML trace tryEval typeOf unsafeDiscardOutputDependency
      \ unsafeDiscardStringContext unsafeGetAttrPos valueSize fromTOML bitAnd
      \ bitOr bitXor floor ceil

syn match nixBuiltin "builtins\.[a-zA-Z']\+"he=s+9 contains=nixComment,nixNamespacedBuiltin

hi def link nixArgOperator               Operator
hi def link nixArgumentDefinition        Identifier
hi def link nixArgumentEllipsis          Operator
hi def link nixAssertKeyword             Keyword
hi def link nixAttribute                 Identifier
hi def link nixAttributeDot              Operator
hi def link nixBoolean                   Boolean
hi def link nixBuiltin                   Special
hi def link nixComment                   Comment
hi def link nixConditional               Conditional
hi def link nixHomePath                  Include
hi def link nixIfExprKeyword             Keyword
hi def link nixInherit                   Keyword
hi def link nixInteger                   Integer
hi def link nixInterpolation             Macro
hi def link nixInterpolationDelimiter    Delimiter
hi def link nixInterpolationParam        Macro
hi def link nixInvalidSimpleStringEscape Error
hi def link nixInvalidStringEscape       Error
hi def link nixLetExprKeyword            Keyword
hi def link nixNamespacedBuiltin         Special
hi def link nixNull                      Constant
hi def link nixOperator                  Operator
hi def link nixPath                      Include
hi def link nixPathDelimiter             Delimiter
hi def link nixRecKeyword                Keyword
hi def link nixSearchPath                Include
hi def link nixSimpleBuiltin             Keyword
hi def link nixSimpleFunctionArgument    Identifier
hi def link nixSimpleString              String
hi def link nixSimpleStringSpecial       SpecialChar
hi def link nixString                    String
hi def link nixStringDelimiter           Delimiter
hi def link nixStringSpecial             Special
hi def link nixTodo                      Todo
hi def link nixURI                       Include
hi def link nixWithExprKeyword           Keyword

" This could lead up to slow syntax highlighting for large files, but usually
" large files such as all-packages.nix are one large attribute set, so if we'd
" use sync patterns we'd have to go back to the start of the file anyway
syn sync fromstart

let b:current_syntax = "nix"

let &cpo = s:cpo_save
unlet s:cpo_save
