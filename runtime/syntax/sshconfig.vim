" Vim syntax file
" Language:	OpenSSH client configuration file (ssh_config)
" Author:	David Necas (Yeti)
" Maintainer:	Dominik Fischer <d dot f dot fischer at web dot de>
" Contributor:  Leonard Ehrenfried <leonard.ehrenfried@web.de>
" Contributor:  Karsten Hopp <karsten@redhat.com>
" Contributor:  Dean, Adam Kenneth <adam.ken.dean@hpe.com>
" Last Change:	2016 Dec 28
" SSH Version:	7.4p1
"

" Setup
" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

setlocal iskeyword=_,-,a-z,A-Z,48-57


" case on
syn case match


" Comments
syn match sshconfigComment "^#.*$" contains=sshconfigTodo
syn match sshconfigComment "\s#.*$" contains=sshconfigTodo

syn keyword sshconfigTodo TODO FIXME NOTE contained


" Constants
syn keyword sshconfigYesNo yes no ask confirm
syn keyword sshconfigYesNo any auto
syn keyword sshconfigYesNo force autoask none

syn keyword sshconfigCipher 3des blowfish

syn keyword sshconfigCiphers 3des-cbc
syn keyword sshconfigCiphers blowfish-cbc
syn keyword sshconfigCiphers cast128-cbc
syn keyword sshconfigCiphers arcfour
syn keyword sshconfigCiphers arcfour128
syn keyword sshconfigCiphers arcfour256
syn keyword sshconfigCiphers aes128-cbc
syn keyword sshconfigCiphers aes192-cbc
syn keyword sshconfigCiphers aes256-cbc
syn match sshconfigCiphers "\<rijndael-cbc@lysator\.liu.se\>"
syn keyword sshconfigCiphers aes128-ctr
syn keyword sshconfigCiphers aes192-ctr
syn keyword sshconfigCiphers aes256-ctr
syn match sshconfigCiphers "\<aes128-gcm@openssh\.com\>"
syn match sshconfigCiphers "\<aes256-gcm@openssh\.com\>"
syn match sshconfigCiphers "\<chacha20-poly1305@openssh\.com\>"

syn keyword sshconfigMAC hmac-sha1
syn keyword sshconfigMAC mac-sha1-96
syn keyword sshconfigMAC mac-sha2-256
syn keyword sshconfigMAC mac-sha2-512
syn keyword sshconfigMAC mac-md5
syn keyword sshconfigMAC mac-md5-96
syn keyword sshconfigMAC mac-ripemd160
syn match   sshconfigMAC "\<hmac-ripemd160@openssh\.com\>"
syn match   sshconfigMAC "\<umac-64@openssh\.com\>"
syn match   sshconfigMAC "\<umac-128@openssh\.com\>"
syn match   sshconfigMAC "\<hmac-sha1-etm@openssh\.com\>"
syn match   sshconfigMAC "\<hmac-sha1-96-etm@openssh\.com\>"
syn match   sshconfigMAC "\<hmac-sha2-256-etm@openssh\.com\>"
syn match   sshconfigMAC "\<hmac-sha2-512-etm@openssh\.com\>"
syn match   sshconfigMAC "\<hmac-md5-etm@openssh\.com\>"
syn match   sshconfigMAC "\<hmac-md5-96-etm@openssh\.com\>"
syn match   sshconfigMAC "\<hmac-ripemd160-etm@openssh\.com\>"
syn match   sshconfigMAC "\<umac-64-etm@openssh\.com\>"
syn match   sshconfigMAC "\<umac-128-etm@openssh\.com\>"

syn keyword sshconfigHostKeyAlgo ssh-ed25519
syn match sshconfigHostKeyAlgo "\<ssh-ed25519-cert-v01@openssh\.com\>"
syn keyword sshconfigHostKeyAlgo ssh-rsa
syn keyword sshconfigHostKeyAlgo ssh-dss
syn keyword sshconfigHostKeyAlgo ecdsa-sha2-nistp256
syn keyword sshconfigHostKeyAlgo ecdsa-sha2-nistp384
syn keyword sshconfigHostKeyAlgo ecdsa-sha2-nistp521
syn match sshconfigHostKeyAlgo "\<ssh-rsa-cert-v01@openssh\.com\>"
syn match sshconfigHostKeyAlgo "\<ssh-dss-cert-v01@openssh\.com\>"
syn match sshconfigHostKeyAlgo "\<ecdsa-sha2-nistp256-cert-v01@openssh\.com\>"
syn match sshconfigHostKeyAlgo "\<ecdsa-sha2-nistp384-cert-v01@openssh\.com\>"
syn match sshconfigHostKeyAlgo "\<ecdsa-sha2-nistp521-cert-v01@openssh\.com\>"

syn keyword sshconfigPreferredAuth hostbased publickey password gssapi-with-mic
syn keyword sshconfigPreferredAuth keyboard-interactive

syn keyword sshconfigLogLevel QUIET FATAL ERROR INFO VERBOSE
syn keyword sshconfigLogLevel DEBUG DEBUG1 DEBUG2 DEBUG3
syn keyword sshconfigSysLogFacility DAEMON USER AUTH AUTHPRIV LOCAL0 LOCAL1
syn keyword sshconfigSysLogFacility LOCAL2 LOCAL3 LOCAL4 LOCAL5 LOCAL6 LOCAL7
syn keyword sshconfigAddressFamily  inet inet6

syn match   sshconfigIPQoS	"af1[123]"
syn match   sshconfigIPQoS	"af2[123]"
syn match   sshconfigIPQoS	"af3[123]"
syn match   sshconfigIPQoS	"af4[123]"
syn match   sshconfigIPQoS	"cs[0-7]"
syn keyword sshconfigIPQoS	ef lowdelay throughput reliability
syn keyword sshconfigKbdInteractive bsdauth pam skey

syn keyword sshconfigKexAlgo diffie-hellman-group1-sha1
syn keyword sshconfigKexAlgo diffie-hellman-group14-sha1
syn keyword sshconfigKexAlgo diffie-hellman-group-exchange-sha1
syn keyword sshconfigKexAlgo diffie-hellman-group-exchange-sha256
syn keyword sshconfigKexAlgo ecdh-sha2-nistp256
syn keyword sshconfigKexAlgo ecdh-sha2-nistp384
syn keyword sshconfigKexAlgo ecdh-sha2-nistp521
syn match sshconfigKexAlgo "\<curve25519-sha256@libssh\.org\>"

syn keyword sshconfigTunnel	point-to-point ethernet

syn match sshconfigVar "%[rhplLdun]\>"
syn match sshconfigSpecial "[*?]"
syn match sshconfigNumber "\d\+"
syn match sshconfigHostPort "\<\(\d\{1,3}\.\)\{3}\d\{1,3}\(:\d\+\)\?\>"
syn match sshconfigHostPort "\<\([-a-zA-Z0-9]\+\.\)\+[-a-zA-Z0-9]\{2,}\(:\d\+\)\?\>"
syn match sshconfigHostPort "\<\(\x\{,4}:\)\+\x\{,4}[:/]\d\+\>"
syn match sshconfigHostPort "\(Host \)\@<=.\+"
syn match sshconfigHostPort "\(HostName \)\@<=.\+"

" case off
syn case ignore


" Keywords
syn keyword sshconfigHostSect Host

syn keyword sshconfigMatch canonical exec host originalhost user localuser all

