" Vim syntax file
" Language:     OpenSSH known hosts file
" Author:       Fionn Fitzmaurice (github.com/fionn)
" Maintainer:   Fionn Fitzmaurice (github.com/fionn)
" License:      Vim & Apache 2.0

if exists("b:current_syntax")
    finish
endif

runtime! syntax/sshpublickey.vim

syn match sshKnownHostsMarker "^@cert-authority\>" nextgroup=sshKnownHostsHostname,sshKnownHostsHashedHostname skipwhite
syn match sshKnownHostsMarker "^@revoked\>" nextgroup=sshKnownHostsHostname,sshKnownHostsHashedHostname skipwhite

syn match sshKnownHostsHostname "!\?[a-zA-Z0-9.*-]\+" nextgroup=sshKnownHostsHostnameSeparator,sshKeyType skipwhite
syn match sshKnownHostsHostname "!\?\[[a-zA-Z0-9.*-]\+\]:[0-9]\{1,5}" nextgroup=sshKnownHostsHostnameSeparator,sshKeyType skipwhite
syn match sshKnownHostsHostnameSeparator "," contained nextgroup=sshKnownHostsHostname

syn match sshKnownHostsHashedHostname "|1|[a-zA-Z0-9/+]\+=\{,2}|[a-zA-Z0-9/+]\+=\{,2}" nextgroup=sshKeyType skipwhite

hi def link sshKnownHostsMarker Statement
hi def link sshKnownHostsHostname Identifier
hi def link sshKnownHostsHostnameSeparator Punctuation
hi def link sshKnownHostsHashedHostname Identifier

let b:current_syntax = "sshknownhosts"
