" Vim syntax file
" Language:	      R (GNU S)
" Maintainer:	      Jakson Aquino <jalvesaq@gmail.com>
" Former Maintainers: Vaidotas Zemlys <zemlys@gmail.com>
" 		      Tom Payne <tom@tompayne.org>
" Contributor:        Johannes Ranke <jranke@uni-bremen.de>
" Homepage:           https://github.com/jalvesaq/R-Vim-runtime
" Last Change:	      Thu Aug 25, 2016  08:52PM
" Filenames:	      *.R *.r *.Rhistory *.Rt
"
" NOTE: The highlighting of R functions is defined in
" runtime files created by a filetype plugin, if installed.
"
" CONFIGURATION:
"   Syntax folding can be turned on by
"
"      let r_syntax_folding = 1
"
"   ROxygen highlighting can be turned off by
"
"      let r_hl_roxygen = 0
"
" Some lines of code were borrowed from Zhuojun Chen.

if exists("b:current_syntax")
  finish
endif

syn iskeyword @,48-57,_,.

if exists("g:r_syntax_folding") && g:r_syntax_folding
  setlocal foldmethod=syntax
endif
if !exists("g:r_hl_roxygen")
  let g:r_hl_roxygen = 1
endif

syn case match

" Comment
syn match rCommentTodo contained "\(BUG\|FIXME\|NOTE\|TODO\):"
syn match rComment contains=@Spell,rCommentTodo,rOBlock "#.*"

" Roxygen
if g:r_hl_roxygen
  syn region rOBlock start="^\s*\n#\{1,2}' " start="\%^#\{1,2}' " end="^\(#\{1,2}'\)\@!" contains=rOTitle,rOKeyword,rOExamples,@Spell keepend
  syn region rOTitle start="^\s*\n#\{1,2}' " start="\%^#\{1,2}' " end="^\(#\{1,2}'\s*$\)\@=" contained contains=rOCommentKey
  syn match rOCommentKey "#\{1,2}'" containedin=rOTitle contained

  syn region rOExamples start="^#\{1,2}' @examples.*"rs=e+1,hs=e+1 end="^\(#\{1,2}' @.*\)\@=" end="^\(#\{1,2}'\)\@!" contained contains=rOKeyword

  syn match rOKeyword contained "@\(param\|return\|name\|rdname\|examples\|example\|include\|docType\)"
  syn match rOKeyword contained "@\(S3method\|TODO\|aliases\|alias\|assignee\|author\|callGraphDepth\|callGraph\)"
  syn match rOKeyword contained "@\(callGraphPrimitives\|concept\|exportClass\|exportMethod\|exportPattern\|export\|formals\)"
  syn match rOKeyword contained "@\(format\|importClassesFrom\|importFrom\|importMethodsFrom\|import\|keywords\|useDynLib\)"
  syn match rOKeyword contained "@\(method\|noRd\|note\|references\|seealso\|setClass\|slot\|source\|title\|usage\)"
  syn match rOKeyword contained "@\(family\|template\|templateVar\|description\|details\|inheritParams\|field\)"
endif


if &filetype == "rhelp"
  " string enclosed in double quotes
  syn region rString contains=rSpecial,@Spell start=/"/ skip=/\\\\\|\\"/ end=/"/
  " string enclosed in single quotes
  syn region rString contains=rSpecial,@Spell start=/'/ skip=/\\\\\|\\'/ end=/'/
else
  " string enclosed in double quotes
  syn region rString contains=rSpecial,rStrError,@Spell start=/"/ skip=/\\\\\|\\"/ end=/"/
  " string enclosed in single quotes
  syn region rString contains=rSpecial,rStrError,@Spell start=/'/ skip=/\\\\\|\\'/ end=/'/
endif

syn match rStrError display contained "\\."


" New line, carriage return, tab, backspace, bell, feed, vertical tab, backslash
syn match rSpecial display contained "\\\(n\|r\|t\|b\|a\|f\|v\|'\|\"\)\|\\\\"

" Hexadecimal and Octal digits
syn match rSpecial display contained "\\\(x\x\{1,2}\|[0-8]\{1,3}\)"

" Unicode characters
syn match rSpecial display contained "\\u\x\{1,4}"
syn match rSpecial display contained "\\U\x\{1,8}"
syn match rSpecial display contained "\\u{\x\{1,4}}"
syn match rSpecial display contained "\\U{\x\{1,8}}"

" Statement
syn keyword rStatement   break next return
syn keyword rConditional if else
syn keyword rRepeat      for in repeat while

" Constant (not really)
syn keyword rConstant T F LETTERS letters month.abb month.name pi
syn keyword rConstant R.version.string

syn keyword rNumber   NA_integer_ NA_real_ NA_complex_ NA_character_

" Constants
syn keyword rConstant NULL
syn keyword rBoolean  FALSE TRUE
syn keyword rNumber   NA Inf NaN

" integer
syn match rInteger "\<\d\+L"
syn match rInteger "\<0x\([0-9]\|[a-f]\|[A-F]\)\+L"
syn match rInteger "\<\d\+[Ee]+\=\d\+L"

" number with no fractional part or exponent
syn match rNumber "\<\d\+\>"
" hexadecimal number
syn match rNumber "\<0x\([0-9]\|[a-f]\|[A-F]\)\+"

