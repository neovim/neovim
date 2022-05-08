" Vim syntax file
" Language:     Wget2 configuration file (/etc/wget2rc ~/.wget2rc)
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2022 Apr 28

" GNU Wget2 2.0.0 - multithreaded metalink/file/website downloader

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn match wgetComment "#.*$" contains=wgetTodo contained

syn keyword wgetTodo TODO NOTE FIXME XXX contained

syn region wgetString start=+"+ skip=+\\\\\|\\"+ end=+"+ contained oneline
syn region wgetString start=+'+ skip=+\\\\\|\\'+ end=+'+ contained oneline

syn case ignore

syn keyword wgetBoolean on off yes no y n contained
syn keyword wgetNumber	infinity inf	  contained

syn match wgetNumber "\<\d\+>"		  contained
syn match wgetQuota  "\<\d\+[kmgt]\>"	  contained
syn match wgetTime   "\<\d\+[smhd]\>"	  contained

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

call map(s:commands, "substitute(v:val, '_', '[-_]\\\\=', 'g')")

for cmd in s:commands
  exe 'syn match wgetCommand "\<' . cmd . '\>" nextgroup=wgetAssignmentOperator skipwhite contained'
endfor

syn case match

syn match wgetStart "^" nextgroup=wgetCommand,wgetComment skipwhite
syn match wgetAssignmentOperator "=" nextgroup=wgetString,wgetBoolean,wgetNumber,wgetQuota,wgetTime skipwhite contained

hi def link wgetAssignmentOperator Special
hi def link wgetBoolean		   Boolean
hi def link wgetCommand		   Identifier
hi def link wgetComment		   Comment
hi def link wgetNumber		   Number
hi def link wgetQuota		   Number
hi def link wgetString		   String
hi def link wgetTime		   Number
hi def link wgetTodo		   Todo

let b:current_syntax = "wget"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8 fdm=marker:
