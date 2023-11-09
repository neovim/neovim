" Vim syntax file
" Language:	Wget configuration file (/etc/wgetrc ~/.wgetrc)
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2023 Nov 05

" GNU Wget 1.21 built on linux-gnu.

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn match wgetComment "#.*" contains=wgetTodo contained

syn keyword wgetTodo TODO NOTE FIXME XXX contained

syn region wgetString start=+"+ skip=+\\\\\|\\"+ end=+"+ contained oneline
syn region wgetString start=+'+ skip=+\\\\\|\\'+ end=+'+ contained oneline

syn case ignore

syn keyword wgetBoolean on off yes no	 contained
syn keyword wgetNumber	inf		 contained
syn match   wgetNumber "\<\d\+>"	 contained
syn match   wgetQuota  "\<\d\+[kmgt]\>"	 contained
syn match   wgetTime   "\<\d\+[smhdw]\>" contained

"{{{ Commands
let s:commands =<< trim EOL
  accept
  accept-regex
  add-host-dir
  adjust-extension
  always-rest
  ask-password
  auth-no-challenge
  background
  backup-converted
  backups
  base
  bind-address
  bind-dns-address
  body-data
  body-file
  ca-certificate
  ca-directory
  cache
  certificate
  certificate-type
  check-certificate
  choose-config
  ciphers
  compression
  connect-timeout
  content-disposition
  content-on-error
  continue
  convert-file-only
  convert-links
  cookies
  crl-file
  cut-dirs
  debug
  default-page
  delete-after
  dns-cache
  dns-servers
  dns-timeout
  dir-prefix
  dir-struct
  domains
  dot-bytes
  dots-in-line
  dot-spacing
  dot-style
  egd-file
  exclude-directories
  exclude-domains
  follow-ftp
  follow-tags
  force-html
  ftp-passwd
  ftp-password
  ftp-user
  ftp-proxy
  ftps-clear-data-connection
  ftps-fallback-to-ftp
  ftps-implicit
  ftps-resume-ssl
  hsts
  hsts-file
  ftp-stmlf
  glob
  header
  html-extension
  htmlify
  http-keep-alive
  http-passwd
  http-password
  http-proxy
  https-proxy
  https-only
  http-user
  if-modified-since
  ignore-case
  ignore-length
  ignore-tags
  include-directories
  inet4-only
  inet6-only
  input
  input-meta-link
  iri
  keep-bad-hash
  keep-session-cookies
  kill-longer
  limit-rate
  load-cookies
  locale
  local-encoding
  logfile
  login
  max-redirect
  metalink-index
  metalink-over-http
  method
  mirror
  netrc
  no-clobber
  no-config
  no-parent
  no-proxy
  numtries
  output-document
  page-requisites
  passive-ftp
  passwd
  password
  pinned-pubkey
  post-data
  post-file
  prefer-family
  preferred-location
  preserve-permissions
  private-key
  private-key-type
  progress
  protocol-directories
  proxy-passwd
  proxy-password
  proxy-user
  quiet
  quota
  random-file
  random-wait
  read-timeout
  rec-level
  recursive
  referer
  regex-type
  reject
  rejected-log
  reject-regex
  relative-only
  remote-encoding
  remove-listing
  report-speed
  restrict-file-names
  retr-symlinks
  retry-connrefused
  retry-on-host-error
  retry-on-http-error
  robots
  save-cookies
  save-headers
  secure-protocol
  server-response
  show-all-dns-entries
  show-progress
  simple-host-check
  span-hosts
  spider
  start-pos
  strict-comments
  sslcertfile
  sslcertkey
  timeout
  timestamping
  use-server-timestamps
  tries
  trust-server-names
  unlink
  use-askpass
  user
  use-proxy
  user-agent
  verbose
  wait
  wait-retry
  warc-cdx
  warc-cdx-dedup
  warc-compression
  warc-digests
  warc-file
  warc-header
  warc-keep-log
  warc-max-size
  warc-temp-dir
  wdebug
  xattr
EOL
"}}}

for cmd in s:commands
  exe 'syn match wgetCommand "\<' .. substitute(cmd, '-', '[-_]\\=', "g") .. '\>" nextgroup=wgetAssignmentOperator skipwhite contained'
endfor
unlet s:commands

syn case match

syn match wgetLineStart		 "^" nextgroup=wgetCommand,wgetComment skipwhite
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
