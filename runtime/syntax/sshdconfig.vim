" Vim syntax file
" Language:	OpenSSH server configuration file (sshd_config)
" Author:	David Necas (Yeti)
" Maintainer:	Jakub Jelen <jakuje at gmail dot com>
" Previous Maintainer:	Dominik Fischer <d dot f dot fischer at web dot de>
" Contributor:	Thilo Six
" Contributor:  Leonard Ehrenfried <leonard.ehrenfried@web.de>	
" Contributor:  Karsten Hopp <karsten@redhat.com>
" Originally:	2009-07-09
" Last Change:	2020-10-20
" SSH Version:	8.4p1
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
syn match sshdconfigComment "^#.*$" contains=sshdconfigTodo
syn match sshdconfigComment "\s#.*$" contains=sshdconfigTodo

syn keyword sshdconfigTodo TODO FIXME NOTE contained

" Constants
syn keyword sshdconfigYesNo yes no none

syn keyword sshdconfigAddressFamily any inet inet6

syn keyword sshdconfigPrivilegeSeparation sandbox

syn keyword sshdconfigTcpForwarding local remote

syn keyword sshdconfigRootLogin prohibit-password without-password forced-commands-only

syn keyword sshdconfigCiphers 3des-cbc
syn keyword sshdconfigCiphers blowfish-cbc
syn keyword sshdconfigCiphers cast128-cbc
syn keyword sshdconfigCiphers arcfour
syn keyword sshdconfigCiphers arcfour128
syn keyword sshdconfigCiphers arcfour256
syn keyword sshdconfigCiphers aes128-cbc
syn keyword sshdconfigCiphers aes192-cbc
syn keyword sshdconfigCiphers aes256-cbc
syn match sshdconfigCiphers "\<rijndael-cbc@lysator\.liu.se\>"
syn keyword sshdconfigCiphers aes128-ctr
syn keyword sshdconfigCiphers aes192-ctr
syn keyword sshdconfigCiphers aes256-ctr
syn match sshdconfigCiphers "\<aes128-gcm@openssh\.com\>"
syn match sshdconfigCiphers "\<aes256-gcm@openssh\.com\>"
syn match sshdconfigCiphers "\<chacha20-poly1305@openssh\.com\>"

syn keyword sshdconfigMAC hmac-sha1
syn keyword sshdconfigMAC mac-sha1-96
syn keyword sshdconfigMAC mac-sha2-256
syn keyword sshdconfigMAC mac-sha2-512
syn keyword sshdconfigMAC mac-md5
syn keyword sshdconfigMAC mac-md5-96
syn keyword sshdconfigMAC mac-ripemd160
syn match   sshdconfigMAC "\<hmac-ripemd160@openssh\.com\>"
syn match   sshdconfigMAC "\<umac-64@openssh\.com\>"
syn match   sshdconfigMAC "\<umac-128@openssh\.com\>"
syn match   sshdconfigMAC "\<hmac-sha1-etm@openssh\.com\>"
syn match   sshdconfigMAC "\<hmac-sha1-96-etm@openssh\.com\>"
syn match   sshdconfigMAC "\<hmac-sha2-256-etm@openssh\.com\>"
syn match   sshdconfigMAC "\<hmac-sha2-512-etm@openssh\.com\>"
syn match   sshdconfigMAC "\<hmac-md5-etm@openssh\.com\>"
syn match   sshdconfigMAC "\<hmac-md5-96-etm@openssh\.com\>"
syn match   sshdconfigMAC "\<hmac-ripemd160-etm@openssh\.com\>"
syn match   sshdconfigMAC "\<umac-64-etm@openssh\.com\>"
syn match   sshdconfigMAC "\<umac-128-etm@openssh\.com\>"

