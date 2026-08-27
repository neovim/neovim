" Vim syntax file
" Language:     OpenSSH allowed signers file
" Author:       Fionn Fitzmaurice (github.com/fionn)
" Maintainer:   Fionn Fitzmaurice (github.com/fionn)
" License:      Vim & Apache 2.0

if exists("b:current_syntax")
    finish
endif

syn match sshAllowedSignersPrincipal "!\?[a-zA-Z0-9.*?_+-]\+@[a-zA-Z0-9.*?-]\+" nextgroup=sshAllowedSignersPrincipalSeparator,sshAllowedSignersOptions,sshKeyType skipwhite
syn match sshAllowedSignersPrincipalSeparator "," contained nextgroup=sshAllowedSignersPrincipal

syn region sshAllowedSignersOptions start="[a-z]" end="\s\@=" contains=@sshAllowedSignersOption nextgroup=sshKeyType skipwhite oneline contained
syn cluster sshAllowedSignersOption contains=sshAllowedSignersOptionKeyword,sshAllowedSignersOptionSeparator,sshAllowedSignersOptionAssignment,sshAllowedSignersOptionValue
syn keyword sshAllowedSignersOptionKeyword namespaces cert-authority valid-after valid-before contained
syn match sshAllowedSignersOptionSeparator "," contained
syn match sshAllowedSignersOptionAssignment "=" contained
syn match sshAllowedSignersOptionValue '"\(\\\"\|[^"]\)*"' contained

runtime! syntax/sshpublickey.vim

hi def link sshAllowedSignersPrincipal Identifier
hi def link sshAllowedSignersPrincipalSeparator Punctuation

hi def link sshAllowedSignersOptionKeyword Keyword
hi def link sshAllowedSignersOptionSeparator Punctuation
hi def link sshAllowedSignersOptionAssignment Operator
hi def link sshAllowedSignersOptionValue String

let b:current_syntax = "sshallowedsigners"
