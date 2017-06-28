" Vim syntax file
" Language:             Scala
" Maintainer:           Derek Wyatt
" URL:                  https://github.com/derekwyatt/vim-scala
" License:              Same as Vim
" Last Change:          20 May 2016
" ----------------------------------------------------------------------------

if !exists('main_syntax')
  " quit when a syntax file was already loaded
  if exists("b:current_syntax")
    finish
  endif
  let main_syntax = 'scala'
endif

scriptencoding utf-8

let b:current_syntax = "scala"

" Allows for embedding, see #59; main_syntax convention instead? Refactor TOP
"
" The @Spell here is a weird hack, it means *exclude* if the first group is
" TOP. Otherwise we get spelling errors highlighted on code elements that
" match scalaBlock, even with `syn spell notoplevel`.
function! s:ContainedGroup()
  try
    silent syn list @scala
    return '@scala,@NoSpell'
  catch /E392/
    return 'TOP,@Spell'
  endtry
endfunction

unlet! b:current_syntax

syn case match
syn sync minlines=200 maxlines=1000

syn keyword scalaKeyword catch do else final finally for forSome if
syn keyword scalaKeyword match return throw try while yield macro
syn keyword scalaKeyword class trait object extends with nextgroup=scalaInstanceDeclaration skipwhite
syn keyword scalaKeyword case nextgroup=scalaKeyword,scalaCaseFollowing skipwhite
syn keyword scalaKeyword val nextgroup=scalaNameDefinition,scalaQuasiQuotes skipwhite
syn keyword scalaKeyword def var nextgroup=scalaNameDefinition skipwhite
hi link scalaKeyword Keyword

exe 'syn region scalaBlock start=/{/ end=/}/ contains=' . s:ContainedGroup() . ' fold'

syn keyword scalaAkkaSpecialWord when goto using startWith initialize onTransition stay become unbecome
hi link scalaAkkaSpecialWord PreProc

syn keyword scalatestSpecialWord shouldBe
syn match scalatestShouldDSLA /^\s\+\zsit should/
syn match scalatestShouldDSLB /\<should\>/
hi link scalatestSpecialWord PreProc
hi link scalatestShouldDSLA PreProc
hi link scalatestShouldDSLB PreProc

syn match scalaSymbol /'[_A-Za-z0-9$]\+/
hi link scalaSymbol Number