syn keyword sshconfigKeyword AddressFamily
syn keyword sshconfigKeyword AddKeysToAgent
syn keyword sshconfigKeyword BatchMode
syn keyword sshconfigKeyword BindAddress
syn keyword sshconfigKeyword CanonicalDomains
syn keyword sshconfigKeyword CanonicalizeFallbackLocal
syn keyword sshconfigKeyword CanonicalizeHostname
syn keyword sshconfigKeyword CanonicalizeMaxDots
syn keyword sshconfigKeyword CertificateFile
syn keyword sshconfigKeyword ChallengeResponseAuthentication
syn keyword sshconfigKeyword CheckHostIP
syn keyword sshconfigKeyword Cipher
syn keyword sshconfigKeyword Ciphers
syn keyword sshconfigKeyword ClearAllForwardings
syn keyword sshconfigKeyword Compression
syn keyword sshconfigKeyword CompressionLevel
syn keyword sshconfigKeyword ConnectTimeout
syn keyword sshconfigKeyword ConnectionAttempts
syn keyword sshconfigKeyword ControlMaster
syn keyword sshconfigKeyword ControlPath
syn keyword sshconfigKeyword ControlPersist
syn keyword sshconfigKeyword DynamicForward
syn keyword sshconfigKeyword EnableSSHKeysign
syn keyword sshconfigKeyword EscapeChar
syn keyword sshconfigKeyword ExitOnForwardFailure
syn keyword sshconfigKeyword ForwardAgent
syn keyword sshconfigKeyword ForwardX11
syn keyword sshconfigKeyword ForwardX11Timeout
syn keyword sshconfigKeyword ForwardX11Trusted
syn keyword sshconfigKeyword GSSAPIAuthentication
syn keyword sshconfigKeyword GSSAPIClientIdentity
syn keyword sshconfigKeyword GSSAPIDelegateCredentials
syn keyword sshconfigKeyword GSSAPIKeyExchange
syn keyword sshconfigKeyword GSSAPIRenewalForcesRekey
syn keyword sshconfigKeyword GSSAPIServerIdentity
syn keyword sshconfigKeyword GSSAPITrustDNS
syn keyword sshconfigKeyword GSSAPITrustDns
syn keyword sshconfigKeyword GatewayPorts
syn keyword sshconfigKeyword GlobalKnownHostsFile
syn keyword sshconfigKeyword HashKnownHosts
syn keyword sshconfigKeyword HostKeyAlgorithms
syn keyword sshconfigKeyword HostKeyAlias
syn keyword sshconfigKeyword HostName
syn keyword sshconfigKeyword HostbasedAuthentication
syn keyword sshconfigKeyword HostbasedKeyTypes
syn keyword sshconfigKeyword IPQoS
syn keyword sshconfigKeyword IdentitiesOnly
syn keyword sshconfigKeyword IdentityFile
syn keyword sshconfigKeyword IgnoreUnknown
syn keyword sshconfigKeyword Include
syn keyword sshconfigKeyword IPQoS
syn keyword sshconfigKeyword KbdInteractiveAuthentication
syn keyword sshconfigKeyword KbdInteractiveDevices
syn keyword sshconfigKeyword KexAlgorithms
syn keyword sshconfigKeyword LocalCommand
syn keyword sshconfigKeyword LocalForward
syn keyword sshconfigKeyword LogLevel
syn keyword sshconfigKeyword MACs
syn keyword sshconfigKeyword Match
syn keyword sshconfigKeyword NoHostAuthenticationForLocalhost
syn keyword sshconfigKeyword NumberOfPasswordPrompts
syn keyword sshconfigKeyword PKCS11Provider
syn keyword sshconfigKeyword PasswordAuthentication
syn keyword sshconfigKeyword PermitLocalCommand
syn keyword sshconfigKeyword Port
syn keyword sshconfigKeyword PreferredAuthentications
syn keyword sshconfigKeyword Protocol
syn keyword sshconfigKeyword ProxyCommand
syn keyword sshconfigKeyword ProxyJump
syn keyword sshconfigKeyword ProxyUseFDPass
syn keyword sshconfigKeyword PubkeyAcceptedKeyTypes
syn keyword sshconfigKeyword PubkeyAuthentication
syn keyword sshconfigKeyword RSAAuthentication
syn keyword sshconfigKeyword RekeyLimit
syn keyword sshconfigKeyword RemoteForward
syn keyword sshconfigKeyword RequestTTY
syn keyword sshconfigKeyword RhostsRSAAuthentication
syn keyword sshconfigKeyword SendEnv
syn keyword sshconfigKeyword ServerAliveCountMax
syn keyword sshconfigKeyword ServerAliveInterval
syn keyword sshconfigKeyword SmartcardDevice
syn keyword sshconfigKeyword StrictHostKeyChecking
syn keyword sshconfigKeyword TCPKeepAlive
syn keyword sshconfigKeyword Tunnel
syn keyword sshconfigKeyword TunnelDevice
syn keyword sshconfigKeyword UseBlacklistedKeys
syn keyword sshconfigKeyword UsePrivilegedPort
syn keyword sshconfigKeyword User
syn keyword sshconfigKeyword UserKnownHostsFile
syn keyword sshconfigKeyword UseRoaming
syn keyword sshconfigKeyword VerifyHostKeyDNS
syn keyword sshconfigKeyword VisualHostKey
syn keyword sshconfigKeyword XAuthLocation

" Define the default highlighting

hi def link sshconfigComment        Comment
hi def link sshconfigTodo           Todo
hi def link sshconfigHostPort       sshconfigConstant
hi def link sshconfigNumber         sshconfigConstant
hi def link sshconfigConstant       Constant
hi def link sshconfigYesNo          sshconfigEnum
hi def link sshconfigCipher         sshconfigEnum
hi def link sshconfigCiphers	 sshconfigEnum
hi def link sshconfigMAC            sshconfigEnum
hi def link sshconfigHostKeyAlgo    sshconfigEnum
hi def link sshconfigLogLevel       sshconfigEnum
hi def link sshconfigSysLogFacility sshconfigEnum
hi def link sshconfigAddressFamily  sshconfigEnum
hi def link sshconfigIPQoS		 sshconfigEnum
hi def link sshconfigKbdInteractive sshconfigEnum
hi def link sshconfigKexAlgo	 sshconfigEnum
hi def link sshconfigTunnel	 sshconfigEnum
hi def link sshconfigPreferredAuth  sshconfigEnum
hi def link sshconfigVar            sshconfigEnum
hi def link sshconfigEnum           Identifier
hi def link sshconfigSpecial        Special
hi def link sshconfigKeyword        Keyword
hi def link sshconfigHostSect       Type
hi def link sshconfigMatch          Type

let b:current_syntax = "sshconfig"

" vim:set ts=8 sw=2 sts=2:
