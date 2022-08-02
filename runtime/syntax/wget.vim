" Vim syntax file
" Language:     Wget configuration file (/etc/wgetrc ~/.wgetrc)
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2022 Apr 28

" GNU Wget 1.21 built on linux-gnu.

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

syn keyword wgetBoolean on off yes no contained
syn keyword wgetNumber	inf	      contained

syn match wgetNumber "\<\d\+>"		  contained
syn match wgetQuota  "\<\d\+[kmgt]\>"	  contained
syn match wgetTime   "\<\d\+[smhdw]\>"	  contained

"{{{ Commands
let s:commands =<< trim EOL
  accept
  accept_regex
  add_host_dir
  adjust_extension
  always_rest
  ask_password
  auth_no_challenge
  background
  backup_converted
  backups
  base
  bind_address
  bind_dns_address
  body_data
  body_file
  ca_certificate
  ca_directory
  cache
  certificate
  certificate_type
  check_certificate
  choose_config
  ciphers
  compression
  connect_timeout
  content_disposition
  content_on_error
  continue
  convert_file_only
  convert_links
  cookies
  crl_file
  cut_dirs
  debug
  default_page
  delete_after
  dns_cache
  dns_servers
  dns_timeout
  dir_prefix
  dir_struct
  domains
  dot_bytes
  dots_in_line
  dot_spacing
  dot_style
  egd_file
  exclude_directories
  exclude_domains
  follow_ftp
  follow_tags
  force_html
  ftp_passwd
  ftp_password
  ftp_user
  ftp_proxy
  ftps_clear_data_connection
  ftps_fallback_to_ftp
  ftps_implicit
  ftps_resume_ssl
  hsts
  hsts_file
  ftp_stmlf
  glob
  header
  html_extension
  htmlify
  http_keep_alive
  http_passwd
  http_password
  http_proxy
  https_proxy
  https_only
  http_user
  if_modified_since
  ignore_case
  ignore_length
  ignore_tags
  include_directories
  inet4_only
  inet6_only
  input
  input_meta_link
  iri
  keep_bad_hash
  keep_session_cookies
  kill_longer
  limit_rate
  load_cookies
  locale
  local_encoding
  logfile
  login
  max_redirect
  metalink_index
  metalink_over_http
  method
  mirror
  netrc
  no_clobber
  no_config
  no_parent
  no_proxy
  numtries
  output_document
  page_requisites
  passive_ftp
  passwd
  password
  pinned_pubkey
  post_data
  post_file
  prefer_family
  preferred_location
  preserve_permissions
  private_key
  private_key_type
  progress
  protocol_directories
  proxy_passwd
  proxy_password
  proxy_user
  quiet
  quota
  random_file
  random_wait
  read_timeout
  rec_level
  recursive
  referer
  regex_type
  reject
  rejected_log
  reject_regex
  relative_only
  remote_encoding
  remove_listing
  report_speed
  restrict_file_names
  retr_symlinks
  retry_connrefused
  retry_on_host_error
  retry_on_http_error
  robots
  save_cookies
  save_headers
  secure_protocol
  server_response
  show_all_dns_entries
  show_progress
  simple_host_check
  span_hosts
  spider
  start_pos
  strict_comments
  sslcertfile
  sslcertkey
  timeout
  timestamping
  use_server_timestamps
  tries
  trust_server_names
  unlink
  use_askpass
  user
  use_proxy
  user_agent
  verbose
  wait
  wait_retry
  warc_cdx
  warc_cdx_dedup
  warc_compression
  warc_digests
  warc_file
  warc_header
  warc_keep_log
  warc_max_size
  warc_temp_dir
  wdebug
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
