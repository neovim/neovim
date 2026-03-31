" Vim syntax file
" Language:	Justfile
" Maintainer:	Peter Benjamin <@pbnj>
" Last Change:	2025 Jan 25
" Credits:	The original author, Noah Bogart <https://github.com/NoahTheDuke/vim-just/>

if exists('b:current_syntax')
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

let b:current_syntax = 'just'

" syncing fromstart prevents mismatched highlighting when jumping around in a justfile
" linebreaks= keeps multi-line constructs highlighted correctly while typing
syn sync fromstart linebreaks=10

" a-zA-Z0-9_-
syn iskeyword @,48-57,_,-

syn match justComment "#.*$" contains=@Spell,justCommentTodo
syn match justCommentInBody '#.*$' contained contains=justCommentTodo,justInterpolation,@justOtherCurlyBraces
syn keyword justCommentTodo TODO FIXME XXX contained
syn match justShebang "^\s*#!.*$" contains=justInterpolation,@justOtherCurlyBraces
syn match justName "\h\k*" contained
syn match justFunction "\h\k*" contained

syn match justPreBodyComment "\v%(\s|\\\n)*%([^\\]\n)@3<!#%([^!].*)?\n%(\t+| +)@=" transparent contained contains=justComment
   \ nextgroup=@justBodies skipnl

syn region justBacktick start=/`/ end=/`/
syn region justBacktick start=/```/ end=/```/
syn region justRawString start=/'/ end=/'/
syn region justRawString start=/'''/ end=/'''/
syn region justString start=/"/ skip=/\\\\\|\\"/ end=/"/ contains=justStringEscapeSequence,justStringUEscapeSequence,justStringEscapeError
syn region justString start=/"""/ skip=/\\\\\|\\"/ end=/"""/ contains=justStringEscapeSequence,justStringUEscapeSequence,justStringEscapeError

syn region justShellExpandRawString start=/\v\k@1<!x'/ end=/'/
   \ contains=justShellExpandVarRaw,justDollarEscape
syn region justShellExpandRawString start=/\v\k@1<!x'''/ end=/'''/
   \ contains=justShellExpandVarRaw,justDollarEscape
syn region justShellExpandString
   \ start=/\v\k@1<!x"/ skip=/\\\\\|\\"/ end=/"/
   \ contains=justStringEscapeSequence,justStringUEscapeSequence,justStringEscapeError,justShellExpandVar,justDollarEscape,justDollarEscapeSplit
syn region justShellExpandString
   \ start=/\v\k@1<!x"""/ skip=/\\\\\|\\"/ end=/"""/
   \ contains=justStringEscapeSequence,justStringUEscapeSequence,justStringEscapeError,justShellExpandVar,justDollarEscape,justDollarEscapeSplit

syn cluster justStringLiterals
   \ contains=justRawString,justString,justShellExpandRawString,justShellExpandString
syn cluster justAllStrings contains=justBacktick,@justStringLiterals

syn match justRegexReplacement
   \ /\v,%(\_s|\\\n)*%('\_[^']*'|'''%(\_.%(''')@!)*\_.?''')%(\_s|\\\n)*%(,%(\_s|\\\n)*)?\)/me=e-1
   \ transparent contained contains=@justExpr,@justStringsWithRegexCapture
syn match justRegexReplacement
   \ /\v,%(\_s|\\\n)*%("%(\_[^"]|\\")*"|"""%(\_.%(""")@!)*\_.?""")%(\_s|\\\n)*%(,%(\_s|\\\n)*)?\)/me=e-1
   \ transparent contained contains=@justExpr,@justStringsWithRegexCapture

syn region justRawStrRegexRepl start=/\v'/ end=/'/ contained contains=justRegexCapture,justDollarEscape
syn region justRawStrRegexRepl start=/\v'''/ end=/'''/ contained contains=justRegexCapture,justDollarEscape
syn region justStringRegexRepl start=/\v"/ skip=/\\\\\|\\"/ end=/"/ contained contains=justStringEscapeSequence,justStringUEscapeSequence,justStringEscapeError,justRegexCapture,justDollarEscape,justDollarEscapeSplit
syn region justStringRegexRepl start=/\v"""/ skip=/\\\\\|\\"/ end=/"""/ contained contains=justStringEscapeSequence,justStringUEscapeSequence,justStringEscapeError,justRegexCapture,justDollarEscape,justDollarEscapeSplit
syn match justRegexCapture '\v\$%(\w+|\{\w+\})' contained
syn cluster justStringsWithRegexCapture contains=justRawStrRegexRepl,justStringRegexRepl

