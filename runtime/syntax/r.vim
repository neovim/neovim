" Vim syntax file
" Language:	      R (GNU S)
" Maintainer:	      Jakson Aquino <jalvesaq@gmail.com>
" Former Maintainers: Vaidotas Zemlys <zemlys@gmail.com>
" 		      Tom Payne <tom@tompayne.org>
" Contributor:        Johannes Ranke <jranke@uni-bremen.de>
" Homepage:           https://github.com/jalvesaq/R-Vim-runtime
" Last Change:	      Sun Mar 28, 2021  01:47PM
" Filenames:	      *.R *.r *.Rhistory *.Rt
"
" NOTE: The highlighting of R functions might be defined in
" runtime files created by a filetype plugin, if installed.
"
" CONFIGURATION:
"   Syntax folding can be turned on by
"
"      let r_syntax_folding = 1
"
"   ROxygen highlighting can be turned off by
"
"      let r_syntax_hl_roxygen = 0
"
" Some lines of code were borrowed from Zhuojun Chen.

if exists("b:current_syntax")
  finish
endif

if has("patch-7.4.1142")
  syn iskeyword @,48-57,_,.
else
  setlocal iskeyword=@,48-57,_,.
endif

" The variables g:r_hl_roxygen and g:r_syn_minlines were renamed on April 8, 2017.
if exists("g:r_hl_roxygen")
  let g:r_syntax_hl_roxygen = g:r_hl_roxygen
endif
if exists("g:r_syn_minlines")
  let g:r_syntax_minlines = g:r_syn_minlines
endif

if exists("g:r_syntax_folding") && g:r_syntax_folding
  setlocal foldmethod=syntax
endif

let g:r_syntax_hl_roxygen = get(g:, 'r_syntax_hl_roxygen', 1)

syn case match

" Comment
syn match rCommentTodo contained "\(BUG\|FIXME\|NOTE\|TODO\):"
syn match rTodoParen contained "\(BUG\|FIXME\|NOTE\|TODO\)\s*(.\{-})\s*:" contains=rTodoKeyw,rTodoInfo transparent
syn keyword rTodoKeyw BUG FIXME NOTE TODO contained
syn match rTodoInfo "(\zs.\{-}\ze)" contained
syn match rComment contains=@Spell,rCommentTodo,rTodoParen "#.*"

