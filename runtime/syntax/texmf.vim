" Vim syntax file
" This is a GENERATED FILE. Please always refer to source file at the URI below.
" Language: Web2C TeX texmf.cnf configuration file
" Maintainer: David Ne\v{c}as (Yeti) <yeti@physics.muni.cz>
" Last Change: 2001-05-13
" URL: http://physics.muni.cz/~yeti/download/syntax/texmf.vim

" Setup
" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn case match

" Comments
syn match texmfComment "%..\+$" contains=texmfTodo
syn match texmfComment "%\s*$" contains=texmfTodo
syn keyword texmfTodo TODO FIXME XXX NOT contained

" Constants and parameters
syn match texmfPassedParameter "[-+]\=%\w\W"
syn match texmfPassedParameter "[-+]\=%\w$"
syn match texmfNumber "\<\d\+\>"
syn match texmfVariable "\$\(\w\k*\|{\w\k*}\)"
syn match texmfSpecial +\\"\|\\$+
syn region texmfString start=+"+ end=+"+ skip=+\\"\\\\+ contains=texmfVariable,texmfSpecial,texmfPassedParameter

" Assignments
syn match texmfLHSStart "^\s*\w\k*" nextgroup=texmfLHSDot,texmfEquals
syn match texmfLHSVariable "\w\k*" contained nextgroup=texmfLHSDot,texmfEquals
syn match texmfLHSDot "\." contained nextgroup=texmfLHSVariable
syn match texmfEquals "\s*=" contained

" Specialities
syn match texmfComma "," contained
syn match texmfColons ":\|;"
syn match texmfDoubleExclam "!!" contained

" Catch errors caused by wrong parenthesization
syn region texmfBrace matchgroup=texmfBraceBrace start="{" end="}" contains=ALLBUT,texmfTodo,texmfBraceError,texmfLHSVariable,texmfLHSDot transparent
syn match texmfBraceError "}"

" Define the default highlighting
command -nargs=+ HiLink hi def link <args>

HiLink texmfComment Comment
HiLink texmfTodo Todo

HiLink texmfPassedParameter texmfVariable
HiLink texmfVariable Identifier

HiLink texmfNumber Number
HiLink texmfString String

HiLink texmfLHSStart texmfLHS
HiLink texmfLHSVariable texmfLHS
HiLink texmfLHSDot texmfLHS
HiLink texmfLHS Type

HiLink texmfEquals Normal

HiLink texmfBraceBrace texmfDelimiter
HiLink texmfComma texmfDelimiter
HiLink texmfColons texmfDelimiter
HiLink texmfDelimiter Preproc

HiLink texmfDoubleExclam Statement
HiLink texmfSpecial Special

HiLink texmfBraceError texmfError
HiLink texmfError Error

delcommand HiLink

let b:current_syntax = "texmf"
