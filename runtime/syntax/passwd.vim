" Vim syntax file
" Language:         passwd(5) password file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-10-03

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn match   passwdBegin         display '^' nextgroup=passwdAccount

syn match   passwdAccount       contained display '[^:]\+'
                                \ nextgroup=passwdPasswordColon

syn match   passwdPasswordColon contained display ':'
                                \ nextgroup=passwdPassword,passwdShadow

syn match   passwdPassword      contained display '[^:]\+'
                                \ nextgroup=passwdUIDColon

syn match   passwdShadow        contained display '[x*!]'
                                \ nextgroup=passwdUIDColon

syn match   passwdUIDColon      contained display ':' nextgroup=passwdUID

syn match   passwdUID           contained display '\d\{0,10}'
                                \ nextgroup=passwdGIDColon

syn match   passwdGIDColon      contained display ':' nextgroup=passwdGID

syn match   passwdGID           contained display '\d\{0,10}'
                                \ nextgroup=passwdGecosColon

syn match   passwdGecosColon    contained display ':' nextgroup=passwdGecos

syn match   passwdGecos         contained display '[^:]*'
                                \ nextgroup=passwdDirColon

syn match   passwdDirColon      contained display ':' nextgroup=passwdDir

syn match   passwdDir           contained display '/[^:]*'
                                \ nextgroup=passwdShellColon

syn match   passwdShellColon    contained display ':'
                                \ nextgroup=passwdShell

syn match   passwdShell         contained display '.*'

hi def link passwdColon         Normal
hi def link passwdAccount       Identifier
hi def link passwdPasswordColon passwdColon
hi def link passwdPassword      Number
hi def link passwdShadow        Special
hi def link passwdUIDColon      passwdColon
hi def link passwdUID           Number
hi def link passwdGIDColon      passwdColon
hi def link passwdGID           Number
hi def link passwdGecosColon    passwdColon
hi def link passwdGecos         Comment
hi def link passwdDirColon      passwdColon
hi def link passwdDir           Type
hi def link passwdShellColon    passwdColon
hi def link passwdShell         Operator

let b:current_syntax = "passwd"

let &cpo = s:cpo_save
unlet s:cpo_save