" floating point number with integer and fractional parts and optional exponent
syn match rFloat "\<\d\+\.\d*\([Ee][-+]\=\d\+\)\="
" floating point number with no integer part and optional exponent
syn match rFloat "\<\.\d\+\([Ee][-+]\=\d\+\)\="
" floating point number with no fractional part and optional exponent
syn match rFloat "\<\d\+[Ee][-+]\=\d\+"

" complex number
syn match rComplex "\<\d\+i"
syn match rComplex "\<\d\++\d\+i"
syn match rComplex "\<0x\([0-9]\|[a-f]\|[A-F]\)\+i"
syn match rComplex "\<\d\+\.\d*\([Ee][-+]\=\d\+\)\=i"
syn match rComplex "\<\.\d\+\([Ee][-+]\=\d\+\)\=i"
syn match rComplex "\<\d\+[Ee][-+]\=\d\+i"

syn match rAssign    '='
syn match rOperator    "&"
syn match rOperator    '-'
syn match rOperator    '\*'
syn match rOperator    '+'
if &filetype != "rmd" && &filetype != "rrst"
  syn match rOperator    "[|!<>^~/:]"
else
  syn match rOperator    "[|!<>^~`/:]"
endif
syn match rOperator    "%\{2}\|%\S\{-}%"
syn match rOperator '\([!><]\)\@<=='
syn match rOperator '=='
syn match rOpError  '\*\{3}'
syn match rOpError  '//'
syn match rOpError  '&&&'
syn match rOpError  '|||'
syn match rOpError  '<<'
syn match rOpError  '>>'

syn match rAssign "<\{1,2}-"
syn match rAssign "->\{1,2}"

" Special
syn match rDelimiter "[,;:]"

" Error
if exists("g:r_syntax_folding")
  syn region rRegion matchgroup=Delimiter start=/(/ matchgroup=Delimiter end=/)/ transparent contains=ALLBUT,rError,rBraceError,rCurlyError fold
  syn region rRegion matchgroup=Delimiter start=/{/ matchgroup=Delimiter end=/}/ transparent contains=ALLBUT,rError,rBraceError,rParenError fold
  syn region rRegion matchgroup=Delimiter start=/\[/ matchgroup=Delimiter end=/]/ transparent contains=ALLBUT,rError,rCurlyError,rParenError fold
else
  syn region rRegion matchgroup=Delimiter start=/(/ matchgroup=Delimiter end=/)/ transparent contains=ALLBUT,rError,rBraceError,rCurlyError
  syn region rRegion matchgroup=Delimiter start=/{/ matchgroup=Delimiter end=/}/ transparent contains=ALLBUT,rError,rBraceError,rParenError
  syn region rRegion matchgroup=Delimiter start=/\[/ matchgroup=Delimiter end=/]/ transparent contains=ALLBUT,rError,rCurlyError,rParenError
endif

syn match rError      "[)\]}]"
syn match rBraceError "[)}]" contained
syn match rCurlyError "[)\]]" contained
syn match rParenError "[\]}]" contained

if !exists("g:R_hi_fun")
  let g:R_hi_fun = 1
endif
if g:R_hi_fun
  " Nvim-R:
  runtime R/functions.vim
endif

syn match rDollar display contained "\$"
syn match rDollar display contained "@"

" List elements will not be highlighted as functions:
syn match rLstElmt "\$[a-zA-Z0-9\\._]*" contains=rDollar
syn match rLstElmt "@[a-zA-Z0-9\\._]*" contains=rDollar

" Functions that may add new objects
syn keyword rPreProc     library require attach detach source

if &filetype == "rhelp"
  syn match rHelpIdent '\\method'
  syn match rHelpIdent '\\S4method'
endif

" Type
syn keyword rType array category character complex double function integer list logical matrix numeric vector data.frame

" Name of object with spaces
if &filetype != "rmd" && &filetype != "rrst"
  syn region rNameWSpace start="`" end="`"
endif

if &filetype == "rhelp"
  syn match rhPreProc "^#ifdef.*"
  syn match rhPreProc "^#endif.*"
  syn match rhSection "\\dontrun\>"
endif

if exists("r_syn_minlines")
  exe "syn sync minlines=" . r_syn_minlines
else
  syn sync minlines=40
endif

" Define the default highlighting.
hi def link rAssign      Statement
hi def link rBoolean     Boolean
hi def link rBraceError  Error
hi def link rComment     Comment
hi def link rCommentTodo Todo
hi def link rComplex     Number
hi def link rConditional Conditional
hi def link rConstant    Constant
hi def link rCurlyError  Error
hi def link rDelimiter   Delimiter
hi def link rDollar      SpecialChar
hi def link rError       Error
hi def link rFloat       Float
hi def link rFunction    Function
hi def link rHelpIdent   Identifier
hi def link rhPreProc    PreProc
hi def link rhSection    PreCondit
hi def link rInteger     Number
hi def link rLstElmt     Normal
hi def link rNameWSpace  Normal
hi def link rNumber      Number
hi def link rOperator    Operator
hi def link rOpError     Error
hi def link rParenError  Error
hi def link rPreProc     PreProc
hi def link rRepeat      Repeat
hi def link rSpecial     SpecialChar
hi def link rStatement   Statement
hi def link rString      String
hi def link rStrError    Error
hi def link rType        Type
if g:r_hl_roxygen
  hi def link rOKeyword    Title
  hi def link rOBlock      Comment
  hi def link rOTitle      Title
  hi def link rOCommentKey Comment
  hi def link rOExamples   SpecialComment
endif


let b:current_syntax="r"

" vim: ts=8 sw=2
