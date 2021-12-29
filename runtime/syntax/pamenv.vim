" Vim syntax file
" Language:             pam_env.conf(5) configuration file
" Latest Revision:      2020-05-10

if exists("b:current_syntax")
  finish
endif

syn keyword     pamenvTodo              contained TODO FIXME XXX NOTE
syn region      pamenvComment           start='^#' end='$' display oneline contains=pamenvTodo,@Spells

syn match       pamenvVars              '^[A-Z_][A-Z_0-9]*' nextgroup=pamenvKeywords skipwhite

syn keyword     pamenvKeywords          contained DEFAULT OVERRIDE nextgroup=pamenvVarEq

syn match       pamenvVarEq             contained '=' nextgroup=pamenvValue,pamenvValueWithQuote

syn match       pamenvValue             contained '[^ \t]*' skipwhite nextgroup=pamenvKeywords
syn region      pamenvValueWithQuote    contained start='"' end='"' skipwhite nextgroup=pamenvKeywords

hi def link     pamenvTodo              Todo
hi def link     pamenvComment           Comment
hi def link     pamenvKeywords          Keyword
hi def link     pamenvVars              Identifier
hi def link     pamenvValue             String
hi def link     pamenvValueWithQuote    String

let b:current_syntax = "pamenv"
