" Vim syntax file
" Language: GoAccess configuration
" Maintainer: Adam Monsen <haircut@gmail.com>
" Last Change: 2024 Aug 1
" Remark: see https://goaccess.io/man#configuration
"
" The GoAccess configuration file syntax is line-separated settings. Settings
" are space-separated key value pairs. Comments are any line starting with a
" hash mark.
" Example: https://github.com/allinurl/goaccess/blob/master/config/goaccess.conf
"
" This syntax definition supports todo/fixme highlighting in comments, and
" special (Keyword) highlighting if a setting's value is 'true' or 'false'.
"
" TODO: a value is required, so use extreme highlighting (e.g. bright red
" background) if a setting is missing a value.

if exists("b:current_syntax")
  finish
endif

syn match goaccessSettingName '^[a-z-]\+' nextgroup=goaccessSettingValue
syn match goaccessSettingValue '\s\+.\+$' contains=goaccessKeyword
syn match goaccessComment "^#.*$" contains=goaccessTodo,@Spell
syn keyword goaccessTodo TODO FIXME contained
syn keyword goaccessKeyword true false contained

hi def link goaccessSettingName Type
hi def link goaccessSettingValue String
hi def link goaccessComment Comment
hi def link goaccessTodo Todo
hi def link goaccessKeyword Keyword

let b:current_syntax = "goaccess"
