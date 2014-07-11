" Vim syntax file
" Language:         gpg(1) configuration file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2010-10-14

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

setlocal iskeyword+=-

syn keyword gpgTodo     contained FIXME TODO XXX NOTE

syn region  gpgComment  contained display oneline start='#' end='$'
                        \ contains=gpgTodo,gpgID,@Spell

syn match   gpgID       contained display '\<\(0x\)\=\x\{8,}\>'

syn match   gpgBegin    display '^' skipwhite nextgroup=gpgComment,gpgOption,gpgCommand

syn keyword gpgCommand  contained skipwhite nextgroup=gpgArg
                        \ check-sigs decrypt decrypt-files delete-key
                        \ delete-secret-and-public-key delete-secret-key
                        \ edit-key encrypt-files export export-all
                        \ export-ownertrust export-secret-keys
                        \ export-secret-subkeys fast-import fingerprint
                        \ gen-prime gen-random import import-ownertrust
                        \ list-keys list-public-keys list-secret-keys
                        \ list-sigs lsign-key nrsign-key print-md print-mds
                        \ recv-keys search-keys send-keys sign-key verify
                        \ verify-files
syn keyword gpgCommand  contained skipwhite nextgroup=gpgArgError
                        \ check-trustdb clearsign desig-revoke detach-sign
                        \ encrypt gen-key gen-revoke help list-packets
                        \ rebuild-keydb-caches sign store symmetric
                        \ update-trustdb version warranty

syn keyword gpgOption   contained skipwhite nextgroup=gpgArg
                        \ attribute-fd cert-digest-algo charset cipher-algo
                        \ command-fd comment completes-needed compress
                        \ compress-algo debug default-cert-check-level
                        \ default-key default-preference-list
                        \ default-recipient digest-algo disable-cipher-algo
                        \ disable-pubkey-algo encrypt-to exec-path
                        \ export-options group homedir import-options
                        \ keyring keyserver keyserver-options load-extension
                        \ local-user logger-fd marginals-needed max-cert-depth
                        \ notation-data options output override-session-key
                        \ passphrase-fd personal-cipher-preferences
                        \ personal-compress-preferences
                        \ personal-digest-preferences photo-viewer
                        \ recipient s2k-cipher-algo s2k-digest-algo s2k-mode
                        \ secret-keyring set-filename set-policy-url status-fd
                        \ trusted-key verify-options keyid-format list-options
syn keyword gpgOption   contained skipwhite nextgroup=gpgArgError
                        \ allow-freeform-uid allow-non-selfsigned-uid
                        \ allow-secret-key-import always-trust
                        \ armor ask-cert-expire ask-sig-expire
                        \ auto-check-trustdb batch debug-all default-comment
                        \ default-recipient-self dry-run emit-version
                        \ emulate-md-encode-bug enable-special-filenames
                        \ escape-from-lines expert fast-list-mode
                        \ fixed-list-mode for-your-eyes-only
                        \ force-mdc force-v3-sigs force-v4-certs
                        \ gpg-agent-info ignore-crc-error ignore-mdc-error
                        \ ignore-time-conflict ignore-valid-from interactive
                        \ list-only lock-multiple lock-never lock-once
                        \ merge-only no no-allow-non-selfsigned-uid
                        \ no-armor no-ask-cert-expire no-ask-sig-expire
                        \ no-auto-check-trustdb no-batch no-comment
                        \ no-default-keyring no-default-recipient
                        \ no-encrypt-to no-expensive-trust-checks
                        \ no-expert no-for-your-eyes-only no-force-v3-sigs
                        \ no-force-v4-certs no-greeting no-literal
                        \ no-mdc-warning no-options no-permission-warning
                        \ no-pgp2 no-pgp6 no-pgp7 no-random-seed-file
                        \ no-secmem-warning no-show-notation no-show-photos
                        \ no-show-policy-url no-sig-cache no-sig-create-check
                        \ no-sk-comments no-tty no-utf8-strings no-verbose
                        \ no-version not-dash-escaped openpgp pgp2
                        \ pgp6 pgp7 preserve-permissions quiet rfc1991
                        \ set-filesize show-keyring show-notation show-photos
                        \ show-policy-url show-session-key simple-sk-checksum
                        \ sk-comments skip-verify textmode throw-keyid
                        \ try-all-secrets use-agent use-embedded-filename
                        \ utf8-strings verbose with-colons with-fingerprint
                        \ with-key-data yes

syn match   gpgArg      contained display '\S\+\(\s\+\S\+\)*' contains=gpgID
syn match   gpgArgError contained display '\S\+\(\s\+\S\+\)*'

hi def link gpgComment  Comment
hi def link gpgTodo     Todo
hi def link gpgID       Number
hi def link gpgOption   Keyword
hi def link gpgCommand  Error
hi def link gpgArgError Error

let b:current_syntax = "gpg"

let &cpo = s:cpo_save
unlet s:cpo_save