syn keyword sshdconfigHostKeyAlgo ssh-ed25519
syn match sshdconfigHostKeyAlgo "\<ssh-ed25519-cert-v01@openssh\.com\>"
syn match sshdconfigHostKeyAlgo "\<sk-ssh-ed25519@openssh\.com\>"
syn match sshdconfigHostKeyAlgo "\<sk-ssh-ed25519-cert-v01@openssh\.com\>"
syn keyword sshdconfigHostKeyAlgo ssh-rsa
syn keyword sshdconfigHostKeyAlgo rsa-sha2-256
syn keyword sshdconfigHostKeyAlgo rsa-sha2-512
syn keyword sshdconfigHostKeyAlgo ssh-dss
syn keyword sshdconfigHostKeyAlgo ecdsa-sha2-nistp256
syn keyword sshdconfigHostKeyAlgo ecdsa-sha2-nistp384
syn keyword sshdconfigHostKeyAlgo ecdsa-sha2-nistp521
syn match sshdconfigHostKeyAlgo "\<ssh-rsa-cert-v01@openssh\.com\>"
syn match sshdconfigHostKeyAlgo "\<rsa-sha2-256-cert-v01@openssh\.com\>"
syn match sshdconfigHostKeyAlgo "\<rsa-sha2-512-cert-v01@openssh\.com\>"
syn match sshdconfigHostKeyAlgo "\<ssh-dss-cert-v01@openssh\.com\>"
syn match sshdconfigHostKeyAlgo "\<ecdsa-sha2-nistp256-cert-v01@openssh\.com\>"
syn match sshdconfigHostKeyAlgo "\<ecdsa-sha2-nistp384-cert-v01@openssh\.com\>"
syn match sshdconfigHostKeyAlgo "\<ecdsa-sha2-nistp521-cert-v01@openssh\.com\>"
syn match sshdconfigHostKeyAlgo "\<sk-ecdsa-sha2-nistp256@openssh\.com\>"
syn match sshdconfigHostKeyAlgo "\<sk-ecdsa-sha2-nistp256-cert-v01@openssh\.com\>"

syn keyword sshdconfigRootLogin prohibit-password without-password forced-commands-only

syn keyword sshdconfigLogLevel QUIET FATAL ERROR INFO VERBOSE
syn keyword sshdconfigLogLevel DEBUG DEBUG1 DEBUG2 DEBUG3
syn keyword sshdconfigSysLogFacility DAEMON USER AUTH AUTHPRIV LOCAL0 LOCAL1
syn keyword sshdconfigSysLogFacility LOCAL2 LOCAL3 LOCAL4 LOCAL5 LOCAL6 LOCAL7

syn keyword sshdconfigCompression    delayed

syn match   sshdconfigIPQoS	"af1[123]"
syn match   sshdconfigIPQoS	"af2[123]"
syn match   sshdconfigIPQoS	"af3[123]"
syn match   sshdconfigIPQoS	"af4[123]"
syn match   sshdconfigIPQoS	"cs[0-7]"
syn keyword sshdconfigIPQoS	ef lowdelay throughput reliability

syn keyword sshdconfigKexAlgo diffie-hellman-group1-sha1
syn keyword sshdconfigKexAlgo diffie-hellman-group14-sha1
syn keyword sshdconfigKexAlgo diffie-hellman-group14-sha256
syn keyword sshdconfigKexAlgo diffie-hellman-group16-sha512
syn keyword sshdconfigKexAlgo diffie-hellman-group18-sha512
syn keyword sshdconfigKexAlgo diffie-hellman-group-exchange-sha1
syn keyword sshdconfigKexAlgo diffie-hellman-group-exchange-sha256
syn keyword sshdconfigKexAlgo ecdh-sha2-nistp256
syn keyword sshdconfigKexAlgo ecdh-sha2-nistp384
syn keyword sshdconfigKexAlgo ecdh-sha2-nistp521
syn keyword sshdconfigKexAlgo curve25519-sha256
syn match sshdconfigKexAlgo "\<curve25519-sha256@libssh\.org\>"
syn match sshdconfigKexAlgo "\<sntrup4591761x25519-sha512@tinyssh\.org\>"

syn keyword sshdconfigTunnel	point-to-point ethernet

syn keyword sshdconfigSubsystem internal-sftp

syn match sshdconfigVar	    "%[hu]\>"
syn match sshdconfigVar	    "%%"

syn match sshdconfigSpecial "[*?]"

syn match sshdconfigNumber "\d\+"
syn match sshdconfigHostPort "\<\(\d\{1,3}\.\)\{3}\d\{1,3}\(:\d\+\)\?\>"
syn match sshdconfigHostPort "\<\([-a-zA-Z0-9]\+\.\)\+[-a-zA-Z0-9]\{2,}\(:\d\+\)\?\>"
" FIXME: this matches quite a few things which are NOT valid IPv6 addresses
syn match sshdconfigHostPort "\<\(\x\{,4}:\)\+\x\{,4}:\d\+\>"
syn match sshdconfigTime "\<\(\d\+[sSmMhHdDwW]\)\+\>"


