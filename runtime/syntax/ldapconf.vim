" Vim syntax file
" Language:         ldap.conf(5) configuration file.
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-12-11

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword ldapconfTodo          contained TODO FIXME XXX NOTE

syn region  ldapconfComment       display oneline start='^\s*#' end='$'
      \                           contains=ldapconfTodo,
      \                                    @Spell

syn match   ldapconfBegin         display '^'
      \                           nextgroup=ldapconfOption,
      \                                     ldapconfDeprOption,
      \                                     ldapconfComment

syn case    ignore

syn keyword ldapconfOption        contained URI 
      \                           nextgroup=ldapconfURI
      \                           skipwhite

syn keyword ldapconfOption        contained
      \                           BASE
      \                           BINDDN
      \                           nextgroup=ldapconfDNAttrType
      \                           skipwhite

syn keyword ldapconfDeprOption    contained 
      \                           HOST
      \                           nextgroup=ldapconfHost
      \                           skipwhite

syn keyword ldapconfDeprOption    contained
      \                           PORT
      \                           nextgroup=ldapconfPort
      \                           skipwhite

syn keyword ldapconfOption        contained
      \                           REFERRALS
      \                           nextgroup=ldapconfBoolean
      \                           skipwhite

syn keyword ldapconfOption        contained
      \                           SIZELIMIT
      \                           TIMELIMIT
      \                           nextgroup=ldapconfInteger
      \                           skipwhite

syn keyword ldapconfOption        contained
      \                           DEREF
      \                           nextgroup=ldapconfDerefWhen
      \                           skipwhite

syn keyword ldapconfOption        contained
      \                           SASL_MECH
      \                           nextgroup=ldapconfSASLMechanism
      \                           skipwhite

syn keyword ldapconfOption        contained
      \                           SASL_REALM
      \                           nextgroup=ldapconfSASLRealm
      \                           skipwhite

syn keyword ldapconfOption        contained
      \                           SASL_AUTHCID
      \                           SASL_AUTHZID
      \                           nextgroup=ldapconfSASLAuthID
      \                           skipwhite

syn keyword ldapconfOption        contained
      \                           SASL_SECPROPS
      \                           nextgroup=ldapconfSASLSecProps
      \                           skipwhite

syn keyword ldapconfOption        contained
      \                           TLS_CACERT
      \                           TLS_CERT
      \                           TLS_KEY
      \                           TLS_RANDFILE
      \                           nextgroup=ldapconfFilename
      \                           skipwhite

syn keyword ldapconfOption        contained
      \                           TLS_CACERTDIR
      \                           nextgroup=ldapconfPath
      \                           skipwhite

syn keyword ldapconfOption        contained
      \                           TLS_CIPHER_SUITE
      \                           nextgroup=@ldapconfTLSCipher
      \                           skipwhite

syn keyword ldapconfOption        contained
      \                           TLS_REQCERT
      \                           nextgroup=ldapconfTLSCertCheck
      \                           skipwhite

syn keyword ldapconfOption        contained
      \                           TLS_CRLCHECK
      \                           nextgroup=ldapconfTLSCRLCheck
      \                           skipwhite

syn case    match

syn match   ldapconfURI           contained display
      \                           'ldaps\=://[^[:space:]:]\+\%(:\d\+\)\='
      \                           nextgroup=ldapconfURI
      \                           skipwhite

" LDAP Distinguished Names are defined in Section 3 of RFC 2253:
" http://www.ietf.org/rfc/rfc2253.txt.
syn match   ldapconfDNAttrType    contained display
      \                           '\a[a-zA-Z0-9-]\+\|\d\+\%(\.\d\+\)*'
      \                           nextgroup=ldapconfDNAttrTypeEq

syn match   ldapconfDNAttrTypeEq  contained display
      \                           '='
      \                           nextgroup=ldapconfDNAttrValue

syn match   ldapconfDNAttrValue   contained display
      \                           '\%([^,=+<>#;\\"]\|\\\%([,=+<>#;\\"]\|\x\x\)\)*\|#\%(\x\x\)\+\|"\%([^\\"]\|\\\%([,=+<>#;\\"]\|\x\x\)\)*"'
      \                           nextgroup=ldapconfDNSeparator

syn match   ldapconfDNSeparator   contained display
      \                           '[+,]'
      \                           nextgroup=ldapconfDNAttrType

syn match   ldapconfHost          contained display
      \                           '[^[:space:]:]\+\%(:\d\+\)\='
      \                           nextgroup=ldapconfHost
      \                           skipwhite

syn match   ldapconfPort          contained display
      \                           '\d\+'

syn keyword ldapconfBoolean       contained
      \                           on
      \                           true
      \                           yes
      \                           off
      \                           false
      \                           no

syn match   ldapconfInteger       contained display
      \                           '\d\+'

syn keyword ldapconfDerefWhen     contained
      \                           never
      \                           searching
      \                           finding
      \                           always

" Taken from http://www.iana.org/assignments/sasl-mechanisms.
syn keyword ldapconfSASLMechanism contained
      \                           KERBEROS_V4
      \                           GSSAPI
      \                           SKEY
      \                           EXTERNAL
      \                           ANONYMOUS
      \                           OTP
      \                           PLAIN
      \                           SECURID
      \                           NTLM
      \                           NMAS_LOGIN
      \                           NMAS_AUTHEN
      \                           KERBEROS_V5

syn match   ldapconfSASLMechanism contained display
      \                           'CRAM-MD5\|GSS-SPNEGO\|DIGEST-MD5\|9798-[UM]-\%(RSA-SHA1-ENC\|\%(EC\)\=DSA-SHA1\)\|NMAS-SAMBA-AUTH'

