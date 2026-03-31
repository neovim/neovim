" Vim syntax file
" Language:     Nvim :checkhealth buffer

if exists("b:current_syntax")
  finish
endif

runtime! syntax/help.vim
unlet! b:current_syntax

syn case match

syn keyword DiagnosticError ERROR[:]
syn keyword DiagnosticWarn WARNING[:]
syn keyword DiagnosticOk OK[:]
" Note: hs=e starts higlighting on the title line (instead of the "===" line).
syn match healthSectionDelim /^======*\n.*$/hs=e
highlight default healthSectionDelim gui=reverse cterm=reverse
syn match healthHeadingChar "=" conceal cchar= contained containedin=healthSectionDelim

let b:current_syntax = "checkhealth"
