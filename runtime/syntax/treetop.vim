" Vim syntax file
" Language:             Treetop
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2011-03-14

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword treetopTodo
      \ contained
      \ TODO
      \ FIXME
      \ XXX
      \ NOTE

syn match treetopComment
                        \ '#.*'
                        \ display
                        \ contains=treetopTodo

syn include @treetopRuby syntax/ruby.vim
unlet b:current_syntax

syn keyword treetopKeyword
                         \ require
                         \ end
syn region  treetopKeyword
                         \ matchgroup=treetopKeyword
                         \ start='\<\%(grammar\|include\|module\)\>\ze\s'
                         \ end='$'
                         \ transparent
                         \ oneline
                         \ keepend
                         \ contains=@treetopRuby
syn keyword treetopKeyword
                         \ rule
                         \ nextgroup=treetopRuleName
                         \ skipwhite skipnl

syn match   treetopGrammarName
                             \ '\u\w*'
                             \ contained

syn match   treetopRubyModuleName
                                \ '\u\w*'
                                \ contained

syn match   treetopRuleName
                          \ '\h\w*'
                          \ contained

syn region  treetopString
                        \ matchgroup=treetopStringDelimiter
                        \ start=+"+
                        \ end=+"+
syn region  treetopString
                        \ matchgroup=treetopStringDelimiter
                        \ start=+'+
                        \ end=+'+

syn region  treetopCharacterClass
                                \ matchgroup=treetopCharacterClassDelimiter
                                \ start=+\[+
                                \ skip=+\\\]+
                                \ end=+\]+

syn region  treetopRubyBlock
                           \ matchgroup=treetopRubyBlockDelimiter
                           \ start=+{+
                           \ end=+}+
                           \ contains=@treetopRuby

syn region  treetopSemanticPredicate
                           \ matchgroup=treetopSemanticPredicateDelimiter
                           \ start=+[!&]{+
                           \ end=+}+
                           \ contains=@treetopRuby

syn region  treetopSubclassDeclaration
                           \ matchgroup=treetopSubclassDeclarationDelimiter
                           \ start=+<+
                           \ end=+>+
                           \ contains=@treetopRuby

syn match   treetopEllipsis
                          \ +''+

hi def link treetopTodo                         Todo
hi def link treetopComment                      Comment
hi def link treetopKeyword                      Keyword
hi def link treetopGrammarName                  Constant
hi def link treetopRubyModuleName               Constant
hi def link treetopRuleName                     Identifier
hi def link treetopString                       String
hi def link treetopStringDelimiter              treetopString
hi def link treetopCharacterClass               treetopString
hi def link treetopCharacterClassDelimiter      treetopCharacterClass
hi def link treetopRubyBlockDelimiter           PreProc
hi def link treetopSemanticPredicateDelimiter   PreProc
hi def link treetopSubclassDeclarationDelimiter PreProc
hi def link treetopEllipsis                     Special

let b:current_syntax = 'treetop'

let &cpo = s:cpo_save
unlet s:cpo_save
