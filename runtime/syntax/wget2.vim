" Vim syntax file
" Language:	Wget2 configuration file (/etc/wget2rc ~/.wget2rc)
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2023 Nov 05

" GNU Wget2 2.1.0 - multithreaded metalink/file/website downloader

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn match wget2Comment "#.*" contains=wget2Todo contained

syn keyword wget2Todo TODO NOTE FIXME XXX contained

syn region wget2String start=+"+ skip=+\\\\\|\\"+ end=+"+ contained oneline
syn region wget2String start=+'+ skip=+\\\\\|\\'+ end=+'+ contained oneline

syn case ignore

syn keyword wget2Boolean on off yes no y n contained
syn keyword wget2Number	 infinity inf	   contained
syn match   wget2Number "\<\d\+>"	   contained
syn match   wget2Quota	"\<\d\+[kmgt]\>"   contained
syn match   wget2Time	"\<\d\+[smhd]\>"   contained

"{{{ Commands
let s:commands =<< trim EOL
  accept
  accept-regex
  adjust-extension
  append-output
  ask-password
  auth-no-challenge
  background
  backup-converted
  backups
  base
  bind-address
  bind-interface
  body-data
  body-file
  ca-certificate
  ca-directory
  cache
  certificate
  certificate-type
  check-certificate
  check-hostname
  chunk-size
  clobber
  compression
  config
  connect-timeout
  content-disposition
  content-on-error
  continue
  convert-file-only
  convert-links
  cookie-suffixes
  cookies
  crl-file
  cut-dirs
  cut-file-get-vars
  cut-url-get-vars
  dane
  debug
  default-http-port
  default-https-port
  default-page
  delete-after
  directories
  directory-prefix
  dns-cache
  dns-cache-preload
  dns-timeout
  domains
  download-attr
  egd-file
  exclude-directories
  exclude-domains
  execute
  filter-mime-type
  filter-urls
  follow-sitemaps
  follow-tags
  force-atom
  force-css
  force-directories
  force-html
  force-metalink
  force-progress
  force-rss
  force-sitemap
  fsync-policy
  gnupg-homedir
  header
  help
  host-directories
  hpkp
  hpkp-file
  hsts
  hsts-file
  hsts-preload
  hsts-preload-file
  html-extension
  http-keep-alive
  http-password
  http-proxy
  http-proxy-password
  http-proxy-user
  http-user
  http2
  http2-only
  http2-request-window
  https-enforce
  https-only
  https-proxy
  hyperlink
  if-modified-since
  ignore-case
  ignore-length
  ignore-tags
  include-directories
  inet4-only
  inet6-only
  input-encoding
  input-file
  keep-extension
  keep-session-cookies
  level
  limit-rate
  list-plugins
  load-cookies
  local-db
  local-encoding
  local-plugin
  max-redirect
  max-threads
  metalink
  method
  mirror
  netrc
  netrc-file
  ocsp
  ocsp-date
  ocsp-file
  ocsp-nonce
  ocsp-server
  ocsp-stapling
  output-document
  output-file
  page-requisites
  parent
  password
  plugin
  plugin-dirs
  plugin-help
  plugin-opt
  post-data
  post-file
  prefer-family
  private-key
  private-key-type
  progress
  protocol-directories
  proxy
  quiet
  quota
  random-file
  random-wait
  read-timeout
  recursive
  referer
  regex-type
  reject
  reject-regex
  remote-encoding
  report-speed
  restrict-file-names
  retry-connrefused
  retry-on-http-error
  robots
  save-content-on
  save-cookies
  save-headers
  secure-protocol
  server-response
  signature-extensions
  span-hosts
  spider
  start-pos
  stats-dns
  stats-ocsp
  stats-server
  stats-site
  stats-tls
  strict-comments
  tcp-fastopen
  timeout
  timestamping
  tls-false-start
  tls-resume
  tls-session-file
  tries
  trust-server-names
  unlink
  use-askpass
  use-server-timestamps
  user
  user-agent
  verbose
  verify-save-failed
  verify-sig
  version
  wait
  waitretry
  xattr
EOL
"}}}

for cmd in s:commands
  exe 'syn match wget2Command "\<' .. substitute(cmd, '-', '[-_]\\=', "g") .. '\>" nextgroup=wget2AssignmentOperator skipwhite contained'
endfor
unlet s:commands

syn case match

syn match wget2LineStart	  "^" nextgroup=wget2Command,wget2Comment skipwhite
syn match wget2AssignmentOperator "=" nextgroup=wget2String,wget2Boolean,wget2Number,wget2Quota,wget2Time skipwhite contained

hi def link wget2AssignmentOperator Special
hi def link wget2Boolean	    Boolean
hi def link wget2Command	    Identifier
hi def link wget2Comment	    Comment
hi def link wget2Number		    Number
hi def link wget2Quota		    Number
hi def link wget2String		    String
hi def link wget2Time		    Number
hi def link wget2Todo		    Todo

let b:current_syntax = "wget2"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8 fdm=marker:
