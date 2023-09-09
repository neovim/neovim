" Vim syntax file
" Language:         JSONC (JSON with Comments)
" Original Author:  Izhak Jakov <izhak724@gmail.com>
" Acknowledgement:  Based off of vim-jsonc maintained by Kevin Locke <kevin@kevinlocke.name>
"                   https://github.com/kevinoid/vim-jsonc
" License:          MIT
" Last Change:      2021-07-01

" Ensure syntax is loaded once, unless nested inside another (main) syntax
" For description of main_syntax, see https://stackoverflow.com/q/16164549
if !exists('g:main_syntax')
  if exists('b:current_syntax') && b:current_syntax ==# 'jsonc'
    finish
  endif
  let g:main_syntax = 'jsonc'
endif

" Based on vim-json syntax
runtime! syntax/json.vim

" Remove syntax group for comments treated as errors
if !exists("g:vim_json_warnings") || g:vim_json_warnings
  syn clear jsonCommentError
endif

syn match jsonStringMatch /"\([^"]\|\\\"\)\+"\ze\(\_s*\/\/.*\_s*\)*[}\]]/ contains=jsonString
syn match jsonStringMatch /"\([^"]\|\\\"\)\+"\ze\_s*\/\*\_.*\*\/\_s*[}\]]/ contains=jsonString
syn match jsonTrailingCommaError /\(,\)\+\ze\(\_s*\/\/.*\_s*\)*[}\]]/
syn match jsonTrailingCommaError /\(,\)\+\ze\_s*\/\*\_.*\*\/\_s*[}\]]/

" Define syntax matching comments and their contents
syn keyword jsonCommentTodo  FIXME NOTE TBD TODO XXX
syn region  jsonLineComment  start=+\/\/+ end=+$+   contains=@Spell,jsonCommentTodo keepend
syn region  jsonComment      start='/\*'  end='\*/' contains=@Spell,jsonCommentTodo fold

" Link comment syntax comment to highlighting
hi! def link jsonLineComment    Comment
hi! def link jsonComment        Comment

" Set/Unset syntax to avoid duplicate inclusion and correctly handle nesting
let b:current_syntax = 'jsonc'
if g:main_syntax ==# 'jsonc'
  unlet g:main_syntax
endif
