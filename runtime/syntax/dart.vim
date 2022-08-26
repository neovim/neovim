" Vim syntax file
"
" Language:     Dart
" Maintainer:   Eugene 'pr3d4t0r' Ciurana <dart.syntax AT cime.net >
" Source:       https://github.com/pr3d4t0r/dart-vim-syntax
" Last Update:	2019 Oct 19
"
" License:      Vim is Charityware.  dart.vim syntax is Charityware.
"               (c) Copyright 2019 by Eugene Ciurana / pr3d4t0r.  Licensed
"               under the standard VIM LICENSE - Vim command :help uganda.txt
"               for details.
"
" Questions, comments:  <dart.syntax AT cime.net>
"                       https://ciurana.eu/pgp, https://keybase.io/pr3d4t0r
"
" vim: set fileencoding=utf-8:


" Quit when a (custom) syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim


syn keyword dartCommentTodo     contained TODO FIXME XXX TBD
syn match   dartLineComment     "//.*" contains=dartTodo,@Spell
syn match   dartCommentSkip     "^[ \t]*\*\($\|[ \t]\+\)"
syn region  dartComment         start="/\*"  end="\*/" contains=@Spell,dartTodo
syn keyword dartReserved        assert async await class const export extends external final hide import implements interface library mixin on show super sync yield
syn match   dartNumber          "-\=\<\d\+L\=\>\|0[xX][0-9a-fA-F]\+\>"


syn keyword dartBoolean     false true
syn keyword dartBranch      break continue
syn keyword dartConditional if else switch
syn keyword dartException   catch finally rethrow throw try
syn keyword dartIdentifier  abstract covariant deferred dynamic factory Function operator part static this typedef var
syn keyword dartLabel       case default
syn keyword dartNull        null
syn keyword dartOperator    is new
syn keyword dartRepeat      for do in while
syn keyword dartStatement   return with 
syn keyword dartType        bool double enum int String StringBuffer void
syn keyword dartTodo        contained TODO FIXME XXX


syn match  dartEscape       contained "\\\([4-9]\d\|[0-3]\d\d\|[\"\\'ntbrf]\|u\x\{4\}\)"
syn match  dartSpecialError contained "\\."
syn match  dartStrInterpol  contained "\${[\x, _]*\}"

syn region dartDQString     start=+"+ end=+"+ end=+$+ contains=dartEscape,dartStrInterpol,dartSpecialError,@Spell
syn region dartSQString     start=+'+ end=+'+ end=+$+ contains=dartEscape,dartStrInterpol,dartSpecialError,@Spell

syn match dartBraces        "[{}\[\]]"
syn match dartParens        "[()]"


syn sync fromstart
syn sync maxlines=100


hi def link dartBoolean         Boolean
hi def link dartBranch          Conditional
hi def link dartComment         Comment
hi def link dartConditional     Conditional
hi def link dartDQString        String
hi def link dartEscape          SpecialChar
hi def link dartException       Exception
hi def link dartIdentifier      Identifier
hi def link dartLabel           Label
hi def link dartLineComment     Comment
hi def link dartNull            Keyword
hi def link dartOperator        Operator
hi def link dartRepeat          Repeat
hi def link dartReserved        Keyword
hi def link dartSQString        String
hi def link dartSpecialError    Error
hi def link dartStatement       Statement
hi def link dartStrInterpol     Special
hi def link dartTodo            Todo
hi def link dartType            Type


let b:current_syntax = "dart"
let &cpo = s:cpo_save
unlet s:cpo_save

