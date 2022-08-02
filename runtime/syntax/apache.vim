" Vim syntax file
" Language: Apache configuration (httpd.conf, srm.conf, access.conf, .htaccess)
" Maintainer: David Necas (Yeti) <yeti@physics.muni.cz>
" License: This file can be redistribued and/or modified under the same terms
"		as Vim itself.
" Last Change: 2022 Apr 25
" Notes: Last synced with apache-2.2.3, version 1.x is no longer supported
" TODO: see particular FIXME's scattered through the file
"		make it really linewise?
"		+ add `display' where appropriate

" quit when a syntax file was already loaded
if exists("b:current_syntax")
	finish
endif

syn case ignore

" Base constructs
syn match apacheComment "^\s*#.*$" contains=apacheFixme
syn match apacheUserID "#-\?\d\+\>"
syn case match
syn keyword apacheFixme FIXME TODO XXX NOT
syn case ignore
syn match apacheAnything "\s[^>]*" contained
syn match apacheError "\w\+" contained
syn region apacheString start=+"+ end=+"+ skip=+\\\\\|\\\"+ oneline

" Following is to prevent escaped quotes from being parsed as strings.
syn match apacheSkipQuote +\\"+

" Core and mpm
syn keyword apacheDeclaration AccessFileName AddDefaultCharset AllowOverride AuthName AuthType ContentDigest DefaultType DocumentRoot ErrorDocument ErrorLog HostNameLookups IdentityCheck Include KeepAlive KeepAliveTimeout LimitRequestBody LimitRequestFields LimitRequestFieldsize LimitRequestLine LogLevel MaxKeepAliveRequests NameVirtualHost Options Require RLimitCPU RLimitMEM RLimitNPROC Satisfy ScriptInterpreterSource ServerAdmin ServerAlias ServerName ServerPath ServerRoot ServerSignature ServerTokens TimeOut UseCanonicalName
syn keyword apacheDeclaration AcceptPathInfo CGIMapExtension EnableMMAP FileETag ForceType LimitXMLRequestBody SetHandler SetInputFilter SetOutputFilter
syn keyword apacheDeclaration AcceptFilter AllowEncodedSlashes EnableSendfile LimitInternalRecursion TraceEnable
syn keyword apacheOption INode MTime Size
syn keyword apacheOption Any All On Off Double EMail DNS Min Minimal OS Prod ProductOnly Full
syn keyword apacheOption emerg alert crit error warn notice info debug
syn keyword apacheOption registry script inetd standalone
syn match apacheOptionOption "[+-]\?\<\(ExecCGI\|FollowSymLinks\|Includes\|IncludesNoExec\|Indexes\|MultiViews\|SymLinksIfOwnerMatch\)\>"
syn keyword apacheOption user group
syn match apacheOption "\<valid-user\>"
syn case match
syn keyword apacheMethodOption GET POST PUT DELETE CONNECT OPTIONS TRACE PATCH PROPFIND PROPPATCH MKCOL COPY MOVE LOCK UNLOCK contained
" Added as suggested by Mikko Koivunalho
syn keyword apacheMethodOption BASELINE-CONTROL CHECKIN CHECKOUT LABEL MERGE MKACTIVITY MKWORKSPACE REPORT UNCHECKOUT UPDATE VERSION-CONTROL contained
syn case ignore
syn match apacheSection "<\/\=\(Directory\|DirectoryMatch\|Files\|FilesMatch\|IfModule\|IfDefine\|Location\|LocationMatch\|VirtualHost\)[^>]*>" contains=apacheAnything
syn match apacheSection "<\/\=\(RequireAll\|RequireAny\|RequireNone\)>" contains=apacheAnything
syn match apacheLimitSection "<\/\=\(Limit\|LimitExcept\)[^>]*>" contains=apacheLimitSectionKeyword,apacheMethodOption,apacheError
syn keyword apacheLimitSectionKeyword Limit LimitExcept contained
syn match apacheAuthType "AuthType\s.*$" contains=apacheAuthTypeValue
syn keyword apacheAuthTypeValue Basic Digest
syn match apacheAllowOverride "AllowOverride\s.*$" contains=apacheAllowOverrideValue,apacheComment
syn keyword apacheAllowOverrideValue AuthConfig FileInfo Indexes Limit Options contained
syn keyword apacheDeclaration CoreDumpDirectory EnableExceptionHook GracefulShutdownTimeout Group Listen ListenBacklog LockFile MaxClients MaxMemFree MaxRequestsPerChild MaxSpareThreads MaxSpareThreadsPerChild MinSpareThreads NumServers PidFile ScoreBoardFile SendBufferSize ServerLimit StartServers StartThreads ThreadLimit ThreadsPerChild User
syn keyword apacheDeclaration MaxThreads ThreadStackSize
syn keyword apacheDeclaration Win32DisableAcceptEx
syn keyword apacheDeclaration AssignUserId ChildPerUserId
syn keyword apacheDeclaration AcceptMutex MaxSpareServers MinSpareServers
syn keyword apacheOption flock fcntl sysvsem pthread

