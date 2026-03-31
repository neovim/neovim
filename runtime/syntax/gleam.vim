" Vim syntax file
" Language:    Gleam
" Maintainer:  Kirill Morozov <kirill@robotix.pro>
" Based On:    https://github.com/gleam-lang/gleam.vim
" Last Change: 2025 Apr 20
" 2025 May 15 Add @Spell clusters #17324

if exists("b:current_syntax")
  finish
endif
let b:current_syntax = "gleam"

syntax case match

" Keywords
syntax keyword gleamConditional case if
syntax keyword gleamConstant const
syntax keyword gleamDebug echo
syntax keyword gleamException panic assert todo
syntax keyword gleamInclude import
syntax keyword gleamKeyword as let use
syntax keyword gleamStorageClass pub opaque
syntax keyword gleamType type

" Number
"" Int
syntax match gleamNumber "\<-\=\%(0\|\%(\d\|\d_\d\)\+\)\>"

"" Binary
syntax match gleamNumber "\<-\=0[bB]_\?\%([01]\|[01]_[01]\)\+\>"

"" Octet
syntax match gleamNumber "\<-\=0[oO]\?_\?\%(\o\|\o_\o\)\+\>"

"" Hexadecimal
syntax match gleamNumber "\<-\=0[xX]_\?\%(\x\|\x_\x\)\+\>"

"" Float
syntax match gleamFloat "\(0*[1-9][0-9_]*\|0\)\.\(0*[1-9][0-9_]*\|0\)\(e-\=0*[1-9][0-9_]*\)\="

" String
syntax region gleamString start=/"/ end=/"/ contains=gleamSpecial,@Spell
syntax match gleamSpecial '\\.' contained

" Operators
"" Basic
syntax match gleamOperator "[-+/*]\.\=\|[%=]"

"" Arrows + Pipeline
syntax match gleamOperator "<-\|[-|]>"

"" Bool
syntax match gleamOperator "&&\|||"

"" Comparison
syntax match gleamOperator "[<>]=\=\.\=\|[=!]="

"" Misc
syntax match gleamOperator "\.\.\|<>\||"

" Type
syntax match gleamIdentifier "\<[A-Z][a-zA-Z0-9]*\>" contains=@NoSpell

" Attribute
syntax match gleamPreProc "@[a-z][a-z_]*" contains=@NoSpell

" Function definition
syntax keyword gleamKeyword fn nextgroup=gleamFunction skipwhite skipempty
syntax match gleamFunction "[a-z][a-z0-9_]*\ze\s*(" skipwhite skipnl contains=@NoSpell

" Comments
syntax region gleamComment start="//" end="$" contains=gleamTodo,@Spell
syntax region gleamSpecialComment start="///" end="$" contains=@Spell
syntax region gleamSpecialComment start="////" end="$" contains=@Spell
syntax keyword gleamTodo contained TODO FIXME XXX NB NOTE

" Highlight groups
highlight link gleamComment Comment
highlight link gleamConditional Conditional
highlight link gleamConstant Constant
highlight link gleamDebug Debug
highlight link gleamException Exception
highlight link gleamFloat Float
highlight link gleamFunction Function
highlight link gleamIdentifier Identifier
highlight link gleamInclude Include
highlight link gleamKeyword Keyword
highlight link gleamNumber Number
highlight link gleamOperator Operator
highlight link gleamPreProc PreProc
highlight link gleamSpecial Special
highlight link gleamSpecialComment SpecialComment
highlight link gleamStorageClass StorageClass
highlight link gleamString String
highlight link gleamTodo Todo
highlight link gleamType Type

" vim: sw=2 sts=2 et
