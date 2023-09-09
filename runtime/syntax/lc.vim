" Vim syntax file
" Language:     Elsa
" Maintainer:   Miles Glapa-Grossklag <miles@glapa-grossklag.com>
" Last Change:  2023-01-29

if exists('b:current_syntax')
  finish
endif

" Keywords
syntax keyword elsaKeyword let eval
syntax match elsaKeyword "\v:"
highlight link elsaKeyword Keyword

" Comments
setlocal commentstring=--%s
syntax match elsaComment "\v--.*$"
highlight link elsaComment Comment

" Operators
syntax match elsaOperator "\v\="
syntax match elsaOperator "\v\=[abd*~]\>"
syntax match elsaOperator "\v-\>"
syntax match elsaOperator "\v\\"
highlight link elsaOperator Operator

" Definitions
syntax match elsaConstant "\v[A-Z]+[A-Z_0-9]*"
highlight link elsaConstant Constant

let b:current_syntax = 'elsa'
