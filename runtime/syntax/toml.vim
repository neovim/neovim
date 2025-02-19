" Vim syntax file
" Language:            TOML
" Homepage:            https://github.com/cespare/vim-toml
" Maintainer:          Aman Verma
" Previous Maintainer: Caleb Spare <cespare@gmail.com>
" Last Change:         Oct 8, 2021

if exists('b:current_syntax')
  finish
endif

syn match tomlEscape /\\[btnfr"/\\]/ display contained
syn match tomlEscape /\\u\x\{4}/ contained
syn match tomlEscape /\\U\x\{8}/ contained
syn match tomlLineEscape /\\$/ contained

" Basic strings
syn region tomlString oneline start=/"/ skip=/\\\\\|\\"/ end=/"/ contains=tomlEscape
" Multi-line basic strings
syn region tomlString start=/"""/ end=/"""/ contains=tomlEscape,tomlLineEscape
" Literal strings
syn region tomlString oneline start=/'/ end=/'/
" Multi-line literal strings
syn region tomlString start=/'''/ end=/'''/

syn match tomlInteger /[+-]\=\<[1-9]\(_\=\d\)*\>/ display
syn match tomlInteger /[+-]\=\<0\>/ display
syn match tomlInteger /[+-]\=\<0x[[:xdigit:]]\(_\=[[:xdigit:]]\)*\>/ display
syn match tomlInteger /[+-]\=\<0o[0-7]\(_\=[0-7]\)*\>/ display
syn match tomlInteger /[+-]\=\<0b[01]\(_\=[01]\)*\>/ display
syn match tomlInteger /[+-]\=\<\(inf\|nan\)\>/ display

syn match tomlFloat /[+-]\=\<\d\(_\=\d\)*\.\d\+\>/ display
syn match tomlFloat /[+-]\=\<\d\(_\=\d\)*\(\.\d\(_\=\d\)*\)\=[eE][+-]\=\d\(_\=\d\)*\>/ display

syn match tomlBoolean /\<\%(true\|false\)\>/ display

" https://tools.ietf.org/html/rfc3339
syn match tomlDate /\d\{4\}-\d\{2\}-\d\{2\}/ display
syn match tomlDate /\d\{2\}:\d\{2\}:\d\{2\}\%(\.\d\+\)\?/ display
syn match tomlDate /\d\{4\}-\d\{2\}-\d\{2\}[T ]\d\{2\}:\d\{2\}:\d\{2\}\%(\.\d\+\)\?\%(Z\|[+-]\d\{2\}:\d\{2\}\)\?/ display

syn match tomlDotInKey /\v[^.]+\zs\./ contained display
syn match tomlKey /\v(^|[{,])\s*\zs[[:alnum:]._-]+\ze\s*\=/ contains=tomlDotInKey display
syn region tomlKeyDq oneline start=/\v(^|[{,])\s*\zs"/ end=/"\ze\s*=/ contains=tomlEscape
syn region tomlKeySq oneline start=/\v(^|[{,])\s*\zs'/ end=/'\ze\s*=/

syn region tomlTable oneline start=/^\s*\[[^\[]/ end=/\]/ contains=tomlKey,tomlKeyDq,tomlKeySq,tomlDotInKey

syn region tomlTableArray oneline start=/^\s*\[\[/ end=/\]\]/ contains=tomlKey,tomlKeyDq,tomlKeySq,tomlDotInKey

syn region tomlKeyValueArray start=/=\s*\[\zs/ end=/\]/ contains=@tomlValue

syn region tomlArray start=/\[/ end=/\]/ contains=@tomlValue contained

syn cluster tomlValue contains=tomlArray,tomlString,tomlInteger,tomlFloat,tomlBoolean,tomlDate,tomlComment

syn keyword tomlTodo TODO FIXME XXX BUG contained

syn match tomlComment /#.*/ contains=@Spell,tomlTodo

hi def link tomlComment Comment
hi def link tomlTodo Todo
hi def link tomlTableArray Title
hi def link tomlTable Title
hi def link tomlDotInKey Normal
hi def link tomlKeySq Identifier
hi def link tomlKeyDq Identifier
hi def link tomlKey Identifier
hi def link tomlDate Constant
hi def link tomlBoolean Boolean
hi def link tomlFloat Float
hi def link tomlInteger Number
hi def link tomlString String
hi def link tomlLineEscape SpecialChar
hi def link tomlEscape SpecialChar

syn sync minlines=500
let b:current_syntax = 'toml'

" vim: et sw=2 sts=2
