" Vim syntax file
" Language: Elm
" Maintainer: Andreas Scharf <as@99n.de>
" Original Author: Joseph Hager <ajhager@gmail.com>
" Copyright: Joseph Hager <ajhager@gmail.com>
" License: BSD3
" Latest Revision: 2020-05-29

if exists('b:current_syntax')
  finish
endif

" Keywords
syn keyword elmConditional else if of then case
syn keyword elmAlias alias
syn keyword elmTypedef contained type port
syn keyword elmImport exposing as import module where

" Operators
" elm/core
syn match elmOperator contained "\(<|\||>\|||\|&&\|==\|/=\|<=\|>=\|++\|::\|+\|-\|*\|/\|//\|^\|<>\|>>\|<<\|<\|>\|%\)"
" elm/parser
syn match elmOperator contained "\(|.\||=\)"
" elm/url
syn match elmOperator contained "\(</>\|<?>\)"

" Types
syn match elmType "\<[A-Z][0-9A-Za-z_-]*"
syn keyword elmNumberType number

" Modules
syn match elmModule "\<\([A-Z][0-9A-Za-z_'-\.]*\)\+\.[A-Za-z]"me=e-2
syn match elmModule "^\(module\|import\)\s\+[A-Z][0-9A-Za-z_'-\.]*\(\s\+as\s\+[A-Z][0-9A-Za-z_'-\.]*\)\?\(\s\+exposing\)\?" contains=elmImport

" Delimiters
syn match elmDelimiter  "[,;]"
syn match elmBraces  "[()[\]{}]"

" Functions
syn match elmTupleFunction "\((,\+)\)"

" Comments
syn keyword elmTodo TODO FIXME XXX contained
syn match elmLineComment "--.*" contains=elmTodo,@spell
syn region elmComment matchgroup=elmComment start="{-|\=" end="-}" contains=elmTodo,elmComment,@spell fold

" Strings
syn match elmStringEscape "\\u[0-9a-fA-F]\{4}" contained
syn match elmStringEscape "\\[nrfvbt\\\"]" contained
syn region elmString start="\"" skip="\\\"" end="\"" contains=elmStringEscape,@spell
syn region elmTripleString start="\"\"\"" skip="\\\"" end="\"\"\"" contains=elmStringEscape,@spell
syn match elmChar "'[^'\\]'\|'\\.'\|'\\u[0-9a-fA-F]\{4}'"

" Lambda
syn region elmLambdaFunc start="\\"hs=s+1 end="->"he=e-2

" Debug
syn match elmDebug "Debug.\(log\|todo\|toString\)"

" Numbers
syn match elmInt "-\?\<\d\+\>"
syn match elmFloat "-\?\(\<\d\+\.\d\+\>\)"

" Identifiers
syn match elmTopLevelDecl "^\s*[a-zA-Z][a-zA-z0-9_]*\('\)*\s\+:\(\r\n\|\r\|\n\|\s\)\+" contains=elmOperator
syn match elmFuncName /^\l\w*/

" Folding
syn region elmTopLevelTypedef start="type" end="\n\(\n\n\)\@=" contains=ALL fold
syn region elmTopLevelFunction start="^[a-zA-Z].\+\n[a-zA-Z].\+=" end="^\(\n\+\)\@=" contains=ALL fold
syn region elmCaseBlock matchgroup=elmCaseBlockDefinition start="^\z\(\s\+\)\<case\>" end="^\z1\@!\W\@=" end="\(\n\n\z1\@!\)\@=" end="\n\z1\@!\(\n\n\)\@=" contains=ALL fold
syn region elmCaseItemBlock start="^\z\(\s\+\).\+->$" end="^\z1\@!\W\@=" end="\(\n\n\z1\@!\)\@=" end="\(\n\z1\S\)\@=" contains=ALL fold
syn region elmLetBlock matchgroup=elmLetBlockDefinition start="\<let\>" end="\<in\>" contains=ALL fold

hi def link elmFuncName Function
hi def link elmCaseBlockDefinition Conditional
hi def link elmCaseBlockItemDefinition Conditional
hi def link elmLetBlockDefinition TypeDef
hi def link elmTopLevelDecl Function
hi def link elmTupleFunction Normal
hi def link elmTodo Todo
hi def link elmComment Comment
hi def link elmLineComment Comment
hi def link elmString String
hi def link elmTripleString String
hi def link elmChar String
hi def link elmStringEscape Special
hi def link elmInt Number
hi def link elmFloat Float
hi def link elmDelimiter Delimiter
hi def link elmBraces Delimiter
hi def link elmTypedef TypeDef
hi def link elmImport Include
hi def link elmConditional Conditional
hi def link elmAlias Delimiter
hi def link elmOperator Operator
hi def link elmType Type
hi def link elmNumberType Identifier
hi def link elmLambdaFunc Function
hi def link elmDebug Debug
hi def link elmModule Type

syn sync minlines=500

let b:current_syntax = 'elm'