" case off
syn case ignore


" Keywords
" Also includes RDomain, but that is a keyword.
syn keyword sshdconfigMatch Host User Group Address LocalAddress LocalPort

syn keyword sshdconfigKeyword AcceptEnv
syn keyword sshdconfigKeyword AddressFamily
syn keyword sshdconfigKeyword AllowAgentForwarding
syn keyword sshdconfigKeyword AllowGroups
syn keyword sshdconfigKeyword AllowStreamLocalForwarding
syn keyword sshdconfigKeyword AllowTcpForwarding
syn keyword sshdconfigKeyword AllowUsers
syn keyword sshdconfigKeyword AuthenticationMethods
syn keyword sshdconfigKeyword AuthorizedKeysFile
syn keyword sshdconfigKeyword AuthorizedKeysCommand
syn keyword sshdconfigKeyword AuthorizedKeysCommandUser
syn keyword sshdconfigKeyword AuthorizedPrincipalsCommand
syn keyword sshdconfigKeyword AuthorizedPrincipalsCommandUser
syn keyword sshdconfigKeyword AuthorizedPrincipalsFile
syn keyword sshdconfigKeyword Banner
syn keyword sshdconfigKeyword CASignatureAlgorithms
syn keyword sshdconfigKeyword ChallengeResponseAuthentication
syn keyword sshdconfigKeyword ChrootDirectory
syn keyword sshdconfigKeyword Ciphers
syn keyword sshdconfigKeyword ClientAliveCountMax
syn keyword sshdconfigKeyword ClientAliveInterval
syn keyword sshdconfigKeyword Compression
syn keyword sshdconfigKeyword DebianBanner
syn keyword sshdconfigKeyword DenyGroups
syn keyword sshdconfigKeyword DenyUsers
syn keyword sshdconfigKeyword DisableForwarding
syn keyword sshdconfigKeyword ExposeAuthInfo
syn keyword sshdconfigKeyword FingerprintHash
syn keyword sshdconfigKeyword ForceCommand
syn keyword sshdconfigKeyword GatewayPorts
syn keyword sshdconfigKeyword GSSAPIAuthentication
syn keyword sshdconfigKeyword GSSAPICleanupCredentials
syn keyword sshdconfigKeyword GSSAPIEnablek5users
syn keyword sshdconfigKeyword GSSAPIKeyExchange
syn keyword sshdconfigKeyword GSSAPIKexAlgorithms
syn keyword sshdconfigKeyword GSSAPIStoreCredentialsOnRekey
syn keyword sshdconfigKeyword GSSAPIStrictAcceptorCheck
syn keyword sshdconfigKeyword HostCertificate
syn keyword sshdconfigKeyword HostKey
syn keyword sshdconfigKeyword HostKeyAgent
syn keyword sshdconfigKeyword HostKeyAlgorithms
syn keyword sshdconfigKeyword HostbasedAcceptedKeyTypes
syn keyword sshdconfigKeyword HostbasedAuthentication
syn keyword sshdconfigKeyword HostbasedUsesNameFromPacketOnly
syn keyword sshdconfigKeyword IPQoS
syn keyword sshdconfigKeyword IgnoreRhosts
syn keyword sshdconfigKeyword IgnoreUserKnownHosts
syn keyword sshdconfigKeyword Include
syn keyword sshdconfigKeyword KbdInteractiveAuthentication
syn keyword sshdconfigKeyword KerberosAuthentication
syn keyword sshdconfigKeyword KerberosGetAFSToken
syn keyword sshdconfigKeyword KerberosOrLocalPasswd
syn keyword sshdconfigKeyword KerberosTicketCleanup
syn keyword sshdconfigKeyword KerberosUniqueCCache
syn keyword sshdconfigKeyword KerberosUseKuserok
syn keyword sshdconfigKeyword KexAlgorithms
syn keyword sshdconfigKeyword KeyRegenerationInterval
syn keyword sshdconfigKeyword ListenAddress
syn keyword sshdconfigKeyword LogLevel
syn keyword sshdconfigKeyword LoginGraceTime
syn keyword sshdconfigKeyword MACs
syn keyword sshdconfigKeyword Match
syn keyword sshdconfigKeyword MaxAuthTries
syn keyword sshdconfigKeyword MaxSessions
syn keyword sshdconfigKeyword MaxStartups
syn keyword sshdconfigKeyword PasswordAuthentication
syn keyword sshdconfigKeyword PermitBlacklistedKeys
syn keyword sshdconfigKeyword PermitEmptyPasswords
syn keyword sshdconfigKeyword PermitListen
syn keyword sshdconfigKeyword PermitOpen
syn keyword sshdconfigKeyword PermitRootLogin
syn keyword sshdconfigKeyword PermitTTY
syn keyword sshdconfigKeyword PermitTunnel
syn keyword sshdconfigKeyword PermitUserEnvironment
syn keyword sshdconfigKeyword PermitUserRC
syn keyword sshdconfigKeyword PidFile
syn keyword sshdconfigKeyword Port
syn keyword sshdconfigKeyword PrintLastLog
syn keyword sshdconfigKeyword PrintMotd
syn keyword sshdconfigKeyword Protocol
syn keyword sshdconfigKeyword PubkeyAcceptedKeyTypes
syn keyword sshdconfigKeyword PubkeyAuthentication
syn keyword sshdconfigKeyword PubkeyAuthOptions
syn keyword sshdconfigKeyword RSAAuthentication
syn keyword sshdconfigKeyword RekeyLimit
syn keyword sshdconfigKeyword RevokedKeys
syn keyword sshdconfigKeyword RDomain
syn keyword sshdconfigKeyword RhostsRSAAuthentication
syn keyword sshdconfigKeyword SecurityKeyProvider
syn keyword sshdconfigKeyword ServerKeyBits
syn keyword sshdconfigKeyword SetEnv
syn keyword sshdconfigKeyword ShowPatchLevel
syn keyword sshdconfigKeyword StrictModes
syn keyword sshdconfigKeyword StreamLocalBindMask
syn keyword sshdconfigKeyword StreamLocalBindUnlink
syn keyword sshdconfigKeyword Subsystem
syn keyword sshdconfigKeyword SyslogFacility
syn keyword sshdconfigKeyword TCPKeepAlive
syn keyword sshdconfigKeyword TrustedUserCAKeys
syn keyword sshdconfigKeyword UseDNS
syn keyword sshdconfigKeyword UseLogin
syn keyword sshdconfigKeyword UsePAM
syn keyword sshdconfigKeyword VersionAddendum
syn keyword sshdconfigKeyword X11DisplayOffset
syn keyword sshdconfigKeyword X11Forwarding
syn keyword sshdconfigKeyword X11MaxDisplays
syn keyword sshdconfigKeyword X11UseLocalhost
syn keyword sshdconfigKeyword XAuthLocation


