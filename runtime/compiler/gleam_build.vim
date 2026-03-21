" Vim compiler file
" Language:    Gleam
" Maintainer:  Kirill Morozov <kirill@robotix.pro>
" Based On:    https://github.com/gleam-lang/gleam.vim
" Last Change: 2025 Apr 21

if exists('current_compiler')
  finish
endif
let current_compiler = "gleam_build"

CompilerSet makeprg=gleam\ build

" Example error message:
"
" error: Unknown variable
"    ┌─ /home/michael/root/projects/tutorials/gleam/try/code/src/main.gleam:19:18
"    │
" 19 │   Ok(tuple(name, spot))
"    │                  ^^^^ did you mean `sport`?
"
" The name `spot` is not in scope here.
CompilerSet errorformat=%Eerror:\ %m,%Wwarning:\ %m,%C\ %#┌─%#\ %f:%l:%c\ %#-%#

" vim: sw=2 sts=2 et