" Roxygen
if g:r_syntax_hl_roxygen
  " A roxygen block can start at the beginning of a file (first version) and
  " after a blank line (second version). It ends when a line appears that does not
  " contain a roxygen comment. In the following comments, any line containing
  " a roxygen comment marker (one or two hash signs # followed by a single
  " quote ' and preceded only by whitespace) is called a roxygen line. A
  " roxygen line containing only a roxygen comment marker, optionally followed
  " by whitespace is called an empty roxygen line.

  " First we match all roxygen blocks as containing only a title. In case an
  " empty roxygen line ending the title or a tag is found, this will be
  " overridden later by the definitions of rOBlock.
  syn match rOTitleBlock "\%^\(\s*#\{1,2}' .*\n\)\{1,}" contains=rOCommentKey,rOTitleTag
  syn match rOTitleBlock "^\s*\n\(\s*#\{1,2}' .*\n\)\{1,}" contains=rOCommentKey,rOTitleTag

  " A title as part of a block is always at the beginning of the block, i.e.
  " either at the start of a file or after a completely empty line.
  syn match rOTitle "\%^\(\s*#\{1,2}' .*\n\)\{-1,}\s*#\{1,2}'\s*$" contained contains=rOCommentKey,rOTitleTag
  syn match rOTitle "^\s*\n\(\s*#\{1,2}' .*\n\)\{-1,}\s*#\{1,2}'\s*$" contained contains=rOCommentKey,rOTitleTag
  syn match rOTitleTag contained "@title"

  " When a roxygen block has a title and additional content, the title
  " consists of one or more roxygen lines (as little as possible are matched),
  " followed either by an empty roxygen line
  syn region rOBlock start="\%^\(\s*#\{1,2}' .*\n\)\{-1,}\s*#\{1,2}'\s*$" end="^\s*\(#\{1,2}'\)\@!" contains=rOTitle,rOTag,rOExamples,@Spell keepend fold
  syn region rOBlock start="^\s*\n\(\s*#\{1,2}' .*\n\)\{-1,}\s*#\{1,2}'\s*$" end="^\s*\(#\{1,2}'\)\@!" contains=rOTitle,rOTag,rOExamples,@Spell keepend fold

  " or by a roxygen tag (we match everything starting with @ but not @@ which is used as escape sequence for a literal @).
  syn region rOBlock start="\%^\(\s*#\{1,2}' .*\n\)\{-}\s*#\{1,2}' @\(@\)\@!" end="^\s*\(#\{1,2}'\)\@!" contains=rOTitle,rOTag,rOExamples,@Spell keepend fold
  syn region rOBlock start="^\s*\n\(\s*#\{1,2}' .*\n\)\{-}\s*#\{1,2}' @\(@\)\@!" end="^\s*\(#\{1,2}'\)\@!" contains=rOTitle,rOTag,rOExamples,@Spell keepend fold

  " If a block contains an @rdname, @describeIn tag, it may have paragraph breaks, but does not have a title
  syn region rOBlockNoTitle start="\%^\(\s*#\{1,2}' .*\n\)\{-1,}\s*#\{1,2}'\s*\n\(\s*#\{1,2}'.*\n\)\{-}\s*#\{1,2}' @rdname" end="^\s*\(#\{1,2}'\)\@!" contains=rOTag,rOExamples,@Spell keepend fold
  syn region rOBlockNoTitle start="^\s*\n\(\s*#\{1,2}' .*\n\)\{-1,}\s*#\{1,2}'\s*\n\(\s*#\{1,2}'.*\n\)\{-}\s*#\{1,2}' @rdname" end="^\s*\(#\{1,2}'\)\@!" contains=rOTag,rOExamples,@Spell keepend fold
  syn region rOBlockNoTitle start="\%^\(\s*#\{1,2}' .*\n\)\{-1,}\s*#\{1,2}'\s*\n\(\s*#\{1,2}'.*\n\)\{-}\s*#\{1,2}' @describeIn" end="^\s*\(#\{1,2}'\)\@!" contains=rOTag,rOExamples,@Spell keepend fold
  syn region rOBlockNoTitle start="^\s*\n\(\s*#\{1,2}' .*\n\)\{-1,}\s*#\{1,2}'\s*\n\(\s*#\{1,2}'.*\n\)\{-}\s*#\{1,2}' @describeIn" end="^\s*\(#\{1,2}'\)\@!" contains=rOTag,rOExamples,@Spell keepend fold

  syn match rOCommentKey "^\s*#\{1,2}'" contained
  syn region rOExamples start="^\s*#\{1,2}' @examples.*"rs=e+1,hs=e+1 end="^\(#\{1,2}' @.*\)\@=" end="^\(#\{1,2}'\)\@!" contained contains=rOTag fold

  " R6 classes may contain roxygen lines independent of roxygen blocks
  syn region rOR6Class start=/R6Class(/ end=/)/ transparent contains=ALLBUT,rError,rBraceError,rCurlyError fold
  syn match rOR6Block "#\{1,2}'.*" contains=rOTag,rOExamples,@Spell containedin=rOR6Class contained
  syn match rOR6Block "^\s*#\{1,2}'.*" contains=rOTag,rOExamples,@Spell containedin=rOR6Class contained

  " rOTag list originally generated from the lists that were available in
  " https://github.com/klutometis/roxygen/R/rd.R and
  " https://github.com/klutometis/roxygen/R/namespace.R
  " using s/^    \([A-Za-z0-9]*\) = .*/  syn match rOTag contained "@\1"/
  " Plus we need the @include tag

  " rd.R
  syn match rOTag contained "@aliases"
  syn match rOTag contained "@author"
  syn match rOTag contained "@backref"
  syn match rOTag contained "@concept"
  syn match rOTag contained "@describeIn"
  syn match rOTag contained "@description"
  syn match rOTag contained "@details"
  syn match rOTag contained "@docType"
  syn match rOTag contained "@encoding"
  syn match rOTag contained "@evalRd"
  syn match rOTag contained "@example"
  syn match rOTag contained "@examples"
  syn match rOTag contained "@family"
  syn match rOTag contained "@field"
  syn match rOTag contained "@format"
  syn match rOTag contained "@inherit"
  syn match rOTag contained "@inheritParams"
  syn match rOTag contained "@inheritDotParams"
  syn match rOTag contained "@inheritSection"
  syn match rOTag contained "@keywords"
  syn match rOTag contained "@method"
  syn match rOTag contained "@name"
  syn match rOTag contained "@md"
  syn match rOTag contained "@noMd"
  syn match rOTag contained "@noRd"
  syn match rOTag contained "@note"
  syn match rOTag contained "@param"
  syn match rOTag contained "@rdname"
  syn match rOTag contained "@rawRd"
  syn match rOTag contained "@references"
  syn match rOTag contained "@return"
  syn match rOTag contained "@section"
  syn match rOTag contained "@seealso"
  syn match rOTag contained "@slot"
  syn match rOTag contained "@source"
  syn match rOTag contained "@template"
  syn match rOTag contained "@templateVar"
  syn match rOTag contained "@title"
  syn match rOTag contained "@usage"
  " namespace.R
  syn match rOTag contained "@export"
  syn match rOTag contained "@exportClass"
  syn match rOTag contained "@exportMethod"
  syn match rOTag contained "@exportPattern"
  syn match rOTag contained "@import"
  syn match rOTag contained "@importClassesFrom"
  syn match rOTag contained "@importFrom"
  syn match rOTag contained "@importMethodsFrom"
  syn match rOTag contained "@rawNamespace"
  syn match rOTag contained "@S3method"
  syn match rOTag contained "@useDynLib"
  " other
  syn match rOTag contained "@eval"
  syn match rOTag contained "@include"
  syn match rOTag contained "@includeRmd"
  syn match rOTag contained "@order"
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

