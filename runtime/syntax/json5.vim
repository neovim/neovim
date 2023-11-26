" Vim syntax file
" Language:     JSON5
" Maintainer:   Mazunki Hoksaas rolferen@gmail.com
" Previous Maintainer: Guten Ye <ywzhaifei@gmail.com>
" Last Change:  2019 Apr 1
" Version:      vim9.0-1
" URL:          https://github.com/json5/json5

" Syntax setup
if exists('b:current_syntax') && b:current_syntax == 'json5'
  finish
endif

" Numbers
syn match   json5Number    "[-+]\=\%(0\|[1-9]\d*\)\%(\.\d*\)\=\%([eE][-+]\=\d\+\)\="
syn match   json5Number    "[-+]\=\%(\.\d\+\)\%([eE][-+]\=\d\+\)\="
syn match   json5Number    "[-+]\=0[xX]\x*"
syn match   json5Number    "[-+]\=Infinity\|NaN"

" An integer part of 0 followed by other digits is not allowed
syn match   json5NumError  "[-+]\=0\d\(\d\|\.\)*"

" A hexadecimal number cannot have a fractional part
syn match   json5NumError  "[-+]\=0x\x*\.\x*"

" Strings
syn region  json5String    start=+"+  skip=+\\\\\|\\"+  end=+"+  contains=json5Escape,@Spell
syn region  json5String    start=+'+  skip=+\\\\\|\\'+  end=+'+  contains=json5Escape,@Spell

" Escape sequences
syn match   json5Escape    "\\['\"\\bfnrtv]" contained
syn match   json5Escape    "\\u\x\{4}" contained

" Boolean
syn keyword json5Boolean   true false

" Null
syn keyword json5Null      null

" Delimiters and Operators
syn match   json5Delimiter  ","
syn match   json5Operator   ":"

" Braces
syn match   json5Braces	   "[{}\[\]]"

" Keys
syn match   json5Key /@\?\%(\I\|\$\)\%(\i\|\$\)*\s*\ze::\@!/ contains=@Spell
syn match   json5Key /"\([^"]\|\\"\)\{-}"\ze\s*:/ contains=json5Escape,@Spell

" Comment
syn region  json5LineComment    start=+\/\/+ end=+$+ keepend contains=@Spell
syn region  json5LineComment    start=+^\s*\/\/+ skip=+\n\s*\/\/+ end=+$+ keepend fold contains=@Spell
syn region  json5Comment        start="/\*"  end="\*/" fold contains=@Spell

" Define the default highlighting
hi def link json5String             String
hi def link json5Key                Identifier
hi def link json5Escape             Special
hi def link json5Number             Number
hi def link json5Delimiter          Delimiter
hi def link json5Operator           Operator
hi def link json5Braces             Delimiter
hi def link json5Null               Keyword
hi def link json5Boolean            Boolean
hi def link json5LineComment        Comment
hi def link json5Comment            Comment
hi def link json5NumError           Error

if !exists('b:current_syntax')
  let b:current_syntax = 'json5'
endif

