" Vim syntax file
" Language:     Wget configuration file (/etc/wgetrc ~/.wgetrc)
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2013 Jun 1

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
syn keyword wgetBoolean on off contained
syn keyword wgetNumber  inf    contained
syn case match

syn match wgetNumber "\<\%(\d\+\|inf\)\>" contained
syn match wgetQuota  "\<\d\+[kKmM]\>"     contained
syn match wgetTime   "\<\d\+[smhdw]\>"    contained

"{{{ Commands
let s:commands = map([
        \ "accept",
	\ "add_hostdir",
	\ "adjust_extension",
	\ "always_rest",
	\ "ask_password",
	\ "auth_no_challenge",
	\ "background",
	\ "backup_converted",
	\ "backups",
	\ "base",
	\ "bind_address",
	\ "ca_certificate",
	\ "ca_directory",
	\ "cache",
	\ "certificate",
	\ "certificate_type",
	\ "check_certificate",
	\ "connect_timeout",
	\ "content_disposition",
	\ "continue",
	\ "convert_links",
	\ "cookies",
	\ "cut_dirs",
	\ "debug",
	\ "default_page",
	\ "delete_after",
	\ "dns_cache",
	\ "dns_timeout",
	\ "dir_prefix",
	\ "dir_struct",
	\ "domains",
	\ "dot_bytes",
	\ "dots_in_line",
	\ "dot_spacing",
	\ "dot_style",
	\ "egd_file",
	\ "exclude_directories",
	\ "exclude_domains",
	\ "follow_ftp",
	\ "follow_tags",
	\ "force_html",
	\ "ftp_passwd",
	\ "ftp_password",
	\ "ftp_user",
	\ "ftp_proxy",
	\ "glob",
	\ "header",
	\ "html_extension",
	\ "htmlify",
	\ "http_keep_alive",
	\ "http_passwd",
	\ "http_password",
	\ "http_proxy",
	\ "https_proxy",
	\ "http_user",
	\ "ignore_case",
	\ "ignore_length",
	\ "ignore_tags",
	\ "include_directories",
	\ "inet4_only",
	\ "inet6_only",
	\ "input",
	\ "iri",
	\ "keep_session_cookies",
	\ "kill_longer",
	\ "limit_rate",
	\ "load_cookies",
	\ "locale",
	\ "local_encoding",
	\ "logfile",
	\ "login",
	\ "max_redirect",
	\ "mirror",
	\ "netrc",
	\ "no_clobber",
	\ "no_parent",
	\ "no_proxy",
	\ "numtries",
	\ "output_document",
	\ "page_requisites",
	\ "passive_ftp",
	\ "passwd",
	\ "password",
	\ "post_data",
	\ "post_file",
	\ "prefer_family",
	\ "preserve_permissions",
	\ "private_key",
	\ "private_key_type",
	\ "progress",
	\ "protocol_directories",
	\ "proxy_passwd",
	\ "proxy_password",
	\ "proxy_user",
	\ "quiet",
	\ "quota",
	\ "random_file",
	\ "random_wait",
	\ "read_timeout",
	\ "reclevel",
	\ "recursive",
	\ "referer",
	\ "reject",
	\ "relative_only",
	\ "remote_encoding",
	\ "remove_listing",
	\ "restrict_file_names",
	\ "retr_symlinks",
	\ "retry_connrefused",
	\ "robots",
	\ "save_cookies",
	\ "save_headers",
	\ "secure_protocol",
	\ "server_response",
	\ "show_all_dns_entries",
	\ "simple_host_check",
	\ "span_hosts",
	\ "spider",
	\ "strict_comments",
	\ "sslcertfile",
	\ "sslcertkey",
	\ "timeout",
	\ "time_stamping",
	\ "use_server_timestamps",
	\ "tries",
	\ "trust_server_names",
	\ "user",
	\ "use_proxy",
	\ "user_agent",
	\ "verbose",
	\ "wait",
	\ "wait_retry"],
	\ "substitute(v:val, '_', '[-_]\\\\=', 'g')")
"}}}

syn case ignore
for cmd in s:commands
  exe 'syn match wgetCommand "' . cmd . '" nextgroup=wgetAssignmentOperator skipwhite contained'
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
hi def link wgetTodo		   Todo

let b:current_syntax = "wget"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8 fdm=marker:
