" Vim syntax file
" Language:	OpenSSH client configuration file (ssh_config)
" Author:	David Necas (Yeti)
" Maintainer:   Leonard Ehrenfried <leonard.ehrenfried@web.de>	
" Last Change:	2012 Feb 24 
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
syn match sshconfigComment "^#.*$" contains=sshconfigTodo
syn match sshconfigComment "\s#.*$" contains=sshconfigTodo

syn keyword sshconfigTodo TODO FIXME NOTE contained


" Constants
syn keyword sshconfigYesNo yes no ask
syn keyword sshconfigYesNo any auto
syn keyword sshconfigYesNo force autoask none

syn keyword sshconfigCipher  3des blowfish
syn keyword sshconfigCiphers aes128-cbc 3des-cbc blowfish blowfish-cbc cast128-cbc
syn keyword sshconfigCiphers aes192-cbc aes256-cbc aes128-ctr aes192-ctr aes256-ctr
syn keyword sshconfigCiphers arcfour arcfour128 arcfour256 cast128-cbc

syn keyword sshconfigMAC hmac-md5 hmac-sha1 hmac-ripemd160 hmac-sha1-96
syn keyword sshconfigMAC hmac-md5-96
syn keyword sshconfigMAC hmac-sha2-256 hmac-sha2-256-96 hmac-sha2-512
syn keyword sshconfigMAC hmac-sha2-512-96
syn match   sshconfigMAC "\<umac-64@openssh\.com\>"

syn keyword sshconfigHostKeyAlg ssh-rsa ssh-dss
syn match   sshconfigHostKeyAlg "\<ecdsa-sha2-nistp256-cert-v01@openssh\.com\>"
syn match   sshconfigHostKeyAlg "\<ecdsa-sha2-nistp384-cert-v01@openssh\.com\>"
syn match   sshconfigHostKeyAlg "\<ecdsa-sha2-nistp521-cert-v01@openssh\.com\>"
syn match   sshconfigHostKeyAlg "\<ssh-rsa-cert-v01@openssh\.com\>"
syn match   sshconfigHostKeyAlg "\<ssh-dss-cert-v01@openssh\.com\>"
syn match   sshconfigHostKeyAlg "\<ssh-rsa-cert-v00@openssh\.com\>"
syn match   sshconfigHostKeyAlg "\<ssh-dss-cert-v00@openssh\.com\>"
syn keyword sshconfigHostKeyAlg ecdsa-sha2-nistp256 ecdsa-sha2-nistp384 ecdsa-sha2-nistp521

syn keyword sshconfigPreferredAuth hostbased publickey password gssapi-with-mic
syn keyword sshconfigPreferredAuth keyboard-interactive

syn keyword sshconfigLogLevel QUIET FATAL ERROR INFO VERBOSE
syn keyword sshconfigLogLevel DEBUG DEBUG1 DEBUG2 DEBUG3
syn keyword sshconfigSysLogFacility DAEMON USER AUTH AUTHPRIV LOCAL0 LOCAL1
syn keyword sshconfigSysLogFacility LOCAL2 LOCAL3 LOCAL4 LOCAL5 LOCAL6 LOCAL7
syn keyword sshconfigAddressFamily  inet inet6

syn match   sshconfigIPQoS	"af1[1234]"
syn match   sshconfigIPQoS	"af2[23]"
syn match   sshconfigIPQoS	"af3[123]"
syn match   sshconfigIPQoS	"af4[123]"
syn match   sshconfigIPQoS	"cs[0-7]"
syn keyword sshconfigIPQoS	ef lowdelay throughput reliability
syn keyword sshconfigKbdInteractive bsdauth pam skey

syn keyword sshconfigKexAlgo	ecdh-sha2-nistp256 ecdh-sha2-nistp384 ecdh-sha2-nistp521
syn keyword sshconfigKexAlgo	diffie-hellman-group-exchange-sha256
syn keyword sshconfigKexAlgo	diffie-hellman-group-exchange-sha1
syn keyword sshconfigKexAlgo	diffie-hellman-group14-sha1
syn keyword sshconfigKexAlgo	diffie-hellman-group1-sha1

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

syn keyword sshconfigKeyword AddressFamily
syn keyword sshconfigKeyword BatchMode
syn keyword sshconfigKeyword BindAddress
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
syn keyword sshconfigKeyword IPQoS
syn keyword sshconfigKeyword IdentitiesOnly
syn keyword sshconfigKeyword IdentityFile
syn keyword sshconfigKeyword KbdInteractiveAuthentication
syn keyword sshconfigKeyword KbdInteractiveDevices
syn keyword sshconfigKeyword KexAlgorithms
syn keyword sshconfigKeyword LocalCommand
syn keyword sshconfigKeyword LocalForward
syn keyword sshconfigKeyword LogLevel
syn keyword sshconfigKeyword MACs
syn keyword sshconfigKeyword NoHostAuthenticationForLocalhost
syn keyword sshconfigKeyword NumberOfPasswordPrompts
syn keyword sshconfigKeyword PKCS11Provider
syn keyword sshconfigKeyword PasswordAuthentication
syn keyword sshconfigKeyword PermitLocalCommand
syn keyword sshconfigKeyword Port
syn keyword sshconfigKeyword PreferredAuthentications
syn keyword sshconfigKeyword Protocol
syn keyword sshconfigKeyword ProxyCommand
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
syn keyword sshconfigKeyword VerifyHostKeyDNS
syn keyword sshconfigKeyword VisualHostKey
syn keyword sshconfigKeyword XAuthLocation

" Define the default highlighting
if version >= 508 || !exists("did_sshconfig_syntax_inits")
  if version < 508
    let did_sshconfig_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink sshconfigComment        Comment
  HiLink sshconfigTodo           Todo
  HiLink sshconfigHostPort       sshconfigConstant
  HiLink sshconfigNumber         sshconfigConstant
  HiLink sshconfigConstant       Constant
  HiLink sshconfigYesNo          sshconfigEnum
  HiLink sshconfigCipher         sshconfigEnum
  HiLink sshconfigCiphers	 sshconfigEnum
  HiLink sshconfigMAC            sshconfigEnum
  HiLink sshconfigHostKeyAlg     sshconfigEnum
  HiLink sshconfigLogLevel       sshconfigEnum
  HiLink sshconfigSysLogFacility sshconfigEnum
  HiLink sshconfigAddressFamily  sshconfigEnum
  HiLink sshconfigIPQoS		 sshconfigEnum
  HiLink sshconfigKbdInteractive sshconfigEnum
  HiLink sshconfigKexAlgo	 sshconfigEnum
  HiLink sshconfigTunnel	 sshconfigEnum
  HiLink sshconfigPreferredAuth  sshconfigEnum
  HiLink sshconfigVar            sshconfigEnum
  HiLink sshconfigEnum           Identifier
  HiLink sshconfigSpecial        Special
  HiLink sshconfigKeyword        Keyword
  HiLink sshconfigHostSect       Type
  delcommand HiLink
endif

let b:current_syntax = "sshconfig"

" vim:set ts=8 sw=2 sts=2:
