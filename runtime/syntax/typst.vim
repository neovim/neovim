" Vim syntax file
" Maintainer:  Maxim Kim <habamax@gmail.com>
" Language:    Typst
" Last Change: 2026 Jun 30
" Based on the syntax file from https://github.com/kaarmu/typst.vim

if exists('b:current_syntax')
    finish
endif

let s:cpo_save = &cpo
set cpo&vim

syntax spell toplevel
syntax sync minlines=300
syntax iskeyword @,48-57,192-255,_,-

syntax cluster typstExpr
      \ contains=typstExprCodeBlock
      \ ,typstExprFunc
      \ ,typstExprContentBlock
      \ ,typstExprBraces
      \ ,typstExprColon
      \ ,typstExprDot
      \ ,typstExprCommand
      \ ,@typstExprConstants
      \ ,typstExprVar
      \ ,typstExprOpSym
      \ ,typstExprOp
      \ ,@typstComment

syntax match typstExprStart /#/ nextgroup=@typstExpr,typstExprBareVar
syntax match typstExprDot /\./
      \ contained
      \ nextgroup=@typstExpr

syntax match typstExprColon /:/
      \ skipwhite
      \ contained
      \ nextgroup=@typstExpr

syntax match typstExprVar /\k\+/
      \ skipwhite
      \ contained
      \ nextgroup=typstExprOp,typstExprOpSym,@typstExpr

syntax region typstExprBraces
      \ skipwhite
      \ contained
      \ contains=@typstExpr,typstMarkupMath
      \ nextgroup=typstExprOp,typstExprOpSym,@typstExpr
      \ start=/(/
      \ end=/)/

syntax match typstExprOpSym /\%(=[=>]\)\|\%([-+*/<>!=]=\)\|[<=>\-+*/]/
      \ skipwhite
      \ contained
      \ nextgroup=typstExprFunc,@typstExpr

syntax match typstExprOp /in\>\|and\>\|or\>\|\%(not\%(\s\+in\>\)\?\)/
      \ skipwhite skipempty
      \ contained
      \ nextgroup=@typstExpr

syntax match typstExprBareVar /\k\+/ skipwhite contained

syntax match typstExprCommand
      \ /let\|set\|while\|for\|if\|else\|show\|import\|include\|context\|return/
      \ skipwhite skipempty
      \ contained
      \ nextgroup=@typstExpr

syntax region typstExprCodeBlock
      \ skipwhite
      \ contained
      \ contains=@typstExpr
      \ start=/{/
      \ end=/}/

syntax region typstExprContentBlock
      \ skipwhite
      \ contained
      \ extend
      \ contains=@typstMarkup,typstExprStart,typstMarkupMath
      \ nextgroup=@typstExpr
      \ matchgroup=NONE
      \ start=/\[/
      \ end=/\]/

syntax match typstExprFunc
      \ skipwhite
      \ contained
      \ contains=typstExprDot
      \ nextgroup=typstExprBraces,typstExprContentBlock,@typstExpr
      \ /\k\+\%(\.\k\+\)*[[(]\@=/

syntax cluster typstExprConstants
      \ contains=typstExprConstant
      \ ,typstExprNumber
      \ ,typstExprString
      \ ,typstExprLabel

syntax match typstExprConstant
      \ contained
      \ /\v<%(none|auto|true|false)-@!>/

syntax region typstExprString
      \ contained
      \ start=/"/ skip=/\v\\\\|\\"/ end=/"/
      \ contains=@Spell
syntax match typstExprNumber
      \ skipwhite
      \ contained
      \ nextgroup=typstExprNumberType,typstExprOp,typstExprOpSym,@typstExpr
      \ /\v<\d+%(\.\d+)?/
syntax match typstExprNumberType
      \ contained
      \ nextgroup=typstExprOp,typstExprOpSym,@typstExpr
      \ /\v%(pt|mm|cm|in|em|deg|rad|\%|fr)>?/

syntax match typstExprLabel
      \ contained
      \ /\v\<\K%(\k*-*)*\>/

syntax region typstMarkupDollar
      \ matchgroup=typstMarkupDollar start=/\\\@1<!\$/ end=/\\\@1<!\$/
      \ contains=@typstMath


syntax cluster typstMarkup
      \ contains=typstMarkupRawInline
      \ ,typstMarkupRawBlock
      \ ,typstMarkupLabel
      \ ,typstMarkupReference
      \ ,typstMarkupUrl
      \ ,typstMarkupHeading
      \ ,typstMarkupBulletList
      \ ,typstMarkupEnumList
      \ ,typstMarkupTermList
      \ ,typstMarkupBold
      \ ,typstMarkupItalic
      \ ,typstMarkupBoldItalic
      \ ,typstMarkupBackslash
      \ ,typstMarkupLinebreak
      \ ,typstMarkupNonbreakingSpace
      \ ,@typstMarkupDollar
      \ ,typstMarkupShy
      \ ,typstMarkupDash
      \ ,typstMarkupEllipsis
      \ ,typstMarkupBackslash
      \ ,typstMarkupEscape

syntax region typstMarkupRawInline
      \ matchgroup=typstMarkupRawDelimiter
      \ start=+\%(^\|[[:space:]-:/]\)\@1<=`[^`]\@1=+
      \ skip=/\\`/
      \ end=+`+

syntax region typstMarkupRawBlock
      \ matchgroup=typstMarkupRawDelimiter
      \ start=/```\w*/
      \ end=/```/
      \ keepend
syntax region typstMarkupCodeBlockTypst
      \ matchgroup=typstMarkupRawDelimiter
      \ start=/```typst/
      \ end=/```/
      \ contains=@typstCode
      \ keepend

for s:name in get(g:, 'typst_embedded_languages', [])
    let s:include = ['syntax include'
                \   ,'@typstEmbedded_'..s:name
                \   ,'syntax/'..s:name..'.vim']
    let s:rule = ['syn region'
                \ ,"typstMarkupRawBlock_"..s:name
                \ ,'matchgroup=typstMarkupRawDelimiter'
                \ ,'start=/```'..s:name..'\>/ end=/```/' 
                \ ,'contains=@typstEmbedded_'..s:name 
                \ ,'keepend'
                \ ,'concealends']

    execute 'silent! ' .. join(s:include, ' ')
    unlet! b:current_syntax
    execute join(s:rule, ' ')
endfor

" Label & Reference
syntax match typstMarkupLabel
      \ /\v\<\K%(\k*-*)*\>/
syntax match typstMarkupReference
      \ /\v\@\K%(\k*-*)*/

syntax match typstMarkupUrl
      \ #\v\w+://\S*#

syntax region typstMarkupHeading
      \ matchgroup=typstMarkupHeadingDelimiter
      \ start=/^\s*\zs=\{1,6}\s/
      \ end=/$/ keepend oneline
      \ contains=typstMarkupLabel,@Spell

syntax match typstMarkupBulletList
      \ /\v^\s*-\s+/
syntax match typstMarkupEnumList
      \ /\v^\s*(\+|\d+\.)\s+/
syntax region typstMarkupTermList
      \ matchgroup=typstMarkupTermListDelimiter
      \ start=/\v^\s*\/\s/
      \ skip=/\\:/
      \ end=/:/
      \ oneline contains=@typstMarkup

syn region typstMarkupBold
      \ start=+\%(^\|[\[[:space:]-:/]\)\@1<=\*[^*]\@1=+
      \ skip=+\\\*+
      \ end=+\*\($\|[[:space:]-.,:;!?"'/\\>)\]}]\)\@1=+
      \ concealends contains=typstMarkupLabel,@Spell
syn region typstMarkupItalic
      \ start=+\%(^\|[\[[:space:]-:/]\)\@1<=_[^_]\@1=+
      \ skip=+\\_+
      \ end=+_\($\|[[:space:]-.,:;!?"'/\\>)\]}]\)\@1=+
      \ concealends contains=typstMarkupLabel,@Spell
syn region typstMarkupBoldItalic
      \ start=+\%(^\|[\[[:space:]-:/]\)\@1<=\*_[^*_]\@1=+
      \ skip=+\\\*_+
      \ end=+_\*\($\|[[:space:]-.,:;!?"'/\\>)\]}]\)\@1=+
      \ concealends contains=typstMarkupLabel,@Spell
syn region typstMarkupBoldItalic
      \ start=+\%(^\|[[:space:]-:/]\)\@1<=_\*[^*_]\@1=+
      \ skip=+\\_\*+
      \ end=+\*_\($\|[[:space:]-.,:;!?"'/\\>)\]}]\)\@1=+
      \ concealends contains=typstMarkupLabel,@Spell

syntax match typstMarkupBackslash /\\\\/
syntax match typstMarkupLinebreak /\\\%(\s\|$\)/
syntax match typstMarkupNonbreakingSpace /\~/
syntax match typstMarkupShy /-?/
syntax match typstMarkupDash /-\{2,3}/
syntax match typstMarkupEllipsis /\.\.\./
syntax match typstMarkupEscape /\\./

syntax region typstMarkupMath
      \ matchgroup=typstMarkupDollar start=/\\\@1<!\$/ end=/\\\@1<!\$/
      \ contains=@typstMath

" Math
syntax cluster typstMath
      \ contains=@typstHashtag
      \ ,typstMathIdentifier
      \ ,typstMathFunction
      \ ,typstMathNumber
      \ ,typstMathSymbol
      \ ,typstMathBold
      \ ,typstMathScripts
      \ ,typstMathQuote
      \ ,@typstComment

syntax match typstMathIdentifier
      \ /\a\a\+/
      \ contained
syntax match typstMathFunction
      \ /\a\a\+\ze(/
      \ contained
syntax match typstMathNumber
      \ contained
      \ /\v\d+%(\.\d+)?/
syntax region typstMathQuote
      \ matchgroup=String start=/"/ skip=/\\"/ end=/"/
      \ contained


syntax cluster typstComment
      \ contains=typstCommentBlock,typstCommentLine
syntax region typstCommentBlock
      \ start="/\*" end="\*/" keepend
      \ contains=typstCommentTodo,@Spell
syntax match typstCommentLine
      \ #//.*#
      \ contains=typstCommentTodo,@Spell
syntax keyword typstCommentTodo
      \ contained
      \ TODO FIXME XXX TBD

hi def link typstCommentBlock Comment
hi def link typstCommentLine Comment
hi def link typstCommentTodo Todo

hi def link typstMathIdentifier Identifier
hi def link typstMathFunction Statement
hi def link typstMathNumber Number
hi def link typstMathSymbol Statement

hi def link typstExprStart Special
hi def link typstExprOp Statement
hi def link typstExprBareVar Identifier
hi def link typstExprEmbeddedBareVar Identifier
hi def link typstExprFunc Function
hi def link typstExprCommand Statement
hi def link typstExprConstant Constant
hi def link typstExprNumber Number
hi def link typstExprNumberType Constant
hi def link typstExprString String
hi def link typstExprLabel Structure

hi def link typstMarkupRawInline PreProc
hi def link typstMarkupRawDelimiter Special
hi def link typstMarkupRawBlock PreProc
hi def link typstMarkupDollar Special
hi def link typstMarkupLabel PreProc
hi def link typstMarkupReference Special
hi def link typstMarkupBulletList PreProc
hi def link typstMarkupEnumList PreProc
hi def link typstMarkupLinebreak Special
hi def link typstMarkupNonbreakingSpace Special
hi def link typstMarkupShy Special
hi def link typstMarkupDash Special
hi def link typstMarkupEllipsis Special
hi def link typstMarkupTermList Bold
hi def link typstMarkupTermListDelimiter PreProc
hi def link typstMarkupHeading Title
hi def link typstMarkupHeadingDelimiter Type
hi def link typstMarkupUrl Underlined
hi def link typstMarkupBold Bold
hi def link typstMarkupItalic Italic
hi def link typstMarkupBoldItalic BoldItalic

let b:current_syntax = 'typst'

let &cpo = s:cpo_save
unlet s:cpo_save