" Modules
syn keyword apacheDeclaration Action Script
syn keyword apacheDeclaration Alias AliasMatch Redirect RedirectMatch RedirectTemp RedirectPermanent ScriptAlias ScriptAliasMatch
syn keyword apacheOption permanent temp seeother gone
syn keyword apacheDeclaration AuthAuthoritative AuthGroupFile AuthUserFile
syn keyword apacheDeclaration AuthBasicAuthoritative AuthBasicProvider
syn keyword apacheDeclaration AuthDigestAlgorithm AuthDigestDomain AuthDigestNcCheck AuthDigestNonceFormat AuthDigestNonceLifetime AuthDigestProvider AuthDigestQop AuthDigestShmemSize
syn keyword apacheOption none auth auth-int MD5 MD5-sess
syn match apacheSection "<\/\=\(<AuthnProviderAlias\)[^>]*>" contains=apacheAnything
syn keyword apacheDeclaration Anonymous Anonymous_Authoritative Anonymous_LogEmail Anonymous_MustGiveEmail Anonymous_NoUserID Anonymous_VerifyEmail
syn keyword apacheDeclaration AuthDBDUserPWQuery AuthDBDUserRealmQuery
syn keyword apacheDeclaration AuthDBMGroupFile AuthDBMAuthoritative
syn keyword apacheDeclaration AuthDBM TypeAuthDBMUserFile
syn keyword apacheOption default SDBM GDBM NDBM DB
syn keyword apacheDeclaration AuthDefaultAuthoritative
syn keyword apacheDeclaration AuthUserFile
syn keyword apacheDeclaration AuthLDAPBindON AuthLDAPEnabled AuthLDAPFrontPageHack AuthLDAPStartTLS
syn keyword apacheDeclaration AuthLDAPBindDN AuthLDAPBindPassword AuthLDAPCharsetConfig AuthLDAPCompareDNOnServer AuthLDAPDereferenceAliases AuthLDAPGroupAttribute AuthLDAPGroupAttributeIsDN AuthLDAPRemoteUserIsDN AuthLDAPUrl AuthzLDAPAuthoritative
syn keyword apacheOption always never searching finding
syn keyword apacheOption ldap-user ldap-group ldap-dn ldap-attribute ldap-filter
syn keyword apacheDeclaration AuthDBMGroupFile AuthzDBMAuthoritative AuthzDBMType
syn keyword apacheDeclaration AuthzDefaultAuthoritative
syn keyword apacheDeclaration AuthGroupFile AuthzGroupFileAuthoritative
syn match apacheAllowDeny "Allow\s\+from.*$" contains=apacheAllowDenyValue,apacheComment
syn match apacheAllowDeny "Deny\s\+from.*$" contains=apacheAllowDenyValue,apacheComment
syn keyword apacheAllowDenyValue All None contained
syn match apacheOrder "^\s*Order\s.*$" contains=apacheOrderValue,apacheComment
syn keyword apacheOrderValue Deny Allow contained
syn keyword apacheDeclaration  AuthzOwnerAuthoritative
syn keyword apacheDeclaration  AuthzUserAuthoritative
syn keyword apacheDeclaration AddAlt AddAltByEncoding AddAltByType AddDescription AddIcon AddIconByEncoding AddIconByType DefaultIcon HeaderName IndexIgnore IndexOptions IndexOrderDefault ReadmeName
syn keyword apacheDeclaration IndexStyleSheet
syn keyword apacheOption DescriptionWidth FancyIndexing FoldersFirst IconHeight IconsAreLinks IconWidth NameWidth ScanHTMLTitles SuppressColumnSorting SuppressDescription SuppressHTMLPreamble SuppressLastModified SuppressSize TrackModified
syn keyword apacheOption Ascending Descending Name Date Size Description
syn keyword apacheOption HTMLTable SuppressIcon SuppressRules VersionSort XHTML
syn keyword apacheOption IgnoreClient IgnoreCase ShowForbidden SuppresRules
syn keyword apacheDeclaration CacheForceCompletion CacheMaxStreamingBuffer
syn keyword apacheDeclaration CacheDefaultExpire CacheDisable CacheEnable CacheIgnoreCacheControl CacheIgnoreHeaders CacheIgnoreNoLastMod CacheLastModifiedFactor CacheMaxExpire CacheStoreNoStore CacheStorePrivate
syn keyword apacheDeclaration MetaFiles MetaDir MetaSuffix
syn keyword apacheDeclaration ScriptLog ScriptLogLength ScriptLogBuffer
syn keyword apacheDeclaration ScriptStock
syn keyword apacheDeclaration CharsetDefault CharsetOptions CharsetSourceEnc
syn keyword apacheOption DebugLevel ImplicitAdd NoImplicitAdd
syn keyword apacheDeclaration Dav DavDepthInfinity DavMinTimeout
syn keyword apacheDeclaration DavLockDB
syn keyword apacheDeclaration DavGenericLockDB
syn keyword apacheDeclaration DBDExptime DBDKeep DBDMax DBDMin DBDParams DBDPersist DBDPrepareSQL DBDriver
syn keyword apacheDeclaration DeflateCompressionLevel DeflateBufferSize DeflateFilterNote DeflateMemLevel DeflateWindowSize
syn keyword apacheDeclaration DirectoryIndex DirectorySlash
syn keyword apacheDeclaration CacheExpiryCheck CacheGcClean CacheGcDaily CacheGcInterval CacheGcMemUsage CacheGcUnused CacheSize CacheTimeMargin
syn keyword apacheDeclaration CacheDirLength CacheDirLevels CacheMaxFileSize CacheMinFileSize CacheRoot
syn keyword apacheDeclaration DumpIOInput DumpIOOutput
syn keyword apacheDeclaration ProtocolEcho
syn keyword apacheDeclaration PassEnv SetEnv UnsetEnv
syn keyword apacheDeclaration Example
syn keyword apacheDeclaration ExpiresActive ExpiresByType ExpiresDefault
syn keyword apacheDeclaration ExtFilterDefine ExtFilterOptions
syn keyword apacheOption PreservesContentLength DebugLevel LogStderr NoLogStderr
syn match apacheOption "\<\(cmd\|mode\|intype\|outtype\|ftype\|disableenv\|enableenv\)\ze="
syn keyword apacheDeclaration CacheFile MMapFile
syn keyword apacheDeclaration FilterChain FilterDeclare FilterProtocol FilterProvider FilterTrace
syn keyword apacheDeclaration Header
syn keyword apacheDeclaration RequestHeader
syn keyword apacheOption set unset append add
syn keyword apacheDeclaration IdentityCheck IdentityCheckTimeout
syn keyword apacheDeclaration ImapMenu ImapDefault ImapBase
syn keyword apacheOption none formatted semiformatted unformatted
syn keyword apacheOption nocontent referer error map
syn keyword apacheDeclaration SSIEndTag SSIErrorMsg SSIStartTag SSITimeFormat SSIUndefinedEcho XBitHack
syn keyword apacheOption on off full
syn keyword apacheDeclaration AddModuleInfo
syn keyword apacheDeclaration ISAPIReadAheadBuffer ISAPILogNotSupported ISAPIAppendLogToErrors ISAPIAppendLogToQuery
syn keyword apacheDeclaration ISAPICacheFile ISAIPFakeAsync
syn keyword apacheDeclaration LDAPCertDBPath
syn keyword apacheDeclaration LDAPCacheEntries LDAPCacheTTL LDAPConnectionTimeout LDAPOpCacheEntries LDAPOpCacheTTL LDAPSharedCacheFile LDAPSharedCacheSize LDAPTrustedClientCert LDAPTrustedGlobalCert LDAPTrustedMode LDAPVerifyServerCert
syn keyword apacheOption CA_DER CA_BASE64 CA_CERT7_DB CA_SECMOD CERT_DER CERT_BASE64 CERT_KEY3_DB CERT_NICKNAME CERT_PFX KEY_DER KEY_BASE64 KEY_PFX
syn keyword apacheDeclaration BufferedLogs CookieLog CustomLog LogFormat TransferLog
syn keyword apacheDeclaration ForensicLog
syn keyword apacheDeclaration MCacheMaxObjectCount MCacheMaxObjectSize MCacheMaxStreamingBuffer MCacheMinObjectSize MCacheRemovalAlgorithm MCacheSize
syn keyword apacheDeclaration AddCharset AddEncoding AddHandler AddLanguage AddType DefaultLanguage RemoveEncoding RemoveHandler RemoveType TypesConfig
syn keyword apacheDeclaration AddInputFilter AddOutputFilter ModMimeUsePathInfo MultiviewsMatch RemoveInputFilter RemoveOutputFilter RemoveCharset
syn keyword apacheOption NegotiatedOnly Filters Handlers
syn keyword apacheDeclaration MimeMagicFile
syn keyword apacheDeclaration MMapFile
syn keyword apacheDeclaration CacheNegotiatedDocs LanguagePriority ForceLanguagePriority
syn keyword apacheDeclaration NWSSLTrustedCerts NWSSLUpgradeable SecureListen
syn keyword apacheDeclaration PerlModule PerlRequire PerlTaintCheck PerlWarn
syn keyword apacheDeclaration PerlSetVar PerlSetEnv PerlPassEnv PerlSetupEnv
syn keyword apacheDeclaration PerlInitHandler PerlPostReadRequestHandler PerlHeaderParserHandler
syn keyword apacheDeclaration PerlTransHandler PerlAccessHandler PerlAuthenHandler PerlAuthzHandler
syn keyword apacheDeclaration PerlTypeHandler PerlFixupHandler PerlHandler PerlLogHandler
syn keyword apacheDeclaration PerlCleanupHandler PerlChildInitHandler PerlChildExitHandler
syn keyword apacheDeclaration PerlRestartHandler PerlDispatchHandler
syn keyword apacheDeclaration PerlFreshRestart PerlSendHeader
syn keyword apacheDeclaration php_value php_flag php_admin_value php_admin_flag
syn match apacheSection "<\/\=\(Proxy\|ProxyMatch\)[^>]*>" contains=apacheAnything
syn keyword apacheDeclaration AllowCONNECT NoProxy ProxyBadHeader ProxyBlock ProxyDomain ProxyErrorOverride ProxyIOBufferSize ProxyMaxForwards ProxyPass ProxyPassMatch ProxyPassReverse ProxyPassReverseCookieDomain ProxyPassReverseCookiePath ProxyPreserveHost ProxyReceiveBufferSize ProxyRemote ProxyRemoteMatch ProxyRequests ProxyTimeout ProxyVia
syn keyword apacheDeclaration RewriteBase RewriteCond RewriteEngine RewriteLock RewriteLog RewriteLogLevel RewriteMap RewriteOptions RewriteRule
syn keyword apacheOption inherit
syn keyword apacheDeclaration BrowserMatch BrowserMatchNoCase SetEnvIf SetEnvIfNoCase
syn keyword apacheDeclaration LoadFile LoadModule
syn keyword apacheDeclaration CheckSpelling CheckCaseOnly
syn keyword apacheDeclaration SSLCACertificateFile SSLCACertificatePath SSLCADNRequestFile SSLCADNRequestPath SSLCARevocationFile SSLCARevocationPath SSLCertificateChainFile SSLCertificateFile SSLCertificateKeyFile SSLCipherSuite SSLCompression SSLCryptoDevice SSLEngine SSLFIPS SSLHonorCipherOrder SSLInsecureRenegotiation SSLMutex SSLOptions SSLPassPhraseDialog SSLProtocol SSLProxyCACertificateFile SSLProxyCACertificatePath SSLProxyCARevocationFile SSLProxyCARevocationPath SSLProxyCheckPeerCN SSLProxyCheckPeerExpire SSLProxyCipherSuite SSLProxyEngine SSLProxyMachineCertificateChainFile SSLProxyMachineCertificateFile SSLProxyMachineCertificatePath SSLProxyProtocol SSLProxyVerify SSLProxyVerifyDepth SSLRandomSeed SSLRenegBufferSize SSLRequire SSLRequireSSL SSLSessionCache SSLSessionCacheTimeout SSLSessionTicketKeyFile SSLSessionTickets SSLStrictSNIVHostCheck SSLUserName SSLVerifyClient SSLVerifyDepth
syn match apacheOption "[+-]\?\<\(StdEnvVars\|CompatEnvVars\|ExportCertData\|FakeBasicAuth\|StrictRequire\|OptRenegotiate\)\>"
syn keyword apacheOption builtin sem
syn match apacheOption "\(file\|exec\|egd\|dbm\|shm\):"
syn match apacheOption "[+-]\?\<\(SSLv2\|SSLv3\|TLSv1\|kRSA\|kHDr\|kDHd\|kEDH\|aNULL\|aRSA\|aDSS\|aRH\|eNULL\|DES\|3DES\|RC2\|RC4\|IDEA\|MD5\|SHA1\|SHA\|EXP\|EXPORT40\|EXPORT56\|LOW\|MEDIUM\|HIGH\|RSA\|DH\|EDH\|ADH\|DSS\|NULL\)\>"
syn keyword apacheOption optional optional_no_ca
syn keyword apacheDeclaration ExtendedStatus
syn keyword apacheDeclaration SuexecUserGroup
syn keyword apacheDeclaration UserDir
syn keyword apacheDeclaration CookieDomain CookieExpires CookieName CookieStyle CookieTracking
syn keyword apacheOption Netscape Cookie Cookie2 RFC2109 RFC2965
syn match apacheSection "<\/\=\(<IfVersion\)[^>]*>" contains=apacheAnything
syn keyword apacheDeclaration VirtualDocumentRoot VirtualDocumentRootIP VirtualScriptAlias VirtualScriptAliasIP

" Define the default highlighting

hi def link apacheAllowOverride apacheDeclaration
hi def link apacheAllowOverrideValue apacheOption
hi def link apacheAuthType apacheDeclaration
hi def link apacheAuthTypeValue apacheOption
hi def link apacheOptionOption apacheOption
hi def link apacheDeclaration Function
hi def link apacheAnything apacheOption
hi def link apacheOption Number
hi def link apacheComment Comment
hi def link apacheFixme Todo
hi def link apacheLimitSectionKeyword apacheLimitSection
hi def link apacheLimitSection apacheSection
hi def link apacheSection Label
hi def link apacheMethodOption Type
hi def link apacheAllowDeny Include
hi def link apacheAllowDenyValue Identifier
hi def link apacheOrder Special
hi def link apacheOrderValue String
hi def link apacheString String
hi def link apacheError Error
hi def link apacheUserID Number


let b:current_syntax = "apache"