syn match scalaChar /'.'/
syn match scalaChar /'\\[\\"'ntbrf]'/ contains=scalaEscapedChar
syn match scalaChar /'\\u[A-Fa-f0-9]\{4}'/ contains=scalaUnicodeChar
syn match scalaEscapedChar /\\[\\"'ntbrf]/
syn match scalaUnicodeChar /\\u[A-Fa-f0-9]\{4}/
hi link scalaChar Character
hi link scalaEscapedChar Function
hi link scalaUnicodeChar Special

syn match scalaOperator "||"
syn match scalaOperator "&&"
hi link scalaOperator Special

syn match scalaNameDefinition /\<[_A-Za-z0-9$]\+\>/ contained nextgroup=scalaPostNameDefinition,scalaVariableDeclarationList
syn match scalaNameDefinition /`[^`]\+`/ contained nextgroup=scalaPostNameDefinition
syn match scalaVariableDeclarationList /\s*,\s*/ contained nextgroup=scalaNameDefinition
syn match scalaPostNameDefinition /\_s*:\_s*/ contained nextgroup=scalaTypeDeclaration
hi link scalaNameDefinition Function

syn match scalaInstanceDeclaration /\<[_\.A-Za-z0-9$]\+\>/ contained nextgroup=scalaInstanceHash
syn match scalaInstanceDeclaration /`[^`]\+`/ contained
syn match scalaInstanceHash /#/ contained nextgroup=scalaInstanceDeclaration
hi link scalaInstanceDeclaration Special
hi link scalaInstanceHash Type

syn match scalaUnimplemented /???/
hi link scalaUnimplemented ERROR

syn match scalaCapitalWord /\<[A-Z][A-Za-z0-9$]*\>/
hi link scalaCapitalWord Special

" Handle type declarations specially
syn region scalaTypeStatement matchgroup=Keyword start=/\<type\_s\+\ze/ end=/$/ contains=scalaTypeTypeDeclaration,scalaSquareBrackets,scalaTypeTypeEquals,scalaTypeStatement

" Ugh... duplication of all the scalaType* stuff to handle special highlighting
" of `type X =` declarations
syn match scalaTypeTypeDeclaration /(/ contained nextgroup=scalaTypeTypeExtension,scalaTypeTypeEquals contains=scalaRoundBrackets skipwhite
syn match scalaTypeTypeDeclaration /\%(⇒\|=>\)\ze/ contained nextgroup=scalaTypeTypeDeclaration contains=scalaTypeTypeExtension skipwhite
syn match scalaTypeTypeDeclaration /\<[_\.A-Za-z0-9$]\+\>/ contained nextgroup=scalaTypeTypeExtension,scalaTypeTypeEquals skipwhite
syn match scalaTypeTypeEquals /=\ze[^>]/ contained nextgroup=scalaTypeTypePostDeclaration skipwhite
syn match scalaTypeTypeExtension /)\?\_s*\zs\%(⇒\|=>\|<:\|:>\|=:=\|::\|#\)/ contained nextgroup=scalaTypeTypeDeclaration skipwhite
syn match scalaTypeTypePostDeclaration /\<[_\.A-Za-z0-9$]\+\>/ contained nextgroup=scalaTypeTypePostExtension skipwhite
syn match scalaTypeTypePostExtension /\%(⇒\|=>\|<:\|:>\|=:=\|::\)/ contained nextgroup=scalaTypeTypePostDeclaration skipwhite
hi link scalaTypeTypeDeclaration Type
hi link scalaTypeTypeExtension Keyword
hi link scalaTypeTypePostDeclaration Special
hi link scalaTypeTypePostExtension Keyword

syn match scalaTypeDeclaration /(/ contained nextgroup=scalaTypeExtension contains=scalaRoundBrackets skipwhite
syn match scalaTypeDeclaration /\%(⇒\|=>\)\ze/ contained nextgroup=scalaTypeDeclaration contains=scalaTypeExtension skipwhite
syn match scalaTypeDeclaration /\<[_\.A-Za-z0-9$]\+\>/ contained nextgroup=scalaTypeExtension skipwhite
syn match scalaTypeExtension /)\?\_s*\zs\%(⇒\|=>\|<:\|:>\|=:=\|::\|#\)/ contained nextgroup=scalaTypeDeclaration skipwhite
hi link scalaTypeDeclaration Type
hi link scalaTypeExtension Keyword
hi link scalaTypePostExtension Keyword

syn match scalaTypeAnnotation /\%([_a-zA-Z0-9$\s]:\_s*\)\ze[_=(\.A-Za-z0-9$]\+/ skipwhite nextgroup=scalaTypeDeclaration contains=scalaRoundBrackets
syn match scalaTypeAnnotation /)\_s*:\_s*\ze[_=(\.A-Za-z0-9$]\+/ skipwhite nextgroup=scalaTypeDeclaration
hi link scalaTypeAnnotation Normal

syn match scalaCaseFollowing /\<[_\.A-Za-z0-9$]\+\>/ contained
syn match scalaCaseFollowing /`[^`]\+`/ contained
hi link scalaCaseFollowing Special

syn keyword scalaKeywordModifier abstract override final lazy implicit implicitly private protected sealed null require super
hi link scalaKeywordModifier Function

syn keyword scalaSpecial this true false ne eq
syn keyword scalaSpecial new nextgroup=scalaInstanceDeclaration skipwhite
syn match scalaSpecial "\%(=>\|⇒\|<-\|←\|->\|→\)"
syn match scalaSpecial /`[^`]\+`/  " Backtick literals
hi link scalaSpecial PreProc

syn keyword scalaExternal package import
hi link scalaExternal Include

syn match scalaStringEmbeddedQuote /\\"/ contained
syn region scalaString start=/"/ end=/"/ contains=scalaStringEmbeddedQuote,scalaEscapedChar,scalaUnicodeChar
hi link scalaString String
hi link scalaStringEmbeddedQuote String

syn region scalaIString matchgroup=scalaInterpolationBrackets start=/\<[a-zA-Z][a-zA-Z0-9_]*"/ skip=/\\"/ end=/"/ contains=scalaInterpolation,scalaInterpolationB,scalaEscapedChar,scalaUnicodeChar
syn region scalaTripleIString matchgroup=scalaInterpolationBrackets start=/\<[a-zA-Z][a-zA-Z0-9_]*"""/ end=/"""\%([^"]\|$\)/ contains=scalaInterpolation,scalaInterpolationB,scalaEscapedChar,scalaUnicodeChar
hi link scalaIString String
hi link scalaTripleIString String

syn match scalaInterpolation /\$[a-zA-Z0-9_$]\+/ contained
exe 'syn region scalaInterpolationB matchgroup=scalaInterpolationBoundary start=/\${/ end=/}/ contained contains=' . s:ContainedGroup()
hi link scalaInterpolation Function
hi link scalaInterpolationB Normal

syn region scalaFString matchgroup=scalaInterpolationBrackets start=/f"/ skip=/\\"/ end=/"/ contains=scalaFInterpolation,scalaFInterpolationB,scalaEscapedChar,scalaUnicodeChar
syn match scalaFInterpolation /\$[a-zA-Z0-9_$]\+\(%[-A-Za-z0-9\.]\+\)\?/ contained
exe 'syn region scalaFInterpolationB matchgroup=scalaInterpolationBoundary start=/${/ end=/}\(%[-A-Za-z0-9\.]\+\)\?/ contained contains=' . s:ContainedGroup()
hi link scalaFString String
hi link scalaFInterpolation Function
hi link scalaFInterpolationB Normal

syn region scalaTripleString start=/"""/ end=/"""\%([^"]\|$\)/ contains=scalaEscapedChar,scalaUnicodeChar
syn region scalaTripleFString matchgroup=scalaInterpolationBrackets start=/f"""/ end=/"""\%([^"]\|$\)/ contains=scalaFInterpolation,scalaFInterpolationB,scalaEscapedChar,scalaUnicodeChar
hi link scalaTripleString String
hi link scalaTripleFString String

hi link scalaInterpolationBrackets Special
hi link scalaInterpolationBoundary Function

syn match scalaNumber /\<0[dDfFlL]\?\>/ " Just a bare 0
syn match scalaNumber /\<[1-9]\d*[dDfFlL]\?\>/  " A multi-digit number - octal numbers with leading 0's are deprecated in Scala
syn match scalaNumber /\<0[xX][0-9a-fA-F]\+[dDfFlL]\?\>/ " Hex number
syn match scalaNumber /\%(\<\d\+\.\d*\|\.\d\+\)\%([eE][-+]\=\d\+\)\=[fFdD]\=/ " exponential notation 1
syn match scalaNumber /\<\d\+[eE][-+]\=\d\+[fFdD]\=\>/ " exponential notation 2
syn match scalaNumber /\<\d\+\%([eE][-+]\=\d\+\)\=[fFdD]\>/ " exponential notation 3
hi link scalaNumber Number

syn region scalaRoundBrackets start="(" end=")" skipwhite contained contains=scalaTypeDeclaration,scalaSquareBrackets,scalaRoundBrackets

syn region scalaSquareBrackets matchgroup=scalaSquareBracketsBrackets start="\[" end="\]" skipwhite nextgroup=scalaTypeExtension contains=scalaTypeDeclaration,scalaSquareBrackets,scalaTypeOperator,scalaTypeAnnotationParameter
syn match scalaTypeOperator /[-+=:<>]\+/ contained
syn match scalaTypeAnnotationParameter /@\<[`_A-Za-z0-9$]\+\>/ contained
hi link scalaSquareBracketsBrackets Type
hi link scalaTypeOperator Keyword
hi link scalaTypeAnnotationParameter Function

syn match scalaShebang "\%^#!.*" display
syn region scalaMultilineComment start="/\*" end="\*/" contains=scalaMultilineComment,scalaDocLinks,scalaParameterAnnotation,scalaCommentAnnotation,scalaTodo,scalaCommentCodeBlock,@Spell keepend fold
syn match scalaCommentAnnotation "@[_A-Za-z0-9$]\+" contained
syn match scalaParameterAnnotation "\%(@tparam\|@param\|@see\)" nextgroup=scalaParamAnnotationValue skipwhite contained
syn match scalaParamAnnotationValue /[.`_A-Za-z0-9$]\+/ contained
syn region scalaDocLinks start="\[\[" end="\]\]" contained
syn region scalaCommentCodeBlock matchgroup=Keyword start="{{{" end="}}}" contained
syn match scalaTodo "\vTODO|FIXME|XXX" contained
hi link scalaShebang Comment
hi link scalaMultilineComment Comment
hi link scalaDocLinks Function
hi link scalaParameterAnnotation Function
hi link scalaParamAnnotationValue Keyword
hi link scalaCommentAnnotation Function
hi link scalaCommentCodeBlockBrackets String
hi link scalaCommentCodeBlock String
hi link scalaTodo Todo

syn match scalaAnnotation /@\<[`_A-Za-z0-9$]\+\>/
hi link scalaAnnotation PreProc

syn match scalaTrailingComment "//.*$" contains=scalaTodo,@Spell
hi link scalaTrailingComment Comment

syn match scalaAkkaFSM /goto([^)]*)\_s\+\<using\>/ contains=scalaAkkaFSMGotoUsing
syn match scalaAkkaFSM /stay\_s\+using/
syn match scalaAkkaFSM /^\s*stay\s*$/
syn match scalaAkkaFSM /when\ze([^)]*)/
syn match scalaAkkaFSM /startWith\ze([^)]*)/
syn match scalaAkkaFSM /initialize\ze()/
syn match scalaAkkaFSM /onTransition/
syn match scalaAkkaFSM /onTermination/
syn match scalaAkkaFSM /whenUnhandled/
syn match scalaAkkaFSMGotoUsing /\<using\>/
syn match scalaAkkaFSMGotoUsing /\<goto\>/
hi link scalaAkkaFSM PreProc
hi link scalaAkkaFSMGotoUsing PreProc

let b:current_syntax = 'scala'

if main_syntax ==# 'scala'
  unlet main_syntax
endif

" vim:set sw=2 sts=2 ts=8 et:
