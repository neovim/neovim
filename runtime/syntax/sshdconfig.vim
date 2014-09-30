" Vim syntax file
" Language:	OpenSSH server configuration file (sshd_config)
" Maintainer:	David Necas (Yeti)
" Maintainer:   Leonard Ehrenfried <leonard.ehrenfried@web.de>	
" Modified By:	Thilo Six
" Originally:	2009-07-09
" Last Change:	2011 Oct 31 
" SSH Version:	5.9p1
"

" Setup
if version >= 600
  if exists("b:current_syntax")
    finish
  endif
else
  syntax clear
endif

if version >= 600
  setlocal iskeyword=_,-,a-z,A-Z,48-57
else
  set iskeyword=_,-,a-z,A-Z,48-57
endif


" case on
syn case match


" Comments
syn match sshdconfigComment "^#.*$" contains=sshdconfigTodo
syn match sshdconfigComment "\s#.*$" contains=sshdconfigTodo

syn keyword sshdconfigTodo TODO FIXME NOTE contained

" Constants
syn keyword sshdconfigYesNo yes no none

syn keyword sshdconfigAddressFamily any inet inet6

syn keyword sshdconfigCipher aes128-cbc 3des-cbc blowfish-cbc cast128-cbc
syn keyword sshdconfigCipher aes192-cbc aes256-cbc aes128-ctr aes192-ctr aes256-ctr
syn keyword sshdconfigCipher arcfour arcfour128 arcfour256 cast128-cbc

syn keyword sshdconfigMAC hmac-md5 hmac-sha1 hmac-ripemd160 hmac-sha1-96
syn keyword sshdconfigMAC hmac-md5-96
syn keyword sshdconfigMAC hmac-sha2-256 hmac-sha256-96 hmac-sha2-512
syn keyword sshdconfigMAC hmac-sha2-512-96
syn match   sshdconfigMAC "\<umac-64@openssh\.com\>"

syn keyword sshdconfigRootLogin without-password forced-commands-only

syn keyword sshdconfigLogLevel QUIET FATAL ERROR INFO VERBOSE
syn keyword sshdconfigLogLevel DEBUG DEBUG1 DEBUG2 DEBUG3
syn keyword sshdconfigSysLogFacility DAEMON USER AUTH AUTHPRIV LOCAL0 LOCAL1
syn keyword sshdconfigSysLogFacility LOCAL2 LOCAL3 LOCAL4 LOCAL5 LOCAL6 LOCAL7

syn keyword sshdconfigCompression    delayed

syn match   sshdconfigIPQoS	"af1[1234]"
syn match   sshdconfigIPQoS	"af2[23]"
syn match   sshdconfigIPQoS	"af3[123]"
syn match   sshdconfigIPQoS	"af4[123]"
syn match   sshdconfigIPQoS	"cs[0-7]"
syn keyword sshdconfigIPQoS	ef lowdelay throughput reliability

syn keyword sshdconfigKexAlgo	ecdh-sha2-nistp256 ecdh-sha2-nistp384 ecdh-sha2-nistp521
syn keyword sshdconfigKexAlgo	diffie-hellman-group-exchange-sha256
syn keyword sshdconfigKexAlgo	diffie-hellman-group-exchange-sha1
syn keyword sshdconfigKexAlgo	diffie-hellman-group14-sha1
syn keyword sshdconfigKexAlgo	diffie-hellman-group1-sha1

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
syn keyword sshdconfigMatch Host User Group Address

syn keyword sshdconfigKeyword AcceptEnv
syn keyword sshdconfigKeyword AddressFamily
syn keyword sshdconfigKeyword AllowAgentForwarding
syn keyword sshdconfigKeyword AllowGroups
syn keyword sshdconfigKeyword AllowTcpForwarding
syn keyword sshdconfigKeyword AllowUsers
syn keyword sshdconfigKeyword AuthorizedKeysFile
syn keyword sshdconfigKeyword AuthorizedPrincipalsFile
syn keyword sshdconfigKeyword Banner
syn keyword sshdconfigKeyword ChallengeResponseAuthentication
syn keyword sshdconfigKeyword ChrootDirectory
syn keyword sshdconfigKeyword Ciphers
syn keyword sshdconfigKeyword ClientAliveCountMax
syn keyword sshdconfigKeyword ClientAliveInterval
syn keyword sshdconfigKeyword Compression
syn keyword sshdconfigKeyword DebianBanner
syn keyword sshdconfigKeyword DenyGroups
syn keyword sshdconfigKeyword DenyUsers
syn keyword sshdconfigKeyword ForceCommand
syn keyword sshdconfigKeyword GSSAPIAuthentication
syn keyword sshdconfigKeyword GSSAPICleanupCredentials
syn keyword sshdconfigKeyword GSSAPIKeyExchange
syn keyword sshdconfigKeyword GSSAPIStoreCredentialsOnRekey
syn keyword sshdconfigKeyword GSSAPIStrictAcceptorCheck
syn keyword sshdconfigKeyword GatewayPorts
syn keyword sshdconfigKeyword HostCertificate
syn keyword sshdconfigKeyword HostKey
syn keyword sshdconfigKeyword HostbasedAuthentication
syn keyword sshdconfigKeyword HostbasedUsesNameFromPacketOnly
syn keyword sshdconfigKeyword IPQoS
syn keyword sshdconfigKeyword IgnoreRhosts
syn keyword sshdconfigKeyword IgnoreUserKnownHosts
syn keyword sshdconfigKeyword KbdInteractiveAuthentication
syn keyword sshdconfigKeyword KerberosAuthentication
syn keyword sshdconfigKeyword KerberosGetAFSToken
syn keyword sshdconfigKeyword KerberosOrLocalPasswd
syn keyword sshdconfigKeyword KerberosTicketCleanup
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
syn keyword sshdconfigKeyword PermitOpen
syn keyword sshdconfigKeyword PermitRootLogin
syn keyword sshdconfigKeyword PermitTunnel
syn keyword sshdconfigKeyword PermitUserEnvironment
syn keyword sshdconfigKeyword PidFile
syn keyword sshdconfigKeyword Port
syn keyword sshdconfigKeyword PrintLastLog
syn keyword sshdconfigKeyword PrintMotd
syn keyword sshdconfigKeyword Protocol
syn keyword sshdconfigKeyword PubkeyAuthentication
syn keyword sshdconfigKeyword RSAAuthentication
syn keyword sshdconfigKeyword RevokedKeys
syn keyword sshdconfigKeyword RhostsRSAAuthentication
syn keyword sshdconfigKeyword ServerKeyBits
syn keyword sshdconfigKeyword ShowPatchLevel
syn keyword sshdconfigKeyword StrictModes
syn keyword sshdconfigKeyword Subsystem
syn keyword sshdconfigKeyword SyslogFacility
syn keyword sshdconfigKeyword TCPKeepAlive
syn keyword sshdconfigKeyword TrustedUserCAKeys
syn keyword sshdconfigKeyword UseDNS
syn keyword sshdconfigKeyword UseLogin
syn keyword sshdconfigKeyword UsePAM
syn keyword sshdconfigKeyword UsePrivilegeSeparation
syn keyword sshdconfigKeyword X11DisplayOffset
syn keyword sshdconfigKeyword X11Forwarding
syn keyword sshdconfigKeyword X11UseLocalhost
syn keyword sshdconfigKeyword XAuthLocation


" Define the default highlighting
if version >= 508 || !exists("did_sshdconfig_syntax_inits")
  if version < 508
    let did_sshdconfig_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink sshdconfigComment        Comment
  HiLink sshdconfigTodo           Todo
  HiLink sshdconfigHostPort       sshdconfigConstant
  HiLink sshdconfigTime           sshdconfigConstant
  HiLink sshdconfigNumber         sshdconfigConstant
  HiLink sshdconfigConstant       Constant
  HiLink sshdconfigYesNo          sshdconfigEnum
  HiLink sshdconfigAddressFamily  sshdconfigEnum
  HiLink sshdconfigCipher         sshdconfigEnum
  HiLink sshdconfigMAC            sshdconfigEnum
  HiLink sshdconfigRootLogin      sshdconfigEnum
  HiLink sshdconfigLogLevel       sshdconfigEnum
  HiLink sshdconfigSysLogFacility sshdconfigEnum
  HiLink sshdconfigVar		  sshdconfigEnum
  HiLink sshdconfigCompression    sshdconfigEnum
  HiLink sshdconfigIPQoS	  sshdconfigEnum
  HiLink sshdconfigKexAlgo	  sshdconfigEnum
  HiLink sshdconfigTunnel	  sshdconfigEnum
  HiLink sshdconfigSubsystem	  sshdconfigEnum
  HiLink sshdconfigEnum           Function
  HiLink sshdconfigSpecial        Special
  HiLink sshdconfigKeyword        Keyword
  HiLink sshdconfigMatch          Type
  delcommand HiLink
endif

let b:current_syntax = "sshdconfig"

" vim:set ts=8 sw=2 sts=2:
