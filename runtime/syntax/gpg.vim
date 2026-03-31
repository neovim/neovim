" Vim syntax file
" Language:		gpg(1) configuration file
" Maintainer: This runtime file is looking for a maintainer.
" Previous Maintainer:	Nikolai Weibull <now@bitwi.se>
" Latest Revision:	2024-02-11
" Updated:		
"     2023-01-23 @ObserverOfTime: added a couple of keywords
"			2023-03-21 Todd Zullinger <tmz@pobox.com>: sync with gnupg-2.4.0
"			2024-02-10 Daniel Kahn Gillmor <dkg@fifthhorseman.net>:
"			           mark use-embedded-filename as warning for security reasons

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

setlocal iskeyword+=-

syn keyword gpgTodo	contained FIXME TODO XXX NOTE

syn region  gpgComment	contained display oneline start='#' end='$'
			\ contains=gpgTodo,gpgID,@Spell

syn match   gpgID	contained display '\<\(0x\)\=\x\{8,}\>'

syn match   gpgBegin	display '^' skipwhite nextgroup=gpgComment,gpgOption,gpgOptionDeprecated,gpgCommand

syn keyword gpgCommand	contained skipwhite nextgroup=gpgArg
			\ change-passphrase check-sig check-signatures
			\ check-sigs delete-keys delete-secret-and-public-keys
			\ delete-secret-keys desig-revoke export
			\ export-secret-keys export-secret-ssh-key
			\ export-secret-subkeys export-ssh-key list-key
			\ list-keys list-packets list-public-keys
			\ list-secret-keys list-sig list-signatures list-sigs
			\ passwd send-keys fetch-keys
			\ generate-designated-revocation generate-revocation
			\ gen-prime gen-random gen-revoke locate-external-keys
			\ locate-keys lsign-key options print-md quick-add-key
			\ quick-addkey quick-add-uid quick-adduid
			\ quick-generate-key quick-gen-key quick-lsign-key
			\ quick-revoke-sig quick-revoke-uid quick-revuid
			\ quick-set-expire quick-set-primary-uid quick-sign-key
			\ quick-update-pref receive-keys recv-keys refresh-keys
			\ search-keys show-key show-keys sign-key tofu-policy

syn keyword gpgCommand	contained skipwhite nextgroup=gpgArgError
			\ card-edit card-status change-pin check-trustdb
			\ clear-sign clearsign dearmor dearmour decrypt
			\ decrypt-files detach-sign encrypt encrypt-files
			\ edit-card edit-key enarmor enarmour export-ownertrust
			\ fast-import import import-ownertrust key-edit
			\ fingerprint fix-trustdb full-generate-key
			\ full-gen-key generate-key gen-key gpgconf-list
			\ gpgconf-test list-config list-gcrypt-config
			\ list-trustdb no-options print-mds
			\ rebuild-keydb-caches server sign store symmetric
			\ update-trustdb verify verify-files

syn keyword gpgOption	contained skipwhite nextgroup=gpgArg
			\ aead-algo agent-program attribute-fd attribute-file
			\ auto-key-locate bzip2-compress-level cert-digest-algo
			\ cert-notation cert-policy-url charset chuid
			\ chunk-size cipher-algo command-fd command-file
			\ comment compatibility-flags completes-needed
			\ compliance compress-algo compression-algo
			\ compress-level ctapi-driver debug
			\ debug-allow-large-chunks debug-level
			\ debug-set-iobuf-size default-cert-check-level
			\ default-cert-expire default-cert-level default-key
			\ default-keyserver-url default-new-key-algo
			\ default-preference-list default-recipient
			\ default-sig-expire digest-algo dirmngr-program
			\ disable-cipher-algo disable-pubkey-algo display
			\ display-charset encrypt-to exec-path export-filter
			\ export-options faked-system-time force-ownertrust
			\ gpg-agent-info group hidden-encrypt-to
			\ hidden-recipient hidden-recipient-file homedir
			\ import-filter import-options input-size-hint
			\ keyboxd-program keyid-format key-origin keyring
			\ keyserver keyserver-options known-notation lc-ctype
			\ lc-messages limit-card-insert-tries list-filter
			\ list-options local-user log-file logger-fd
			\ logger-file marginals-needed max-cert-depth
			\ max-output min-cert-level min-rsa-length output
			\ override-session-key override-session-key-fd
			\ passphrase passphrase-fd passphrase-file
			\ passphrase-repeat pcsc-driver
			\ personal-aead-preferences personal-cipher-preferences
			\ personal-cipher-prefs personal-compress-preferences
			\ personal-compress-prefs personal-digest-preferences
			\ photo-viewer pinentry-mode primary-keyring
			\ reader-port recipient recipient-file remote-user
			\ request-origin s2k-cipher-algo s2k-count
			\ s2k-digest-algo s2k-mode secret-keyring sender
			\ set-filename set-filesize set-notation set-policy-url
			\ sig-keyserver-url sig-notation sign-with
			\ sig-policy-url status-fd status-file temp-directory
			\ tofu-db-format tofu-default-policy trustdb-name
			\ trusted-key trust-model try-secret-key ttyname
			\ ttytype ungroup user verify-options weak-digest
			\ xauthority

syn keyword gpgOption	contained skipwhite nextgroup=gpgArgError
			\ allow-freeform-uid allow-multiple-messages
			\ allow-multisig-verification allow-non-selfsigned-uid
			\ allow-old-cipher-algos allow-secret-key-import
			\ allow-weak-digest-algos allow-weak-key-signatures
			\ always-trust armor armour ask-cert-expire
			\ ask-cert-level ask-sig-expire auto-check-trustdb
			\ auto-key-import auto-key-retrieve batch
			\ bzip2-decompress-lowmem compress-keys compress-sigs
			\ debug-all debug-iolbf debug-quick-random
			\ default-comment default-recipient-self disable-ccid
			\ disable-dirmngr disable-dsa2 disable-large-rsa
			\ disable-mdc disable-signer-uid dry-run dump-options
			\ dump-option-table emit-version enable-dsa2
			\ enable-large-rsa enable-progress-filter
			\ enable-special-filenames encrypt-to-default-key
			\ escape-from-lines exit-on-status-write-error expert
			\ fast-list-mode file-is-digest fixed-list-mode
			\ forbid-gen-key force-aead force-mdc force-ocb
			\ force-sign-key force-v3-sigs force-v4-certs
			\ for-your-eyes-only full-timestrings gnupg help
			\ honor-http-proxy ignore-crc-error ignore-mdc-error
			\ ignore-time-conflict ignore-valid-from
			\ include-key-block interactive legacy-list-mode
			\ list-only lock-multiple lock-never lock-once
			\ mangle-dos-filenames merge-only mimemode multifile no
			\ no-allow-freeform-uid no-allow-multiple-messages
			\ no-allow-non-selfsigned-uid no-armor no-armour
			\ no-ask-cert-expire no-ask-cert-level
			\ no-ask-sig-expire no-auto-check-trustdb
			\ no-auto-key-import no-auto-key-locate
			\ no-auto-key-retrieve no-autostart
			\ no-auto-trust-new-key no-batch no-comments
			\ no-default-keyring no-default-recipient
			\ no-disable-mdc no-emit-version no-encrypt-to
			\ no-escape-from-lines no-expensive-trust-checks
			\ no-expert no-force-mdc no-force-v3-sigs
			\ no-force-v4-certs no-for-your-eyes-only no-greeting
			\ no-groups no-include-key-block no-keyring no-literal
			\ no-mangle-dos-filenames no-mdc-warning
			\ no-permission-warning no-pgp2 no-pgp6 no-pgp7 no-pgp8
			\ no-random-seed-file no-require-backsigs
			\ no-require-cross-certification no-require-secmem
			\ no-rfc2440-text no-secmem-warning no-show-notation
			\ no-show-photos no-show-policy-url no-sig-cache
			\ no-sk-comments no-skip-hidden-recipients
			\ no-symkey-cache not-dash-escaped no-textmode
			\ no-throw-keyids no-tty no-use-agent
			\ no-utf8-strings no-verbose
			\ no-version only-sign-text-ids openpgp
			\ override-compliance-check pgp6 pgp7 pgp8
			\ preserve-permissions print-dane-records quiet
			\ require-backsigs require-compliance
			\ require-cross-certification require-secmem rfc2440
			\ rfc2440-text rfc4880 rfc4880bis show-keyring
			\ show-notation show-photos show-policy-url
			\ show-session-key sk-comments skip-hidden-recipients
			\ skip-verify textmode throw-keyids try-all-secrets
			\ unwrap use-agent use-keyboxd
			\ use-only-openpgp-card utf8-strings verbose version
			\ warranty with-colons with-fingerprint
			\ with-icao-spelling with-key-data with-keygrip
			\ with-key-origin with-key-screening with-secret
			\ with-sig-check with-sig-list with-subkey-fingerprint
			\ with-subkey-fingerprints with-tofu-info with-wkd-hash
			\ yes

" depcrated for security reasons
syn keyword gpgOptionDeprecated	contained skipwhite nextgroup=gpgArgError
      \ use-embedded-filename no-use-embedded-filename

syn match   gpgArg	contained display '\S\+\(\s\+\S\+\)*' contains=gpgID
syn match   gpgArgError contained display '\S\+\(\s\+\S\+\)*'

hi def link gpgComment	Comment
hi def link gpgTodo	Todo
hi def link gpgID	Number
hi def link gpgOption	Keyword
hi def link gpgOptionDeprecated	WarningMsg
hi def link gpgCommand	Error
hi def link gpgArgError	Error

let b:current_syntax = "gpg"

let &cpo = s:cpo_save
unlet s:cpo_save