" Define the default highlighting

hi def link sshdconfigComment              Comment
hi def link sshdconfigTodo                 Todo
hi def link sshdconfigHostPort             sshdconfigConstant
hi def link sshdconfigTime                 sshdconfigConstant
hi def link sshdconfigNumber               sshdconfigConstant
hi def link sshdconfigConstant             Constant
hi def link sshdconfigYesNo                sshdconfigEnum
hi def link sshdconfigAddressFamily        sshdconfigEnum
hi def link sshdconfigPrivilegeSeparation  sshdconfigEnum
hi def link sshdconfigTcpForwarding        sshdconfigEnum
hi def link sshdconfigRootLogin            sshdconfigEnum
hi def link sshdconfigCiphers              sshdconfigEnum
hi def link sshdconfigMAC                  sshdconfigEnum
hi def link sshdconfigHostKeyAlgo          sshdconfigEnum
hi def link sshdconfigRootLogin            sshdconfigEnum
hi def link sshdconfigLogLevel             sshdconfigEnum
hi def link sshdconfigSysLogFacility       sshdconfigEnum
hi def link sshdconfigVar                  sshdconfigEnum
hi def link sshdconfigCompression          sshdconfigEnum
hi def link sshdconfigIPQoS                sshdconfigEnum
hi def link sshdconfigKexAlgo              sshdconfigEnum
hi def link sshdconfigTunnel               sshdconfigEnum
hi def link sshdconfigSubsystem            sshdconfigEnum
hi def link sshdconfigEnum                 Function
hi def link sshdconfigSpecial              Special
hi def link sshdconfigKeyword              Keyword
hi def link sshdconfigMatch                Type

let b:current_syntax = "sshdconfig"

" vim:set ts=8 sw=2 sts=2:
