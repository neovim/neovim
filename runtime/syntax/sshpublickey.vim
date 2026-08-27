" Vim syntax file
" Language:     OpenSSH public key
" Author:       Fionn Fitzmaurice (github.com/fionn)
" Maintainer:   Fionn Fitzmaurice (github.com/fionn)
" License:      Vim & Apache 2.0

if exists("b:current_syntax")
    finish
endif

setlocal iskeyword=_,.,@-@,-,a-z,A-Z,48-57

syn keyword sshKeyType ssh-ed25519 nextgroup=sshKeyBase64Encoded skipwhite
syn keyword sshKeyType sk-ssh-ed25519@openssh.com nextgroup=sshKeyBase64Encoded skipwhite
syn keyword sshKeyType ecdsa-sha2-nistp256 nextgroup=sshKeyBase64Encoded skipwhite
syn keyword sshKeyType ecdsa-sha2-nistp384 nextgroup=sshKeyBase64Encoded skipwhite
syn keyword sshKeyType ecdsa-sha2-nistp521 nextgroup=sshKeyBase64Encoded skipwhite
syn keyword sshKeyType sk-ecdsa-sha2-nistp256@openssh.com nextgroup=sshKeyBase64Encoded skipwhite
syn keyword sshKeyType ssh-rsa nextgroup=sshKeyBase64Encoded skipwhite

syn match sshKeyBase64Encoded "AAAA[a-zA-Z0-9/+]\{64,8000}=\{,2}" contained nextgroup=sshKeyComment
syn match sshKeyComment ".*$" contained

syn match sshKeyComment "#.*$"

hi def link sshKeyType Type
hi def link sshKeyBase64Encoded String
hi def link sshKeyComment Comment

let b:current_syntax = "sshpublickey"
