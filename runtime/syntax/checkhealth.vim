" Vim syntax file
" Language:     Nvim :checkhealth buffer
" Last Change:  2022 Nov 10

if exists("b:current_syntax")
  finish
endif

runtime! syntax/help.vim
unlet! b:current_syntax

syn case match

syn keyword DiagnosticError ERROR[:]
syn keyword DiagnosticWarn WARNING[:]
syn keyword DiagnosticOk OK[:]
syn match helpSectionDelim "^======*\n.*$"
syn match healthHeadingChar "=" conceal cchar=─ contained containedin=helpSectionDelim

let b:current_syntax = "checkhealth"
