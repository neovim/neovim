" Vim syntax file
" Language:     OpenSSH authorized keys file
" Author:       Fionn Fitzmaurice (github.com/fionn)
" Maintainer:   Fionn Fitzmaurice (github.com/fionn)
" License:      Vim & Apache 2.0

if exists("b:current_syntax")
    finish
endif

syn region sshAuthorizedKeyOptions start="^[a-z]" end="\s" contains=@sshAuthorizedKeyOption nextgroup=sshKeyType skipwhite oneline
syn cluster sshAuthorizedKeyOption contains=sshAuthorizedKeyOptionKeyword,sshAuthorizedKeyOptionSeparator,sshAuthorizedKeyOptionAssignment,sshAuthorizedKeyOptionValue
syn match sshAuthorizedKeyOptionKeyword "[a-z-]\+" contained
syn match sshAuthorizedKeyOptionSeparator "," contained
syn match sshAuthorizedKeyOptionAssignment "=" contained
syn match sshAuthorizedKeyOptionValue '"\(\\\"\|[^"]\)*"' contained

runtime! syntax/sshpublickey.vim

hi def link sshAuthorizedKeyOptionKeyword Keyword
hi def link sshAuthorizedKeyOptionSeparator Punctuation
hi def link sshAuthorizedKeyOptionAssignment Operator
hi def link sshAuthorizedKeyOptionValue String

let b:current_syntax = "sshauthorizedkeys"