syn cluster justRawStrings contains=justRawString,justRawStrRegexRepl

syn region justStringInsideBody start=/\v\\@1<!'/ end=/'/ contained contains=justInterpolation,@justOtherCurlyBraces,justIndentError
syn region justStringInsideBody start=/\v\\@1<!"/ skip=/\v\\@1<!\\"/ end=/"/ contained contains=justInterpolation,@justOtherCurlyBraces,justIndentError
syn region justStringInShebangBody start=/\v\\@1<!'/ end=/'/ contained contains=justInterpolation,@justOtherCurlyBraces,justShebangIndentError
syn region justStringInShebangBody start=/\v\\@1<!"/ skip=/\v\\@1<!\\"/ end=/"/ contained contains=justInterpolation,@justOtherCurlyBraces,justShebangIndentError

syn match justStringEscapeError '\\.' contained
syn match justStringEscapeSequence '\v\\[tnr"\\]' contained
syn match justStringUEscapeSequence '\v\\u\{[0-9A-Fa-f]{1,6}\}' contained

syn match justAssignmentOperator "\V:=" contained

syn region justExprParen start='\V(' end='\V)' transparent contains=@justExpr
syn region justExprParenInInterp start='\V(' end='\V)' transparent contained contains=@justExprInInterp

syn match justRecipeAt "^@" contained
syn match justRecipeColon ":" contained

syn region justRecipeAttributes
   \ matchgroup=justRecipeAttr start='\v^%(\\\n)@3<!\[' end='\V]'
   \ contains=justRecipeAttr,justRecipeAttrSep,justRecipeAttrArgs,justRecipeAttrArgError,justRecipeAttrValueShort

syn keyword justRecipeAttr
   \ confirm doc extension group linux macos no-cd no-exit-message no-quiet openbsd positional-arguments private script unix windows working-directory
   \ contained
syn match justRecipeAttrSep ',' contained
syn match justRecipeAttrValueShort '\v:%(\_s|\\\n)*' transparent contained
   \ contains=justRecipeAttrValueColon nextgroup=@justStringLiterals,justInvalidAttrValue
syn match justRecipeAttrValueColon '\V:' contained
syn region justRecipeAttrArgs matchgroup=justRecipeAttr start='\V(' end='\V)' contained
   \ contains=@justStringLiterals
syn match justRecipeAttrArgError '\v\(%(\s|\\?\n)*\)' contained