" Raw string
syn region rRawString matchgroup=rRawStrDelim start=/[rR]\z(['"]\)\z(-*\)(/ end=/)\z2\z1/ keepend
syn region rRawString matchgroup=rRawStrDelim start=/[rR]\z(['"]\)\z(-*\){/ end=/}\z2\z1/ keepend
syn region rRawString matchgroup=rRawStrDelim start=/[rR]\z(['"]\)\z(-*\)\[/ end=/\]\z2\z1/ keepend

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
  syn region rSection matchgroup=Title start=/^#.*[-=#]\{4,}/ end=/^#.*[-=#]\{4,}/ms=s-2,me=s-1 transparent contains=ALL fold
else
  syn region rRegion matchgroup=Delimiter start=/(/ matchgroup=Delimiter end=/)/ transparent contains=ALLBUT,rError,rBraceError,rCurlyError
  syn region rRegion matchgroup=Delimiter start=/{/ matchgroup=Delimiter end=/}/ transparent contains=ALLBUT,rError,rBraceError,rParenError
  syn region rRegion matchgroup=Delimiter start=/\[/ matchgroup=Delimiter end=/]/ transparent contains=ALLBUT,rError,rCurlyError,rParenError
endif

syn match rError      "[)\]}]"
syn match rBraceError "[)}]" contained
syn match rCurlyError "[)\]]" contained
syn match rParenError "[\]}]" contained

" Use Nvim-R to highlight functions dynamically if it is installed
if !exists("g:r_syntax_fun_pattern")
  let s:ff = split(substitute(globpath(&rtp, "R/functions.vim"), "functions.vim", "", "g"), "\n")
  if len(s:ff) > 0
    let g:r_syntax_fun_pattern = 0
  else
    let g:r_syntax_fun_pattern = 1
  endif
endif

" Only use Nvim-R to highlight functions if they should not be highlighted
" according to a generic pattern
if g:r_syntax_fun_pattern == 1
  syn match rFunction '[0-9a-zA-Z_\.]\+\s*\ze('
else
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
  syn region rNameWSpace start="`" end="`" contains=rSpaceFun
endif

if &filetype == "rhelp"
  syn match rhPreProc "^#ifdef.*"
  syn match rhPreProc "^#endif.*"
  syn match rhSection "\\dontrun\>"
endif

if exists("r_syntax_minlines")
  exe "syn sync minlines=" . r_syntax_minlines
else
  syn sync minlines=40
endif

" Define the default highlighting.
hi def link rAssign      Statement
hi def link rBoolean     Boolean
hi def link rBraceError  Error
hi def link rComment     Comment
hi def link rTodoParen   Comment
hi def link rTodoInfo    SpecialComment
hi def link rCommentTodo Todo
hi def link rTodoKeyw    Todo
hi def link rComplex     Number
hi def link rConditional Conditional
hi def link rConstant    Constant
hi def link rCurlyError  Error
hi def link rDelimiter   Delimiter
hi def link rDollar      SpecialChar
hi def link rError       Error
hi def link rFloat       Float
hi def link rFunction    Function
hi def link rSpaceFun    Function
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
hi def link rRawString   String
hi def link rRawStrDelim Delimiter
hi def link rRepeat      Repeat
hi def link rSpecial     SpecialChar
hi def link rStatement   Statement
hi def link rString      String
hi def link rStrError    Error
hi def link rType        Type
if g:r_syntax_hl_roxygen
  hi def link rOTitleTag   Operator
  hi def link rOTag        Operator
  hi def link rOTitleBlock Title
  hi def link rOBlock         Comment
  hi def link rOBlockNoTitle  Comment
  hi def link rOR6Block         Comment
  hi def link rOTitle      Title
  hi def link rOCommentKey Comment
  hi def link rOExamples   SpecialComment
endif

let b:current_syntax="r"

" vim: ts=8 sw=2
