" Vim syntax file
" Language:    env
" Maintainer:  DuckAfire <duckafire@gmail.com>
" Last Change: 2026 Jan 27
" Version:     2
" Changelog:
" 0. Create syntax file.
" 1. Remove unused variable (g:main_syntax).
" 2. Apply changes required by github@dkearns

if exists("b:current_syntax")
  finish
endif

syn match   envField   nextgroup=envValue         /^\h\%(\w\|\.\)*/
syn region  envValue   matchgroup=Operator        start=/=/ end=/$/
syn match   envComment contains=envTodo,envTitles /^#.*$/
syn keyword envTodo    contained                  CAUTION NOTE TODO WARN WARNING
syn match   envTitle   contained                  /^\s*#\s*\zs[A-Z0-9][A-Z0-9 ]*:/

hi def link envField   Identifier
hi def link envValue   String
hi def link envComment Comment
hi def link envTodo    Todo
hi def link envTitle   PreProc

let b:current_syntax = "env"

