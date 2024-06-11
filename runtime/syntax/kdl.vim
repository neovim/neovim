" Vim syntax file
" Language: KDL
" Maintainer: Aram Drevekenin <aram@poor.dev>
" Maintainer: Yinzuo Jiang <jiangyinzuo@foxmail.com>
" Latest Revision: 2024-06-10

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn match kdlNode '\v(\w|-|\=)' display
syn match kdlBool '\v(true|false)' display

syn keyword kdlTodo contained TODO FIXME XXX NOTE
syn match kdlComment "//.*$" contains=kdlTodo

" Regular int like number with - + or nothing in front
syn match kdlNumber '\d\+'
syn match kdlNumber '[-+]\d\+'

" Floating point number with decimal no E or e (+,-)
syn match kdlNumber '\d\+\.\d*' contained display
syn match kdlNumber '[-+]\d\+\.\d*' contained display
 
" Floating point like number with E and no decimal point (+,-)
syn match kdlNumber '[-+]\=\d[[:digit:]]*[eE][\-+]\=\d\+' contained display
syn match kdlNumber '\d[[:digit:]]*[eE][\-+]\=\d\+' contained display
 
" Floating point like number with E and decimal point (+,-)
syn match kdlNumber '[-+]\=\d[[:digit:]]*\.\d*[eE][\-+]\=\d\+' contained display
syn match kdlNumber '\d[[:digit:]]*\.\d*[eE][\-+]\=\d\+' contained display

syn region kdlString start='"' end='"' skip='\\\\\|\\"' display
 
syn region kdlChildren start="{" end="}" contains=kdlString,kdlNumber,kdlNode,kdlBool,kdlComment

hi def link kdlTodo        Todo
hi def link kdlComment     Comment
hi def link kdlNode        Statement
hi def link kdlBool        Boolean
hi def link kdlString      String
hi def link kdlNumber      Number

let b:current_syntax = "kdl"