syn match justInvalidAttrValue '\v[^"',]["']@![^,\]]*' contained

syn match justRecipeDeclSimple "\v^\@?\h\k*%(%(\s|\\\n)*:\=@!)@="
   \ transparent contains=justRecipeName
   \ nextgroup=justRecipeNoDeps,justRecipeDeps

syn region justRecipeDeclComplex start="\v^\@?\h\k*%(\s|\\\n)+%([+*$]+%(\s|\\\n)*)*\h" end="\v%(:\=@!)@=|$"
   \ transparent
   \ contains=justRecipeName,justParameter
   \ nextgroup=justRecipeNoDeps,justRecipeDeps

syn match justRecipeName "\v^\@?\h\k*" transparent contained contains=justRecipeAt,justFunction

syn match justParameter "\v%(\s|\\\n)@3<=%(%([*+]%(\s|\\\n)*)?%(\$%(\s|\\\n)*)?|\$%(\s|\\\n)*[*+]%(\s|\\\n)*)\h\k*"
   \ transparent contained
   \ contains=justName,justVariadicPrefix,justParamExport,justVariadicPrefixError
   \ nextgroup=justPreParamValue

syn match justPreParamValue '\v%(\s|\\\n)*\=%(\s|\\\n)*'
   \ contained transparent
   \ contains=justParameterOperator
   \ nextgroup=justParamValue

syn region justParamValue contained transparent
   \ start="\v\S"
   \ skip="\\\n"
   \ end="\v%(\s|^)%([*+$:]|\h)@=|:@=|$"
   \ contains=@justAllStrings,justRecipeParenDefault,@justExprFunc
   \ nextgroup=justParameterError
syn match justParameterOperator "\V=" contained

syn match justVariadicPrefix "\v%(\s|\\\n)@3<=[*+]%(%(\s|\\\n)*\$?%(\s|\\\n)*\h)@=" contained
syn match justParamExport '\V$' contained
syn match justVariadicPrefixError "\v\$%(\s|\\\n)*[*+]" contained

syn match justParameterError "\v%(%([+*$]+%(\s|\\\n)*)*\h\k*)@>%(%(\s|\\\n)*\=)@!" contained

syn region justRecipeParenDefault
   \ matchgroup=justRecipeDepParamsParen start='\v%(\=%(\s|\\\n)*)@<=\(' end='\V)'
   \ contained
   \ contains=@justExpr
syn match justRecipeSubsequentDeps '\V&&' contained

syn match justRecipeNoDeps '\v:%(\s|\\\n)*\n|:#@=|:%(\s|\\\n)+#@='
   \ transparent contained
   \ contains=justRecipeColon
   \ nextgroup=justPreBodyComment,@justBodies
syn region justRecipeDeps start="\v:%(\s|\\\n)*%([a-zA-Z_(]|\&\&)" skip='\\\n' end="\v#@=|\\@1<!\n"
   \ transparent contained
   \ contains=justFunction,justRecipeColon,justRecipeSubsequentDeps,justRecipeParamDep
   \ nextgroup=justPreBodyComment,@justBodies

syn region justRecipeParamDep contained transparent
   \ matchgroup=justRecipeDepParamsParen
   \ start="\V("
   \ end="\V)"
   \ contains=justRecipeDepParenName,@justExpr

syn keyword justBoolean true false contained

syn match justAssignment "\v^\h\k*%(\s|\\\n)*:\=" transparent contains=justAssignmentOperator

syn match justSet '\v^set' contained
syn keyword justSetKeywords
   \ allow-duplicate-recipes allow-duplicate-variables dotenv-load dotenv-filename dotenv-path dotenv-required export fallback ignore-comments positional-arguments quiet script-interpreter shell tempdir unstable windows-shell working-directory
   \ contained
syn keyword justSetDeprecatedKeywords windows-powershell contained
syn match justBooleanSet "\v^set%(\s|\\\n)+%(allow-duplicate-%(recip|variabl)es|dotenv-%(loa|require)d|export|fallback|ignore-comments|positional-arguments|quiet|unstable|windows-powershell)%(%(\s|\\\n)*:\=%(\s|\\\n)*%(true|false))?%(\s|\\\n)*%($|#@=)"
   \ contains=justSet,justSetKeywords,justSetDeprecatedKeywords,justAssignmentOperator,justBoolean
   \ transparent

syn match justStringSet '\v^set%(\s|\\\n)+\k+%(\s|\\\n)*:\=%(\s|\\\n)*%(x?['"])@=' transparent contains=justSet,justSetKeywords,justAssignmentOperator

syn match justShellSet
   \ "\v^set%(\s|\\\n)+%(s%(hell|cript-interpreter)|windows-shell)%(\s|\\\n)*:\=%(\s|\\\n)*\[@="
   \ contains=justSet,justSetKeywords,justAssignmentOperator
   \ transparent skipwhite
   \ nextgroup=justShellSetValue
syn region justShellSetValue
   \ start='\V[' end='\V]'
   \ contained
   \ contains=@justStringLiterals,justShellSetError

syn match justShellSetError '\v\k+['"]@!' contained

syn match justAlias '\v^alias' contained
syn match justAliasDecl "\v^alias%(\s|\\\n)+\h\k*%(\s|\\\n)*:\=%(\s|\\\n)*"
   \ transparent
   \ contains=justAlias,justFunction,justAssignmentOperator
   \ nextgroup=justAliasRes
syn match justAliasRes '\v\h\k*%(\s|\\\n)*%(#@=|$)' contained transparent contains=justFunction

syn match justExportedAssignment "\v^export%(\s|\\\n)+\h\k*%(\s|\\\n)*:\=" transparent
   \ contains=justExport,justAssignmentOperator

syn match justExport '\v^export' contained

syn match justUnexportStatement '\v^unexport%(\s|\\\n)+\w+\s*$' contains=justUnexport
syn match justUnexport '\v^unexport' contained

syn keyword justConditional if else
syn region justConditionalBraces start="\v\{\{@!" end="\v\}@=" transparent contains=@justExpr
syn region justConditionalBracesInInterp start="\v\{\{@!" end="\v\}@=" transparent contained contains=@justExprInInterp

syn match justLineLeadingSymbol "\v^%(\\\n)@3<!\s+\zs%(\@-|-\@|\@|-)"

syn match justLineContinuation "\\$"
   \ containedin=ALLBUT,justComment,justCommentInBody,justShebang,@justRawStrings,justRecipeAttrArgError,justShellExpandRawDefaultValue

syn region justBody
   \ start=/\v^\z( +|\t+)%(#!)@!\S/
   \ skip='\v\\\n|\n\s*$'
   \ end="\v\n\z1@!|%(^\S)@2<=\_.@="
   \ contains=justInterpolation,@justOtherCurlyBraces,justLineLeadingSymbol,justCommentInBody,justStringInsideBody,justIndentError
   \ contained

syn region justShebangBody
   \ start="\v^\z( +|\t+)#!"
   \ skip='\v\\\n|\n\s*$'
   \ end="\v\n\z1@!|%(^\S)@2<=\_.@="
   \ contains=justInterpolation,@justOtherCurlyBraces,justCommentInBody,justShebang,justStringInShebangBody,justShebangIndentError
   \ contained

syn cluster justBodies contains=justBody,justShebangBody

syn match justIndentError '\v^%(\\\n)@3<!%( +\zs\t|\t+\zs )\s*\S@='
syn match justShebangIndentError '\v^ +\zs\t\s*\S@='

syn region justInterpolation
   \ matchgroup=justInterpolationDelim
   \ start="\v\{\{\{@!" end="\v%(%(\\\n\s|\S)\s*)@<=\}\}|$"
   \ matchgroup=justInterpError end='^\S'
   \ contained
   \ contains=@justExprInInterp

syn match justBadCurlyBraces '\v\{{3}\ze[^{]' contained
syn match justCurlyBraces '\v\{{4}' contained
syn match justBadCurlyBraces '\v\{{5}\ze[^{]' contained
syn cluster justOtherCurlyBraces contains=justCurlyBraces,justBadCurlyBraces

syn match justFunctionCall "\v\w+%(\s|\\\n)*\(@=" transparent contains=justBuiltInFunction

" error() is intentionally not included in this list
syn keyword justBuiltInFunction
   \ absolute_path append arch blake3 blake3_file cache_dir cache_directory canonicalize capitalize choose clean config_dir config_directory config_local_dir config_local_directory data_dir data_directory data_local_dir data_local_directory datetime datetime_utc encode_uri_component env env_var env_var_or_default executable_dir executable_directory extension file_name file_stem home_dir home_directory invocation_dir invocation_dir_native invocation_directory invocation_directory_native is_dependency join just_executable just_pid justfile justfile_dir justfile_directory kebabcase lowercamelcase lowercase module_dir module_directory module_file num_cpus os os_family parent_dir parent_directory path_exists prepend quote replace replace_regex semver_matches sha256 sha256_file shell shoutykebabcase shoutysnakecase snakecase source_dir source_directory source_file style titlecase trim trim_end trim_end_match trim_end_matches trim_start trim_start_match trim_start_matches uppercamelcase uppercase uuid without_extension
   \ contained

syn match justUserDefinedError "\v%(assert|error)%(%(\s|\\\n)*\()@="

syn match justReplaceRegex '\vreplace_regex%(\s|\\\n)*\(@=' transparent contains=justBuiltInFunction nextgroup=justReplaceRegexCall
syn match justReplaceRegexInInterp '\vreplace_regex%(\s|\\\n)*\(@=' transparent contained contains=justBuiltInFunction nextgroup=justReplaceRegexCallInInterp

syn region justReplaceRegexCall
   \ matchgroup=justReplaceRegexCall
   \ start='\V(' end='\V)'
   \ transparent contained
   \ contains=@justExpr,justRegexReplacement
syn region justReplaceRegexCallInInterp
   \ matchgroup=justReplaceRegexCall
   \ start='\V(' end='\V)'
   \ transparent contained
   \ contains=@justExprInInterp,justRegexReplacement

syn match justParameterLineContinuation '\v%(\s|\\\n)*' contained nextgroup=justParameterError

syn match justRecipeDepParenName '\v%(\(\n?)@3<=%(\_s|\\\n)*\h\k*'
   \ transparent contained
   \ contains=justFunction

syn cluster justBuiltInFunctions contains=justFunctionCall,justUserDefinedError

syn match justConditionalOperator "\V=="
syn match justConditionalOperator "\V!="
syn match justConditionalOperator "\V=~"

syn match justOperator "\V+"
syn match justOperator "\V/"
syn match justOperator "\V&&"
syn match justOperator "\V||"

syn keyword justConstant
   \ HEX HEXLOWER HEXUPPER
   \ CLEAR NORMAL BOLD ITALIC UNDERLINE INVERT HIDE STRIKETHROUGH
   \ BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE
   \ BG_BLACK BG_RED BG_GREEN BG_YELLOW BG_BLUE BG_MAGENTA BG_CYAN BG_WHITE

syn match justShellExpandVarRaw '\v\$%(\{\_[^}]*\}|\w+)' contained contains=justShellExpandRawDefaultDelimiter
syn match justShellExpandRawDefaultDelimiter '\V:-' contained nextgroup=justShellExpandRawDefaultValue
syn match justShellExpandRawDefaultValue '\v\_[^}]*' contained
syn match justShellExpandVar '\v\$%(\w|\\\n\s*)+' contained
syn region justShellExpandVar start='\v\$%(\\\n\s*)*\{' end='\V}' contains=justShellExpandDefaultDelimiter,justStringEscapeSequence,justStringUEscapeSequence,justStringEscapeError
syn match justShellExpandDefaultDelimiter '\v:%(\\\n\s*)*-@=' contained nextgroup=justShellExpandDefault
syn region justShellExpandDefault
   \ matchgroup=justShellExpandDefaultDelimiter start='\V-' end='\v\}@='
   \ contained
   \ contains=justStringEscapeSequence,justStringUEscapeSequence,justStringEscapeError

syn match justDollarEscape '\V$$' contained
syn match justDollarEscapeSplit '\v\$%(\\\n\s*)*\$' contained

syn cluster justExprBase contains=@justAllStrings,@justBuiltInFunctions,justConditional,justConditionalOperator,justOperator,justConstant
syn cluster justExpr contains=@justExprBase,justExprParen,justConditionalBraces,justReplaceRegex
syn cluster justExprInInterp contains=@justExprBase,justName,justExprParenInInterp,justConditionalBracesInInterp,justReplaceRegexInInterp

syn cluster justExprFunc contains=@justBuiltInFunctions,justReplaceRegex,justExprParen

syn match justImport /\v^import%(%(\s|\\\n)*\?|%(\s|\\\n)+%(x?['"])@=)/ transparent
   \ contains=justImportStatement,justOptionalFile
syn match justImportStatement '^import' contained

syn match justOldInclude "^!include"

syn match justModule /\v^mod%(%(\s|\\\n)*\?)?%(\s|\\\n)+\h\k*\s*%($|%(\s|\\\n)*%(x?['"]|#)@=)/
   \ transparent contains=justModStatement,justName,justOptionalFile
syn match justModStatement '^mod' contained

syn match justOptionalFile '\V?' contained

" Most linked colorscheme colors are chosen based on semantics of the color name.
" Some are for parity with other syntax files (for example, Number for recipe body highlighting
" is to align with the make.vim distributed with Vim).
" Deprecated `just` syntaxes are highlighted as Underlined.
"
" Colors are linked 'def'(ault) so that users who prefer other colors
" can override them, e.g. in ~/.vim/after/syntax/just.vim
"
" Note that vim-just's highlight groups are an implementation detail and may be subject to change.

" The list of highlight links is sorted alphabetically.

hi def link justAlias                            Statement
hi def link justAssignmentOperator               Operator
hi def link justBacktick                         Special
hi def link justBadCurlyBraces                   Error
hi def link justBody                             Number
hi def link justBoolean                          Boolean
hi def link justBuiltInFunction                  Function
hi def link justComment                          Comment
hi def link justCommentInBody                    Comment
hi def link justCommentTodo                      Todo
hi def link justConditional                      Conditional
hi def link justConditionalOperator              Conditional
hi def link justConstant                         Constant
hi def link justCurlyBraces                      Special
hi def link justDollarEscape                     Special
hi def link justDollarEscapeSplit                Special
hi def link justExport                           Statement
hi def link justFunction                         Function
hi def link justImportStatement                  Include
hi def link justIndentError                      Error
hi def link justInterpError                      Error
hi def link justInterpolation                    Normal
hi def link justInterpolationDelim               Delimiter
hi def link justInvalidAttrValue                 Error
hi def link justLineContinuation                 Special
hi def link justLineLeadingSymbol                Special
hi def link justModStatement                     Keyword
hi def link justName                             Identifier
hi def link justOldInclude                       Error
hi def link justOperator                         Operator
hi def link justOptionalFile                     Conditional
hi def link justParameterError                   Error
hi def link justParameterOperator                Operator
hi def link justParamExport                      Statement
hi def link justRawString                        String
hi def link justRawStrRegexRepl                  String
hi def link justRecipeAt                         Special
hi def link justRecipeAttr                       Type
hi def link justRecipeAttrArgError               Error
hi def link justRecipeAttrSep                    Operator
hi def link justRecipeAttrValueColon             Operator
hi def link justRecipeColon                      Operator
hi def link justRecipeDepParamsParen             Delimiter
hi def link justRecipeSubsequentDeps             Delimiter
hi def link justRegexCapture                     Identifier
hi def link justSet                              Statement
hi def link justSetDeprecatedKeywords            Underlined
hi def link justSetKeywords                      Keyword
hi def link justShebang                          SpecialComment
hi def link justShebangBody                      Number
hi def link justShebangIndentError               Error
hi def link justShellExpandDefault               Character
hi def link justShellExpandDefaultDelimiter      Operator
hi def link justShellExpandRawDefaultDelimiter   Operator
hi def link justShellExpandRawDefaultValue       Character
hi def link justShellExpandRawString             String
hi def link justShellExpandString                String
hi def link justShellExpandVar                   PreProc
hi def link justShellExpandVarRaw                PreProc
hi def link justShellSetError                    Error
hi def link justString                           String
hi def link justStringEscapeError                Error
hi def link justStringEscapeSequence             Special
hi def link justStringInShebangBody              String
hi def link justStringInsideBody                 String
hi def link justStringRegexRepl                  String
hi def link justStringUEscapeSequence            Special
hi def link justUnexport                         Statement
hi def link justUserDefinedError                 Exception
hi def link justVariadicPrefix                   Statement
hi def link justVariadicPrefixError              Error

let &cpo = s:cpo_save
unlet s:cpo_save
