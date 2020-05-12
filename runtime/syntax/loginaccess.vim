" Vim syntax file
" Language:             login.access(5) configuration file
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword loginaccessTodo           contained TODO FIXME XXX NOTE

syn region  loginaccessComment        display oneline start='^#' end='$'
                                      \ contains=loginaccessTodo,@Spell

syn match   loginaccessBegin          display '^'
                                      \ nextgroup=loginaccessPermission,
                                      \ loginaccessComment skipwhite

syn match   loginaccessPermission     contained display '[^#]'
                                      \ contains=loginaccessPermError
                                      \ nextgroup=loginaccessUserSep

syn match   loginaccessPermError      contained display '[^+-]'

syn match   loginaccessUserSep        contained display ':'
                                      \ nextgroup=loginaccessUsers,
                                      \ loginaccessAllUsers,
                                      \ loginaccessExceptUsers

syn match   loginaccessUsers          contained display '[^, \t:]\+'
                                      \ nextgroup=loginaccessUserIntSep,
                                      \ loginaccessOriginSep

syn match   loginaccessAllUsers       contained display '\<ALL\>'
                                      \ nextgroup=loginaccessUserIntSep,
                                      \ loginaccessOriginSep

syn match   loginaccessLocalUsers     contained display '\<LOCAL\>'
                                      \ nextgroup=loginaccessUserIntSep,
                                      \ loginaccessOriginSep

syn match   loginaccessExceptUsers    contained display '\<EXCEPT\>'
                                      \ nextgroup=loginaccessUserIntSep,
                                      \ loginaccessOriginSep

syn match   loginaccessUserIntSep     contained display '[, \t]'
                                      \ nextgroup=loginaccessUsers,
                                      \ loginaccessAllUsers,
                                      \ loginaccessExceptUsers

syn match   loginaccessOriginSep      contained display ':'
                                      \ nextgroup=loginaccessOrigins,
                                      \ loginaccessAllOrigins,
                                      \ loginaccessExceptOrigins

syn match   loginaccessOrigins        contained display '[^, \t]\+'
                                      \ nextgroup=loginaccessOriginIntSep

syn match   loginaccessAllOrigins     contained display '\<ALL\>'
                                      \ nextgroup=loginaccessOriginIntSep

syn match   loginaccessLocalOrigins   contained display '\<LOCAL\>'
                                      \ nextgroup=loginaccessOriginIntSep

syn match   loginaccessExceptOrigins  contained display '\<EXCEPT\>'
                                      \ nextgroup=loginaccessOriginIntSep

syn match   loginaccessOriginIntSep   contained display '[, \t]'
                                      \ nextgroup=loginaccessOrigins,
                                      \ loginaccessAllOrigins,
                                      \ loginaccessExceptOrigins

hi def link loginaccessTodo           Todo
hi def link loginaccessComment        Comment
hi def link loginaccessPermission     Type
hi def link loginaccessPermError      Error
hi def link loginaccessUserSep        Delimiter
hi def link loginaccessUsers          Identifier
hi def link loginaccessAllUsers       Macro
hi def link loginaccessLocalUsers     Macro
hi def link loginaccessExceptUsers    Operator
hi def link loginaccessUserIntSep     loginaccessUserSep
hi def link loginaccessOriginSep      loginaccessUserSep
hi def link loginaccessOrigins        Identifier
hi def link loginaccessAllOrigins     Macro
hi def link loginaccessLocalOrigins   Macro
hi def link loginaccessExceptOrigins  loginaccessExceptUsers
hi def link loginaccessOriginIntSep   loginaccessUserSep

let b:current_syntax = "loginaccess"

let &cpo = s:cpo_save
unlet s:cpo_save