" TODO: I have been unable to find a definition for a SASL realm,
" authentication identity, and proxy authorization identity.
syn match   ldapconfSASLRealm     contained display
      \                           '\S\+'

syn match   ldapconfSASLAuthID    contained display
      \                           '\S\+'

syn keyword ldapconfSASLSecProps  contained
      \                           none
      \                           noplain
      \                           noactive
      \                           nodict
      \                           noanonymous
      \                           forwardsec
      \                           passcred
      \                           nextgroup=ldapconfSASLSecPSep

syn keyword ldapconfSASLSecProps  contained
      \                           minssf
      \                           maxssf
      \                           maxbufsize
      \                           nextgroup=ldapconfSASLSecPEq

syn match   ldapconfSASLSecPEq    contained display
      \                           '='
      \                           nextgroup=ldapconfSASLSecFactor

syn match   ldapconfSASLSecFactor contained display
      \                           '\d\+'
      \                           nextgroup=ldapconfSASLSecPSep

syn match   ldapconfSASLSecPSep   contained display
      \                           ','
      \                           nextgroup=ldapconfSASLSecProps

syn match   ldapconfFilename      contained display
      \                           '.\+'

syn match   ldapconfPath          contained display
      \                           '.\+'

" Defined in openssl-ciphers(1).
" TODO: Should we include the stuff under CIPHER SUITE NAMES?
syn cluster ldapconfTLSCipher     contains=ldapconfTLSCipherOp,
      \                                    ldapconfTLSCipherName,
      \                                    ldapconfTLSCipherSort

syn match   ldapconfTLSCipherOp   contained display
      \                           '[+!-]'
      \                           nextgroup=ldapconfTLSCipherName

syn keyword ldapconfTLSCipherName contained
      \                           DEFAULT
      \                           COMPLEMENTOFDEFAULT
      \                           ALL
      \                           COMPLEMENTOFALL
      \                           HIGH
      \                           MEDIUM
      \                           LOW
      \                           EXP
      \                           EXPORT
      \                           EXPORT40
      \                           EXPORT56
      \                           eNULL
      \                           NULL
      \                           aNULL
      \                           kRSA
      \                           RSA
      \                           kEDH
      \                           kDHr
      \                           kDHd
      \                           aRSA
      \                           aDSS
      \                           DSS
      \                           aDH
      \                           kFZA
      \                           aFZA
      \                           eFZA
      \                           FZA
      \                           TLSv1
      \                           SSLv3
      \                           SSLv2
      \                           DH
      \                           ADH
      \                           AES
      \                           3DES
      \                           DES
      \                           RC4
      \                           RC2
      \                           IDEA
      \                           MD5
      \                           SHA1
      \                           SHA
      \                           Camellia
      \                           nextgroup=ldapconfTLSCipherSep

syn match   ldapconfTLSCipherSort contained display
      \                           '@STRENGTH'
      \                           nextgroup=ldapconfTLSCipherSep

syn match   ldapconfTLSCipherSep  contained display
      \                           '[:, ]'
      \                           nextgroup=@ldapconfTLSCipher

syn keyword ldapconfTLSCertCheck  contained
      \                           never
      \                           allow
      \                           try
      \                           demand
      \                           hard

syn keyword ldapconfTLSCRLCheck   contained
      \                           none
      \                           peer
      \                           all

hi def link ldapconfTodo          Todo
hi def link ldapconfComment       Comment
hi def link ldapconfOption        Keyword
hi def link ldapconfDeprOption    Error
hi def link ldapconfString        String
hi def link ldapconfURI           ldapconfString
hi def link ldapconfDNAttrType    Identifier
hi def link ldapconfOperator      Operator
hi def link ldapconfEq            ldapconfOperator
hi def link ldapconfDNAttrTypeEq  ldapconfEq
hi def link ldapconfValue         ldapconfString
hi def link ldapconfDNAttrValue   ldapconfValue
hi def link ldapconfSeparator     ldapconfOperator
hi def link ldapconfDNSeparator   ldapconfSeparator
hi def link ldapconfHost          ldapconfURI
hi def link ldapconfNumber        Number
hi def link ldapconfPort          ldapconfNumber
hi def link ldapconfBoolean       Boolean
hi def link ldapconfInteger       ldapconfNumber
hi def link ldapconfType          Type
hi def link ldapconfDerefWhen     ldapconfType
hi def link ldapconfDefine        Define
hi def link ldapconfSASLMechanism ldapconfDefine
hi def link ldapconfSASLRealm     ldapconfURI
hi def link ldapconfSASLAuthID    ldapconfValue
hi def link ldapconfSASLSecProps  ldapconfType
hi def link ldapconfSASLSecPEq    ldapconfEq
hi def link ldapconfSASLSecFactor ldapconfNumber
hi def link ldapconfSASLSecPSep   ldapconfSeparator
hi def link ldapconfFilename      ldapconfString
hi def link ldapconfPath          ldapconfFilename
hi def link ldapconfTLSCipherOp   ldapconfOperator
hi def link ldapconfTLSCipherName ldapconfDefine
hi def link ldapconfSpecial       Special
hi def link ldapconfTLSCipherSort ldapconfSpecial
hi def link ldapconfTLSCipherSep  ldapconfSeparator
hi def link ldapconfTLSCertCheck  ldapconfType
hi def link ldapconfTLSCRLCheck   ldapconfType

let b:current_syntax = "ldapconf"

let &cpo = s:cpo_save
unlet s:cpo_save
