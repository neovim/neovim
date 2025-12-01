" Vim syntax file
" Language:     Leex (Erlang Lexical Analyzer Generator)
" Maintainer:   Jon Parise <jon@indelible.org>
" Last Change:  2025 Nov 30
" Filenames:    *.xrl
"
" References:
" - https://www.erlang.org/doc/apps/parsetools/leex.html

if exists('b:current_syntax')
  finish
endif

syn include @leexErlang syntax/erlang.vim
unlet! b:current_syntax

syn match leexComment "%.*$" contains=@Spell display

syn match leexRegexOperator "[|*+?]" contained display
syn match leexRegexDelimiter "[()[\]]" contained display
syn match leexRegexSpecial "[.^$\\]" contained display
syn match leexRegexEscape '\\\%([bfnrtevsd]\|\o\{1,3}\|x\x\{2}\|x{\x\+}\|.\)' contained display
syn match leexRegexRange "\[[^\]]*\]" contains=leexRegexDelimiter,leexRegexEscape contained display

" Macro definitions: NAME = VALUE
syn match leexMacroName "^\s*\zs\h\w*\ze\s\+=\s\+" contained nextgroup=leexMacroEquals skipwhite display
syn match leexMacroEquals "=" contained nextgroup=leexMacroValue skipwhite display
syn match leexMacroValue "\S\+" contained contains=leexRegexOperator,leexRegexDelimiter,leexRegexSpecial,leexRegexEscape,leexRegexRange,leexMacroRef display
syn match leexMacroRef "{\h\w*}" contained display

" Rule definitions: <Regexp> : <Erlang code>.
syn match leexRuleRegex "^\s*\zs[^%].\{-}\ze\s\+:" contained contains=leexRegexOperator,leexRegexDelimiter,leexRegexSpecial,leexRegexEscape,leexRegexRange,leexMacroRef nextgroup=leexRuleColon skipwhite display
syn match leexRuleColon ":" contained nextgroup=leexRuleCode skipwhite skipnl display
syn region leexRuleCode start="" end="\.\s*\%(%.*\)\?$" skip="^\s*%.*$" contained contains=@leexErlang keepend skipnl skipwhite

" Sections
syn match leexHeading "^\%(Definitions\|Rules\|Erlang code\)\.$" contained display
syn region leexDefinitions start="^Definitions\.$" end="^[A-Z][A-Za-z ]*\.$"me=s-1 end="\%$" keepend fold
  \ contains=leexHeading,leexComment,leexMacroName
syn region leexRules start="^Rules\.$" end="^[A-Z][A-Za-z ]*\.$"me=s-1 end="\%$" keepend fold
  \ contains=leexHeading,leexComment,leexRuleRegex
syn region leexErlangCode start="^Erlang code\.$" end="^[A-Z][A-Za-z ]*\.$"me=s-1 end="\%$" keepend fold
  \ contains=leexHeading,@leexErlang

hi def link leexComment Comment
hi def link leexHeading PreProc

hi def link leexRegexOperator Operator
hi def link leexRegexDelimiter Delimiter
hi def link leexRegexSpecial Special
hi def link leexRegexRange String
hi def link leexRegexEscape SpecialChar

hi def link leexMacroName Identifier
hi def link leexMacroEquals Operator
hi def link leexMacroValue String
hi def link leexMacroRef Macro

hi def link leexRuleColon Operator

syn sync fromstart

let b:current_syntax = 'leex'
