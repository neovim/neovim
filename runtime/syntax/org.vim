" Vim syntax file
" Language:	Org
" Previous Maintainer:  Luca Saccarola <github.e41mv@aleeas.com>
" Maintainer:   This runtime file is looking for a new maintainer.
" Last Change:  2025 Aug 05
"
" Reference Specification: Org mode manual
"   GNU Info: `$ info Org`
"   Web: <https://orgmode.org/manual/index.html>

" Quit when a (custom) syntax file was already loaded
if exists("b:current_syntax")
  finish
endif
let b:current_syntax = 'org'

syn case ignore

" Bold
syn region orgBold matchgroup=orgBoldDelimiter start="\(^\|[- '"({\]]\)\@<=\*\ze[^ ]" end="^\@!\*\([^\k\*]\|$\)\@=" keepend
hi def link orgBold markdownBold
hi def link orgBoldDelimiter orgBold

" Italic
syn region orgItalic matchgroup=orgItalicDelimiter start="\(^\|[- '"({\]]\)\@<=\/\ze[^ ]" end="^\@!\/\([^\k\/]\|$\)\@=" keepend
hi def link orgItalic markdownItalic
hi def link orgItalicDelimiter orgItalic

" Strikethrogh
syn region orgStrikethrough matchgroup=orgStrikethroughDelimiter start="\(^\|[ '"({\]]\)\@<=+\ze[^ ]" end="^\@!+\([^\k+]\|$\)\@=" keepend
hi def link orgStrikethrough markdownStrike
hi def link orgStrikethroughDelimiter orgStrikethrough

" Underline
syn region orgUnderline matchgroup=orgUnderlineDelimiter start="\(^\|[- '"({\]]\)\@<=_\ze[^ ]" end="^\@!_\([^\k_]\|$\)\@=" keepend

" Headlines
syn match orgHeadline "^\*\+\s\+.*$" keepend
hi def link orgHeadline Title

" Line Comment
syn match  orgLineComment /^\s*#\s\+.*$/ keepend
hi def link orgLineComment Comment

" Block Comment
syn region orgBlockComment matchgroup=orgBlockCommentDelimiter start="\c^\s*#+BEGIN_COMMENT" end="\c^\s*#+END_COMMENT" keepend
hi def link orgBlockComment Comment
hi def link orgBlockCommentDelimiter Comment

" Lists
syn match orgUnorderedListMarker "^\s*[-+]\s\+" keepend
hi def link orgUnorderedListMarker markdownOrderedListMarker
syn match orgOrderedListMarker "^\s*\(\d\|\a\)\+[.)]\s\+" keepend
hi def link orgOrderedListMarker markdownOrderedListMarker
"
" Verbatim
syn region orgVerbatimInline matchgroup=orgVerbatimInlineDelimiter start="\(^\|[- '"({\]]\)\@<==\ze[^ ]" end="^\@!=\([^\k=]\|$\)\@=" keepend
hi def link orgVerbatimInline markdownCodeBlock
hi def link orgVerbatimInlineDelimiter orgVerbatimInline
syn region orgVerbatimBlock matchgroup=orgVerbatimBlockDelimiter start="\c^\s*#+BEGIN_.*" end="\c^\s*#+END_.*" keepend
hi def link orgVerbatimBlock orgCode
hi def link orgVerbatimBlockDelimiter orgVerbatimBlock

" Code
syn region orgCodeInline matchgroup=orgCodeInlineDelimiter start="\(^\|[- '"({\]]\)\@<=\~\ze[^ ]" end="^\@!\~\([^\k\~]\|$\)\@=" keepend
highlight def link orgCodeInline markdownCodeBlock
highlight def link orgCodeInlineDelimiter orgCodeInline
syn region orgCodeBlock matchgroup=orgCodeBlockDelimiter start="\c^\s*#+BEGIN_SRC.*" end="\c^\s*#+END_SRC" keepend
highlight def link orgCodeBlock markdownCodeBlock
highlight def link orgCodeBlockDelimiter orgCodeBlock

" vim: ts=8 sts=2 sw=2 et
