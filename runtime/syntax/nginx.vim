" Vim syntax file
" Language: nginx.conf
" Maintainer: Chris Aumann <me@chr4.org>
" Last Change: Jan 25, 2023

if exists("b:current_syntax")
  finish
end

let b:current_syntax = "nginx"

syn match ngxVariable '\$\(\w\+\|{\w\+}\)'
syn match ngxVariableBlock '\$\(\w\+\|{\w\+}\)' contained
syn match ngxVariableString '\$\(\w\+\|{\w\+}\)' contained
syn region ngxBlock start=+^+ end=+{+ skip=+\${\|{{\|{%+ contains=ngxComment,ngxInteger,ngxIPaddr,ngxDirectiveBlock,ngxVariableBlock,ngxString,ngxThirdPartyLuaBlock oneline
syn region ngxString start=+[^:a-zA-Z>!\\@]\z(["']\)+lc=1 end=+\z1+ skip=+\\\\\|\\\z1+ contains=ngxVariableString,ngxSSLCipherInsecure
syn match ngxComment ' *#.*$'

" These regular expressions where taken (and adapted) from
" http://vim.1045645.n5.nabble.com/IPv6-support-for-quot-dns-quot-zonefile-syntax-highlighting-td1197292.html
syn match ngxInteger '\W\zs\(\d[0-9.]*\|[0-9.]*\d\)\w\?\ze\W'
syn match ngxIPaddr '\([0-2]\?\d\{1,2}\.\)\{3}[0-2]\?\d\{1,2}'
syn match ngxIPaddr '\[\(\x\{1,4}:\)\{6}\(\x\{1,4}:\x\{1,4}\|\([0-2]\?\d\{1,2}\.\)\{3}[0-2]\?\d\{1,2}\)\]'
syn match ngxIPaddr '\[::\(\(\x\{1,4}:\)\{,6}\x\{1,4}\|\(\x\{1,4}:\)\{,5}\([0-2]\?\d\{1,2}\.\)\{3}[0-2]\?\d\{1,2}\)\]'
syn match ngxIPaddr '\[\(\x\{1,4}:\)\{1}:\(\(\x\{1,4}:\)\{,5}\x\{1,4}\|\(\x\{1,4}:\)\{,4}\([0-2]\?\d\{1,2}\.\)\{3}[0-2]\?\d\{1,2}\)\]'
syn match ngxIPaddr '\[\(\x\{1,4}:\)\{2}:\(\(\x\{1,4}:\)\{,4}\x\{1,4}\|\(\x\{1,4}:\)\{,3}\([0-2]\?\d\{1,2}\.\)\{3}[0-2]\?\d\{1,2}\)\]'
syn match ngxIPaddr '\[\(\x\{1,4}:\)\{3}:\(\(\x\{1,4}:\)\{,3}\x\{1,4}\|\(\x\{1,4}:\)\{,2}\([0-2]\?\d\{1,2}\.\)\{3}[0-2]\?\d\{1,2}\)\]'
syn match ngxIPaddr '\[\(\x\{1,4}:\)\{4}:\(\(\x\{1,4}:\)\{,2}\x\{1,4}\|\(\x\{1,4}:\)\{,1}\([0-2]\?\d\{1,2}\.\)\{3}[0-2]\?\d\{1,2}\)\]'
syn match ngxIPaddr '\[\(\x\{1,4}:\)\{5}:\(\(\x\{1,4}:\)\{,1}\x\{1,4}\|\([0-2]\?\d\{1,2}\.\)\{3}[0-2]\?\d\{1,2}\)\]'
syn match ngxIPaddr '\[\(\x\{1,4}:\)\{6}:\x\{1,4}\]'

" Highlight wildcard listening signs also as IPaddr
syn match ngxIPaddr '\s\zs\[::]'
syn match ngxIPaddr '\s\zs\*'

syn keyword ngxBoolean on
syn keyword ngxBoolean off

syn keyword ngxDirectiveBlock http          contained
syn keyword ngxDirectiveBlock mail          contained
syn keyword ngxDirectiveBlock events        contained
syn keyword ngxDirectiveBlock server        contained
syn keyword ngxDirectiveBlock match         contained
syn keyword ngxDirectiveBlock types         contained
syn keyword ngxDirectiveBlock location      contained
syn keyword ngxDirectiveBlock upstream      contained
syn keyword ngxDirectiveBlock charset_map   contained
syn keyword ngxDirectiveBlock limit_except  contained
syn keyword ngxDirectiveBlock if            contained
syn keyword ngxDirectiveBlock geo           contained
syn keyword ngxDirectiveBlock map           contained
syn keyword ngxDirectiveBlock split_clients contained

syn keyword ngxDirectiveImportant include
syn keyword ngxDirectiveImportant root
syn keyword ngxDirectiveImportant server contained
syn region  ngxDirectiveImportantServer matchgroup=ngxDirectiveImportant start=+^\s*\zsserver\ze\s.*;+ skip=+\\\\\|\\\;+ end=+;+he=e-1 contains=ngxUpstreamServerOptions,ngxString,ngxIPaddr,ngxBoolean,ngxInteger,ngxTemplateVar
syn keyword ngxDirectiveImportant server_name
syn keyword ngxDirectiveImportant listen contained
syn region  ngxDirectiveImportantListen matchgroup=ngxDirectiveImportant start=+listen+ skip=+\\\\\|\\\;+ end=+;+he=e-1 contains=ngxListenOptions,ngxString,ngxIPaddr,ngxBoolean,ngxInteger,ngxTemplateVar
syn keyword ngxDirectiveImportant internal
syn keyword ngxDirectiveImportant proxy_pass
syn keyword ngxDirectiveImportant memcached_pass
syn keyword ngxDirectiveImportant fastcgi_pass
syn keyword ngxDirectiveImportant scgi_pass
syn keyword ngxDirectiveImportant uwsgi_pass
syn keyword ngxDirectiveImportant try_files
syn keyword ngxDirectiveImportant error_page
syn keyword ngxDirectiveImportant post_action

syn keyword ngxUpstreamServerOptions weight         contained
syn keyword ngxUpstreamServerOptions max_conns      contained
syn keyword ngxUpstreamServerOptions max_fails      contained
syn keyword ngxUpstreamServerOptions fail_timeout   contained
syn keyword ngxUpstreamServerOptions backup         contained
syn keyword ngxUpstreamServerOptions down           contained
syn keyword ngxUpstreamServerOptions resolve        contained
syn keyword ngxUpstreamServerOptions route          contained
syn keyword ngxUpstreamServerOptions service        contained
syn keyword ngxUpstreamServerOptions default_server contained
syn keyword ngxUpstreamServerOptions slow_start     contained

syn keyword ngxListenOptions default_server contained
syn keyword ngxListenOptions ssl            contained
syn keyword ngxListenOptions http2          contained
syn keyword ngxListenOptions spdy           contained
syn keyword ngxListenOptions http3          contained
syn keyword ngxListenOptions quic           contained
syn keyword ngxListenOptions proxy_protocol contained
syn keyword ngxListenOptions setfib         contained
syn keyword ngxListenOptions fastopen       contained
syn keyword ngxListenOptions backlog        contained
syn keyword ngxListenOptions rcvbuf         contained
syn keyword ngxListenOptions sndbuf         contained
syn keyword ngxListenOptions accept_filter  contained
syn keyword ngxListenOptions deferred       contained
syn keyword ngxListenOptions bind           contained
syn keyword ngxListenOptions ipv6only       contained
syn keyword ngxListenOptions reuseport      contained
syn keyword ngxListenOptions so_keepalive   contained
syn keyword ngxListenOptions keepidle       contained

syn keyword ngxDirectiveControl break
syn keyword ngxDirectiveControl return
syn keyword ngxDirectiveControl rewrite
syn keyword ngxDirectiveControl set

syn keyword ngxDirectiveDeprecated connections
syn keyword ngxDirectiveDeprecated imap
syn keyword ngxDirectiveDeprecated limit_zone
syn keyword ngxDirectiveDeprecated mysql_test
syn keyword ngxDirectiveDeprecated open_file_cache_retest
syn keyword ngxDirectiveDeprecated optimize_server_names
syn keyword ngxDirectiveDeprecated satisfy_any
syn keyword ngxDirectiveDeprecated so_keepalive

syn keyword ngxDirective absolute_redirect
syn keyword ngxDirective accept_mutex
syn keyword ngxDirective accept_mutex_delay
syn keyword ngxDirective acceptex_read
syn keyword ngxDirective access_log
syn keyword ngxDirective add_after_body
syn keyword ngxDirective add_before_body
syn keyword ngxDirective add_header
syn keyword ngxDirective addition_types
syn keyword ngxDirective aio
syn keyword ngxDirective aio_write
syn keyword ngxDirective alias
syn keyword ngxDirective allow
syn keyword ngxDirective ancient_browser
syn keyword ngxDirective ancient_browser_value
syn keyword ngxDirective auth_basic
syn keyword ngxDirective auth_basic_user_file
syn keyword ngxDirective auth_http
syn keyword ngxDirective auth_http_header
syn keyword ngxDirective auth_http_pass_client_cert
syn keyword ngxDirective auth_http_timeout
syn keyword ngxDirective auth_jwt
syn keyword ngxDirective auth_jwt_key_file
syn keyword ngxDirective auth_request
syn keyword ngxDirective auth_request_set
syn keyword ngxDirective autoindex
syn keyword ngxDirective autoindex_exact_size
syn keyword ngxDirective autoindex_format
syn keyword ngxDirective autoindex_localtime
syn keyword ngxDirective charset
syn keyword ngxDirective charset_map
syn keyword ngxDirective charset_types
syn keyword ngxDirective chunked_transfer_encoding
syn keyword ngxDirective client_body_buffer_size
syn keyword ngxDirective client_body_in_file_only
syn keyword ngxDirective client_body_in_single_buffer
syn keyword ngxDirective client_body_temp_path
syn keyword ngxDirective client_body_timeout
syn keyword ngxDirective client_header_buffer_size
syn keyword ngxDirective client_header_timeout
syn keyword ngxDirective client_max_body_size
syn keyword ngxDirective connection_pool_size
syn keyword ngxDirective create_full_put_path
syn keyword ngxDirective daemon
syn keyword ngxDirective dav_access
syn keyword ngxDirective dav_methods
syn keyword ngxDirective debug_connection
syn keyword ngxDirective debug_points
syn keyword ngxDirective default_type
syn keyword ngxDirective degradation
syn keyword ngxDirective degrade
syn keyword ngxDirective deny
syn keyword ngxDirective devpoll_changes
syn keyword ngxDirective devpoll_events
syn keyword ngxDirective directio
syn keyword ngxDirective directio_alignment
syn keyword ngxDirective disable_symlinks
syn keyword ngxDirective empty_gif
syn keyword ngxDirective env
syn keyword ngxDirective epoll_events
syn keyword ngxDirective error_log
syn keyword ngxDirective etag
syn keyword ngxDirective eventport_events
syn keyword ngxDirective expires
syn keyword ngxDirective f4f
syn keyword ngxDirective f4f_buffer_size
syn keyword ngxDirective fastcgi_bind
syn keyword ngxDirective fastcgi_buffer_size
syn keyword ngxDirective fastcgi_buffering
syn keyword ngxDirective fastcgi_buffers
syn keyword ngxDirective fastcgi_busy_buffers_size
syn keyword ngxDirective fastcgi_cache
syn keyword ngxDirective fastcgi_cache_bypass
syn keyword ngxDirective fastcgi_cache_key
syn keyword ngxDirective fastcgi_cache_lock
syn keyword ngxDirective fastcgi_cache_lock_age
syn keyword ngxDirective fastcgi_cache_lock_timeout
syn keyword ngxDirective fastcgi_cache_max_range_offset
syn keyword ngxDirective fastcgi_cache_methods
syn keyword ngxDirective fastcgi_cache_min_uses
syn keyword ngxDirective fastcgi_cache_path
syn keyword ngxDirective fastcgi_cache_purge
syn keyword ngxDirective fastcgi_cache_revalidate
syn keyword ngxDirective fastcgi_cache_use_stale
syn keyword ngxDirective fastcgi_cache_valid
syn keyword ngxDirective fastcgi_catch_stderr
syn keyword ngxDirective fastcgi_connect_timeout
syn keyword ngxDirective fastcgi_force_ranges
syn keyword ngxDirective fastcgi_hide_header
syn keyword ngxDirective fastcgi_ignore_client_abort
syn keyword ngxDirective fastcgi_ignore_headers
syn keyword ngxDirective fastcgi_index
syn keyword ngxDirective fastcgi_intercept_errors
syn keyword ngxDirective fastcgi_keep_conn
syn keyword ngxDirective fastcgi_limit_rate
syn keyword ngxDirective fastcgi_max_temp_file_size
syn keyword ngxDirective fastcgi_next_upstream
syn keyword ngxDirective fastcgi_next_upstream_timeout
syn keyword ngxDirective fastcgi_next_upstream_tries
syn keyword ngxDirective fastcgi_no_cache
syn keyword ngxDirective fastcgi_param
syn keyword ngxDirective fastcgi_pass_header
syn keyword ngxDirective fastcgi_pass_request_body
syn keyword ngxDirective fastcgi_pass_request_headers
syn keyword ngxDirective fastcgi_read_timeout
syn keyword ngxDirective fastcgi_request_buffering
syn keyword ngxDirective fastcgi_send_lowat
syn keyword ngxDirective fastcgi_send_timeout
syn keyword ngxDirective fastcgi_split_path_info
syn keyword ngxDirective fastcgi_store
syn keyword ngxDirective fastcgi_store_access
syn keyword ngxDirective fastcgi_temp_file_write_size
syn keyword ngxDirective fastcgi_temp_path
syn keyword ngxDirective flv
syn keyword ngxDirective geoip_city
syn keyword ngxDirective geoip_country
syn keyword ngxDirective geoip_org
syn keyword ngxDirective geoip_proxy
syn keyword ngxDirective geoip_proxy_recursive
syn keyword ngxDirective google_perftools_profiles
syn keyword ngxDirective gunzip
syn keyword ngxDirective gunzip_buffers
syn keyword ngxDirective gzip nextgroup=ngxGzipOn,ngxGzipOff skipwhite
syn keyword ngxGzipOn on contained
syn keyword ngxGzipOff off contained
syn keyword ngxDirective gzip_buffers
syn keyword ngxDirective gzip_comp_level
syn keyword ngxDirective gzip_disable
syn keyword ngxDirective gzip_hash
syn keyword ngxDirective gzip_http_version
syn keyword ngxDirective gzip_min_length
syn keyword ngxDirective gzip_no_buffer
syn keyword ngxDirective gzip_proxied
syn keyword ngxDirective gzip_static
syn keyword ngxDirective gzip_types
syn keyword ngxDirective gzip_vary
syn keyword ngxDirective gzip_window
syn keyword ngxDirective hash
syn keyword ngxDirective health_check
syn keyword ngxDirective health_check_timeout
syn keyword ngxDirective hls
syn keyword ngxDirective hls_buffers
syn keyword ngxDirective hls_forward_args
syn keyword ngxDirective hls_fragment
syn keyword ngxDirective hls_mp4_buffer_size
syn keyword ngxDirective hls_mp4_max_buffer_size
syn keyword ngxDirective http2_chunk_size
syn keyword ngxDirective http2_body_preread_size
syn keyword ngxDirective http2_idle_timeout
syn keyword ngxDirective http2_max_concurrent_streams
syn keyword ngxDirective http2_max_field_size
syn keyword ngxDirective http2_max_header_size
syn keyword ngxDirective http2_max_requests
syn keyword ngxDirective http2_push
syn keyword ngxDirective http2_push_preload
syn keyword ngxDirective http2_recv_buffer_size
syn keyword ngxDirective http2_recv_timeout
syn keyword ngxDirective http3_hq
syn keyword ngxDirective http3_max_concurrent_pushes
syn keyword ngxDirective http3_max_concurrent_streams
syn keyword ngxDirective http3_push
syn keyword ngxDirective http3_push_preload
syn keyword ngxDirective http3_stream_buffer_size
syn keyword ngxDirective if_modified_since
syn keyword ngxDirective ignore_invalid_headers
syn keyword ngxDirective image_filter
syn keyword ngxDirective image_filter_buffer
syn keyword ngxDirective image_filter_interlace
syn keyword ngxDirective image_filter_jpeg_quality
syn keyword ngxDirective image_filter_sharpen
syn keyword ngxDirective image_filter_transparency
syn keyword ngxDirective image_filter_webp_quality
syn keyword ngxDirective imap_auth
syn keyword ngxDirective imap_capabilities
syn keyword ngxDirective imap_client_buffer
syn keyword ngxDirective index
syn keyword ngxDirective iocp_threads
syn keyword ngxDirective ip_hash
syn keyword ngxDirective js_access
syn keyword ngxDirective js_content
syn keyword ngxDirective js_filter
syn keyword ngxDirective js_include
syn keyword ngxDirective js_preread
syn keyword ngxDirective js_set
syn keyword ngxDirective keepalive
syn keyword ngxDirective keepalive_disable
syn keyword ngxDirective keepalive_requests
syn keyword ngxDirective keepalive_timeout
syn keyword ngxDirective kqueue_changes
syn keyword ngxDirective kqueue_events
syn keyword ngxDirective large_client_header_buffers
syn keyword ngxDirective least_conn
syn keyword ngxDirective least_time
syn keyword ngxDirective limit_conn
syn keyword ngxDirective limit_conn_dry_run
syn keyword ngxDirective limit_conn_log_level
syn keyword ngxDirective limit_conn_status
syn keyword ngxDirective limit_conn_zone
syn keyword ngxDirective limit_except
syn keyword ngxDirective limit_rate
syn keyword ngxDirective limit_rate_after
syn keyword ngxDirective limit_req
syn keyword ngxDirective limit_req_dry_run
syn keyword ngxDirective limit_req_log_level
syn keyword ngxDirective limit_req_status
syn keyword ngxDirective limit_req_zone
syn keyword ngxDirective lingering_close
syn keyword ngxDirective lingering_time
syn keyword ngxDirective lingering_timeout
syn keyword ngxDirective load_module
syn keyword ngxDirective lock_file
syn keyword ngxDirective log_format
syn keyword ngxDirective log_not_found
syn keyword ngxDirective log_subrequest
syn keyword ngxDirective map_hash_bucket_size
syn keyword ngxDirective map_hash_max_size
syn keyword ngxDirective master_process
syn keyword ngxDirective max_ranges
syn keyword ngxDirective memcached_bind
syn keyword ngxDirective memcached_buffer_size
syn keyword ngxDirective memcached_connect_timeout
syn keyword ngxDirective memcached_force_ranges
syn keyword ngxDirective memcached_gzip_flag
syn keyword ngxDirective memcached_next_upstream
syn keyword ngxDirective memcached_next_upstream_timeout
syn keyword ngxDirective memcached_next_upstream_tries
syn keyword ngxDirective memcached_read_timeout
syn keyword ngxDirective memcached_send_timeout
syn keyword ngxDirective merge_slashes
syn keyword ngxDirective min_delete_depth
syn keyword ngxDirective modern_browser
syn keyword ngxDirective modern_browser_value
syn keyword ngxDirective mp4
syn keyword ngxDirective mp4_buffer_size
syn keyword ngxDirective mp4_max_buffer_size
syn keyword ngxDirective mp4_limit_rate
syn keyword ngxDirective mp4_limit_rate_after
syn keyword ngxDirective msie_padding
syn keyword ngxDirective msie_refresh
syn keyword ngxDirective multi_accept
syn keyword ngxDirective ntlm
syn keyword ngxDirective open_file_cache
syn keyword ngxDirective open_file_cache_errors
syn keyword ngxDirective open_file_cache_events
syn keyword ngxDirective open_file_cache_min_uses
syn keyword ngxDirective open_file_cache_valid
syn keyword ngxDirective open_log_file_cache
syn keyword ngxDirective output_buffers
syn keyword ngxDirective override_charset
syn keyword ngxDirective pcre_jit
syn keyword ngxDirective perl
syn keyword ngxDirective perl_modules
syn keyword ngxDirective perl_require
syn keyword ngxDirective perl_set
syn keyword ngxDirective pid
syn keyword ngxDirective pop3_auth
syn keyword ngxDirective pop3_capabilities
syn keyword ngxDirective port_in_redirect
syn keyword ngxDirective post_acceptex
syn keyword ngxDirective postpone_gzipping
syn keyword ngxDirective postpone_output
syn keyword ngxDirective preread_buffer_size
syn keyword ngxDirective preread_timeout
syn keyword ngxDirective protocol nextgroup=ngxMailProtocol skipwhite
syn keyword ngxMailProtocol imap pop3 smtp contained
syn keyword ngxDirective proxy
syn keyword ngxDirective proxy_bind
syn keyword ngxDirective proxy_buffer
syn keyword ngxDirective proxy_buffer_size
syn keyword ngxDirective proxy_buffering
syn keyword ngxDirective proxy_buffers
syn keyword ngxDirective proxy_busy_buffers_size
syn keyword ngxDirective proxy_cache
syn keyword ngxDirective proxy_cache_bypass
syn keyword ngxDirective proxy_cache_convert_head
syn keyword ngxDirective proxy_cache_key
syn keyword ngxDirective proxy_cache_lock
syn keyword ngxDirective proxy_cache_lock_age
syn keyword ngxDirective proxy_cache_lock_timeout
syn keyword ngxDirective proxy_cache_max_range_offset
syn keyword ngxDirective proxy_cache_methods
syn keyword ngxDirective proxy_cache_min_uses
syn keyword ngxDirective proxy_cache_path
syn keyword ngxDirective proxy_cache_purge
syn keyword ngxDirective proxy_cache_revalidate
syn keyword ngxDirective proxy_cache_use_stale
syn keyword ngxDirective proxy_cache_valid
syn keyword ngxDirective proxy_connect_timeout
syn keyword ngxDirective proxy_cookie_domain
syn keyword ngxDirective proxy_cookie_path
syn keyword ngxDirective proxy_download_rate
syn keyword ngxDirective proxy_force_ranges
syn keyword ngxDirective proxy_headers_hash_bucket_size
syn keyword ngxDirective proxy_headers_hash_max_size
syn keyword ngxDirective proxy_hide_header
syn keyword ngxDirective proxy_http_version
syn keyword ngxDirective proxy_ignore_client_abort
syn keyword ngxDirective proxy_ignore_headers
syn keyword ngxDirective proxy_intercept_errors
syn keyword ngxDirective proxy_limit_rate
syn keyword ngxDirective proxy_max_temp_file_size
syn keyword ngxDirective proxy_method
syn keyword ngxDirective proxy_next_upstream contained
syn region  ngxDirectiveProxyNextUpstream matchgroup=ngxDirective start=+^\s*\zsproxy_next_upstream\ze\s.*;+ skip=+\\\\\|\\\;+ end=+;+he=e-1 contains=ngxProxyNextUpstreamOptions,ngxString,ngxTemplateVar
syn keyword ngxDirective proxy_next_upstream_timeout
syn keyword ngxDirective proxy_next_upstream_tries
syn keyword ngxDirective proxy_no_cache
syn keyword ngxDirective proxy_pass_error_message
syn keyword ngxDirective proxy_pass_header
syn keyword ngxDirective proxy_pass_request_body
syn keyword ngxDirective proxy_pass_request_headers
syn keyword ngxDirective proxy_protocol
syn keyword ngxDirective proxy_protocol_timeout
syn keyword ngxDirective proxy_read_timeout
syn keyword ngxDirective proxy_redirect
syn keyword ngxDirective proxy_request_buffering
syn keyword ngxDirective proxy_responses
syn keyword ngxDirective proxy_send_lowat
syn keyword ngxDirective proxy_send_timeout
syn keyword ngxDirective proxy_set_body
syn keyword ngxDirective proxy_set_header
syn keyword ngxDirective proxy_ssl_certificate
syn keyword ngxDirective proxy_ssl_certificate_key
syn keyword ngxDirective proxy_ssl_ciphers
syn keyword ngxDirective proxy_ssl_crl
syn keyword ngxDirective proxy_ssl_name
syn keyword ngxDirective proxy_ssl_password_file
syn keyword ngxDirective proxy_ssl_protocols nextgroup=ngxSSLProtocol skipwhite
syn keyword ngxDirective proxy_ssl_server_name
syn keyword ngxDirective proxy_ssl_session_reuse
syn keyword ngxDirective proxy_ssl_trusted_certificate
syn keyword ngxDirective proxy_ssl_verify
syn keyword ngxDirective proxy_ssl_verify_depth
syn keyword ngxDirective proxy_store
syn keyword ngxDirective proxy_store_access
syn keyword ngxDirective proxy_temp_file_write_size
syn keyword ngxDirective proxy_temp_path
syn keyword ngxDirective proxy_timeout
syn keyword ngxDirective proxy_upload_rate
syn keyword ngxDirective queue
syn keyword ngxDirective quic_gso
syn keyword ngxDirective quic_host_key
syn keyword ngxDirective quic_mtu
syn keyword ngxDirective quic_retry
syn keyword ngxDirective random_index
syn keyword ngxDirective read_ahead
syn keyword ngxDirective real_ip_header
syn keyword ngxDirective real_ip_recursive
syn keyword ngxDirective recursive_error_pages
syn keyword ngxDirective referer_hash_bucket_size
syn keyword ngxDirective referer_hash_max_size
syn keyword ngxDirective request_pool_size
syn keyword ngxDirective reset_timedout_connection
syn keyword ngxDirective resolver
syn keyword ngxDirective resolver_timeout
syn keyword ngxDirective rewrite_log
syn keyword ngxDirective rtsig_overflow_events
syn keyword ngxDirective rtsig_overflow_test
syn keyword ngxDirective rtsig_overflow_threshold
syn keyword ngxDirective rtsig_signo
syn keyword ngxDirective satisfy
syn keyword ngxDirective scgi_bind
syn keyword ngxDirective scgi_buffer_size
syn keyword ngxDirective scgi_buffering
syn keyword ngxDirective scgi_buffers
syn keyword ngxDirective scgi_busy_buffers_size
syn keyword ngxDirective scgi_cache
syn keyword ngxDirective scgi_cache_bypass
syn keyword ngxDirective scgi_cache_key
syn keyword ngxDirective scgi_cache_lock
syn keyword ngxDirective scgi_cache_lock_age
syn keyword ngxDirective scgi_cache_lock_timeout
syn keyword ngxDirective scgi_cache_max_range_offset
syn keyword ngxDirective scgi_cache_methods
syn keyword ngxDirective scgi_cache_min_uses
syn keyword ngxDirective scgi_cache_path
syn keyword ngxDirective scgi_cache_purge
syn keyword ngxDirective scgi_cache_revalidate
syn keyword ngxDirective scgi_cache_use_stale
syn keyword ngxDirective scgi_cache_valid
syn keyword ngxDirective scgi_connect_timeout
syn keyword ngxDirective scgi_force_ranges
syn keyword ngxDirective scgi_hide_header
syn keyword ngxDirective scgi_ignore_client_abort
syn keyword ngxDirective scgi_ignore_headers
syn keyword ngxDirective scgi_intercept_errors
syn keyword ngxDirective scgi_limit_rate
syn keyword ngxDirective scgi_max_temp_file_size
syn keyword ngxDirective scgi_next_upstream
syn keyword ngxDirective scgi_next_upstream_timeout
syn keyword ngxDirective scgi_next_upstream_tries
syn keyword ngxDirective scgi_no_cache
syn keyword ngxDirective scgi_param
syn keyword ngxDirective scgi_pass_header
syn keyword ngxDirective scgi_pass_request_body
syn keyword ngxDirective scgi_pass_request_headers
syn keyword ngxDirective scgi_read_timeout
syn keyword ngxDirective scgi_request_buffering
syn keyword ngxDirective scgi_send_timeout
syn keyword ngxDirective scgi_store
syn keyword ngxDirective scgi_store_access
syn keyword ngxDirective scgi_temp_file_write_size
syn keyword ngxDirective scgi_temp_path
syn keyword ngxDirective secure_link
syn keyword ngxDirective secure_link_md5
syn keyword ngxDirective secure_link_secret
syn keyword ngxDirective send_lowat
syn keyword ngxDirective send_timeout
syn keyword ngxDirective sendfile
syn keyword ngxDirective sendfile_max_chunk
syn keyword ngxDirective server_name_in_redirect
syn keyword ngxDirective server_names_hash_bucket_size
syn keyword ngxDirective server_names_hash_max_size
syn keyword ngxDirective server_tokens
syn keyword ngxDirective session_log
syn keyword ngxDirective session_log_format
syn keyword ngxDirective session_log_zone
syn keyword ngxDirective set_real_ip_from
syn keyword ngxDirective slice
syn keyword ngxDirective smtp_auth
syn keyword ngxDirective smtp_capabilities
syn keyword ngxDirective smtp_client_buffer
syn keyword ngxDirective smtp_greeting_delay
syn keyword ngxDirective source_charset
syn keyword ngxDirective spdy_chunk_size
syn keyword ngxDirective spdy_headers_comp
syn keyword ngxDirective spdy_keepalive_timeout
syn keyword ngxDirective spdy_max_concurrent_streams
syn keyword ngxDirective spdy_pool_size
syn keyword ngxDirective spdy_recv_buffer_size
syn keyword ngxDirective spdy_recv_timeout
syn keyword ngxDirective spdy_streams_index_size
syn keyword ngxDirective ssi
syn keyword ngxDirective ssi_ignore_recycled_buffers
syn keyword ngxDirective ssi_last_modified
syn keyword ngxDirective ssi_min_file_chunk
syn keyword ngxDirective ssi_silent_errors
syn keyword ngxDirective ssi_types
syn keyword ngxDirective ssi_value_length
syn keyword ngxDirective ssl
syn keyword ngxDirective ssl_buffer_size
syn keyword ngxDirective ssl_certificate
syn keyword ngxDirective ssl_certificate_key
syn keyword ngxDirective ssl_ciphers
syn keyword ngxDirective ssl_client_certificate
syn keyword ngxDirective ssl_conf_command
syn keyword ngxDirective ssl_crl
syn keyword ngxDirective ssl_dhparam
syn keyword ngxDirective ssl_early_data
syn keyword ngxDirective ssl_ecdh_curve
syn keyword ngxDirective ssl_engine
syn keyword ngxDirective ssl_handshake_timeout
syn keyword ngxDirective ssl_password_file
syn keyword ngxDirective ssl_prefer_server_ciphers nextgroup=ngxSSLPreferServerCiphersOff,ngxSSLPreferServerCiphersOn skipwhite
syn keyword ngxSSLPreferServerCiphersOn on contained
syn keyword ngxSSLPreferServerCiphersOff off contained
syn keyword ngxDirective ssl_preread
syn keyword ngxDirective ssl_protocols nextgroup=ngxSSLProtocol,ngxSSLProtocolDeprecated skipwhite
syn keyword ngxDirective ssl_reject_handshake
syn match ngxSSLProtocol 'TLSv1' contained nextgroup=ngxSSLProtocol,ngxSSLProtocolDeprecated skipwhite
syn match ngxSSLProtocol 'TLSv1\.1' contained nextgroup=ngxSSLProtocol,ngxSSLProtocolDeprecated skipwhite
syn match ngxSSLProtocol 'TLSv1\.2' contained nextgroup=ngxSSLProtocol,ngxSSLProtocolDeprecated skipwhite
syn match ngxSSLProtocol 'TLSv1\.3' contained nextgroup=ngxSSLProtocol,ngxSSLProtocolDeprecated skipwhite

" Do not enable highlighting of insecure protocols if sslecure is loaded
if !exists('g:loaded_sslsecure')
  syn keyword ngxSSLProtocolDeprecated SSLv2 SSLv3 contained nextgroup=ngxSSLProtocol,ngxSSLProtocolDeprecated skipwhite
else
  syn match ngxSSLProtocol 'SSLv2' contained nextgroup=ngxSSLProtocol,ngxSSLProtocolDeprecated skipwhite
  syn match ngxSSLProtocol 'SSLv3' contained nextgroup=ngxSSLProtocol,ngxSSLProtocolDeprecated skipwhite
endif

syn keyword ngxDirective ssl_session_cache
syn keyword ngxDirective ssl_session_ticket_key
syn keyword ngxDirective ssl_session_tickets nextgroup=ngxSSLSessionTicketsOn,ngxSSLSessionTicketsOff skipwhite
syn keyword ngxSSLSessionTicketsOn on contained
syn keyword ngxSSLSessionTicketsOff off contained
syn keyword ngxDirective ssl_session_timeout
syn keyword ngxDirective ssl_stapling
syn keyword ngxDirective ssl_stapling_file
syn keyword ngxDirective ssl_stapling_responder
syn keyword ngxDirective ssl_stapling_verify
syn keyword ngxDirective ssl_trusted_certificate
syn keyword ngxDirective ssl_verify_client
syn keyword ngxDirective ssl_verify_depth
syn keyword ngxDirective starttls
syn keyword ngxDirective state
syn keyword ngxDirective status
syn keyword ngxDirective status_format
syn keyword ngxDirective status_zone
syn keyword ngxDirective sticky contained
syn keyword ngxDirective sticky_cookie_insert contained
syn region  ngxDirectiveSticky matchgroup=ngxDirective start=+^\s*\zssticky\ze\s.*;+ skip=+\\\\\|\\\;+ end=+;+he=e-1 contains=ngxCookieOptions,ngxString,ngxBoolean,ngxInteger,ngxTemplateVar
syn keyword ngxDirective stub_status
syn keyword ngxDirective sub_filter
syn keyword ngxDirective sub_filter_last_modified
syn keyword ngxDirective sub_filter_once
syn keyword ngxDirective sub_filter_types
syn keyword ngxDirective tcp_nodelay
syn keyword ngxDirective tcp_nopush
syn keyword ngxDirective thread_pool
syn keyword ngxDirective thread_stack_size
syn keyword ngxDirective timeout
syn keyword ngxDirective timer_resolution
syn keyword ngxDirective types_hash_bucket_size
syn keyword ngxDirective types_hash_max_size
syn keyword ngxDirective underscores_in_headers
syn keyword ngxDirective uninitialized_variable_warn
syn keyword ngxDirective upstream_conf
syn keyword ngxDirective use
syn keyword ngxDirective user
syn keyword ngxDirective userid
syn keyword ngxDirective userid_domain
syn keyword ngxDirective userid_expires
syn keyword ngxDirective userid_mark
syn keyword ngxDirective userid_name
syn keyword ngxDirective userid_p3p
syn keyword ngxDirective userid_path
syn keyword ngxDirective userid_service
syn keyword ngxDirective uwsgi_bind
syn keyword ngxDirective uwsgi_buffer_size
syn keyword ngxDirective uwsgi_buffering
syn keyword ngxDirective uwsgi_buffers
syn keyword ngxDirective uwsgi_busy_buffers_size
syn keyword ngxDirective uwsgi_cache
syn keyword ngxDirective uwsgi_cache_background_update
syn keyword ngxDirective uwsgi_cache_bypass
syn keyword ngxDirective uwsgi_cache_key
syn keyword ngxDirective uwsgi_cache_lock
syn keyword ngxDirective uwsgi_cache_lock_age
syn keyword ngxDirective uwsgi_cache_lock_timeout
syn keyword ngxDirective uwsgi_cache_methods
syn keyword ngxDirective uwsgi_cache_min_uses
syn keyword ngxDirective uwsgi_cache_path
syn keyword ngxDirective uwsgi_cache_purge
syn keyword ngxDirective uwsgi_cache_revalidate
syn keyword ngxDirective uwsgi_cache_use_stale
syn keyword ngxDirective uwsgi_cache_valid
syn keyword ngxDirective uwsgi_connect_timeout
syn keyword ngxDirective uwsgi_force_ranges
syn keyword ngxDirective uwsgi_hide_header
syn keyword ngxDirective uwsgi_ignore_client_abort
syn keyword ngxDirective uwsgi_ignore_headers
syn keyword ngxDirective uwsgi_intercept_errors
syn keyword ngxDirective uwsgi_limit_rate
syn keyword ngxDirective uwsgi_max_temp_file_size
syn keyword ngxDirective uwsgi_modifier1
syn keyword ngxDirective uwsgi_modifier2
syn keyword ngxDirective uwsgi_next_upstream
syn keyword ngxDirective uwsgi_next_upstream_timeout
syn keyword ngxDirective uwsgi_next_upstream_tries
syn keyword ngxDirective uwsgi_no_cache
syn keyword ngxDirective uwsgi_param
syn keyword ngxDirective uwsgi_pass
syn keyword ngxDirective uwsgi_pass_header
syn keyword ngxDirective uwsgi_pass_request_body
syn keyword ngxDirective uwsgi_pass_request_headers
syn keyword ngxDirective uwsgi_read_timeout
syn keyword ngxDirective uwsgi_request_buffering
syn keyword ngxDirective uwsgi_send_timeout
syn keyword ngxDirective uwsgi_ssl_certificate
syn keyword ngxDirective uwsgi_ssl_certificate_key
syn keyword ngxDirective uwsgi_ssl_ciphers
syn keyword ngxDirective uwsgi_ssl_crl
syn keyword ngxDirective uwsgi_ssl_name
syn keyword ngxDirective uwsgi_ssl_password_file
syn keyword ngxDirective uwsgi_ssl_protocols nextgroup=ngxSSLProtocol skipwhite
syn keyword ngxDirective uwsgi_ssl_server_name
syn keyword ngxDirective uwsgi_ssl_session_reuse
syn keyword ngxDirective uwsgi_ssl_trusted_certificate
syn keyword ngxDirective uwsgi_ssl_verify
syn keyword ngxDirective uwsgi_ssl_verify_depth
syn keyword ngxDirective uwsgi_store
syn keyword ngxDirective uwsgi_store_access
syn keyword ngxDirective uwsgi_string
syn keyword ngxDirective uwsgi_temp_file_write_size
syn keyword ngxDirective uwsgi_temp_path
syn keyword ngxDirective valid_referers
syn keyword ngxDirective variables_hash_bucket_size
syn keyword ngxDirective variables_hash_max_size
syn keyword ngxDirective worker_aio_requests
syn keyword ngxDirective worker_connections
syn keyword ngxDirective worker_cpu_affinity
syn keyword ngxDirective worker_priority
syn keyword ngxDirective worker_processes
syn keyword ngxDirective worker_rlimit_core
syn keyword ngxDirective worker_rlimit_nofile
syn keyword ngxDirective worker_rlimit_sigpending
syn keyword ngxDirective worker_threads
syn keyword ngxDirective working_directory
syn keyword ngxDirective xclient
syn keyword ngxDirective xml_entities
syn keyword ngxDirective xslt_last_modified
syn keyword ngxDirective xslt_param
syn keyword ngxDirective xslt_string_param
syn keyword ngxDirective xslt_stylesheet
syn keyword ngxDirective xslt_types
syn keyword ngxDirective zone

" Do not enable highlighting of insecure ciphers if sslecure is loaded
if !exists('g:loaded_sslsecure')
  " Mark insecure SSL Ciphers (Note: List might not not complete)
  " Reference: https://www.openssl.org/docs/man1.0.2/apps/ciphers.html
  syn match ngxSSLCipherInsecure '[^!]\zsSSLv3'
  syn match ngxSSLCipherInsecure '[^!]\zsSSLv2'
  syn match ngxSSLCipherInsecure '[^!]\zsHIGH'
  syn match ngxSSLCipherInsecure '[^!]\zsMEDIUM'
  syn match ngxSSLCipherInsecure '[^!]\zsLOW'
  syn match ngxSSLCipherInsecure '[^!]\zsDEFAULT'
  syn match ngxSSLCipherInsecure '[^!]\zsCOMPLEMENTOFDEFAULT'
  syn match ngxSSLCipherInsecure '[^!]\zsALL'
  syn match ngxSSLCipherInsecure '[^!]\zsCOMPLEMENTOFALL'

  " SHA ciphers are only used in HMAC with all known OpenSSL/ LibreSSL cipher suites and MAC
  " usage is still considered safe
  " syn match ngxSSLCipherInsecure '[^!]\zsSHA\ze\D'      " Match SHA1 without matching SHA256+
  " syn match ngxSSLCipherInsecure '[^!]\zsSHA1'
  syn match ngxSSLCipherInsecure '[^!]\zsMD5'
  syn match ngxSSLCipherInsecure '[^!]\zsRC2'
  syn match ngxSSLCipherInsecure '[^!]\zsRC4'
  syn match ngxSSLCipherInsecure '[^!]\zs3DES'
  syn match ngxSSLCipherInsecure '[^!3]\zsDES'
  syn match ngxSSLCipherInsecure '[^!]\zsaDSS'
  syn match ngxSSLCipherInsecure '[^!a]\zsDSS'
  syn match ngxSSLCipherInsecure '[^!]\zsPSK'
  syn match ngxSSLCipherInsecure '[^!]\zsIDEA'
  syn match ngxSSLCipherInsecure '[^!]\zsSEED'
  syn match ngxSSLCipherInsecure '[^!]\zsEXP\w*'        " Match all EXPORT ciphers
  syn match ngxSSLCipherInsecure '[^!]\zsaGOST\w*'      " Match all GOST ciphers
  syn match ngxSSLCipherInsecure '[^!]\zskGOST\w*'
  syn match ngxSSLCipherInsecure '[^!ak]\zsGOST\w*'
  syn match ngxSSLCipherInsecure '[^!]\zs[kae]\?FZA'    " Not implemented
  syn match ngxSSLCipherInsecure '[^!]\zsECB'
  syn match ngxSSLCipherInsecure '[^!]\zs[aes]NULL'

  " Anonymous cipher suites should never be used
  syn match ngxSSLCipherInsecure '[^!ECa]\zsDH\ze[^E]'  " Try to match DH without DHE, EDH, EECDH, etc.
  syn match ngxSSLCipherInsecure '[^!EA]\zsECDH\ze[^E]' " Do not match EECDH, ECDHE
  syn match ngxSSLCipherInsecure '[^!]\zsADH'
  syn match ngxSSLCipherInsecure '[^!]\zskDHE'
  syn match ngxSSLCipherInsecure '[^!]\zskEDH'
  syn match ngxSSLCipherInsecure '[^!]\zskECDHE'
  syn match ngxSSLCipherInsecure '[^!]\zskEECDH'
  syn match ngxSSLCipherInsecure '[^!E]\zsAECDH'
endif

syn keyword ngxProxyNextUpstreamOptions error          contained
syn keyword ngxProxyNextUpstreamOptions timeout        contained
syn keyword ngxProxyNextUpstreamOptions invalid_header contained
syn keyword ngxProxyNextUpstreamOptions http_500       contained
syn keyword ngxProxyNextUpstreamOptions http_502       contained
syn keyword ngxProxyNextUpstreamOptions http_503       contained
syn keyword ngxProxyNextUpstreamOptions http_504       contained
syn keyword ngxProxyNextUpstreamOptions http_403       contained
syn keyword ngxProxyNextUpstreamOptions http_404       contained
syn keyword ngxProxyNextUpstreamOptions http_429       contained
syn keyword ngxProxyNextUpstreamOptions non_idempotent contained
syn keyword ngxProxyNextUpstreamOptions off            contained

syn keyword ngxStickyOptions cookie contained
syn region  ngxStickyOptionsCookie matchgroup=ngxStickyOptions start=+^\s*\zssticky\s\s*cookie\ze\s.*;+ skip=+\\\\\|\\\;+ end=+;+he=e-1 contains=ngxCookieOptions,ngxString,ngxBoolean,ngxInteger,ngxTemplateVar
syn keyword ngxStickyOptions route  contained
syn keyword ngxStickyOptions learn  contained

syn keyword ngxCookieOptions expires  contained
syn keyword ngxCookieOptions domain   contained
syn keyword ngxCookieOptions httponly contained
syn keyword ngxCookieOptions secure   contained
syn keyword ngxCookieOptions path     contained

" 3rd party module list:
" https://www.nginx.com/resources/wiki/modules/

" Accept Language Module <https://www.nginx.com/resources/wiki/modules/accept_language/>
" Parses the Accept-Language header and gives the most suitable locale from a list of supported locales.
syn keyword ngxDirectiveThirdParty set_from_accept_language

" Access Key Module (DEPRECATED) <http://wiki.nginx.org/NginxHttpAccessKeyModule>
" Denies access unless the request URL contains an access key.
syn keyword ngxDirectiveDeprecated accesskey
syn keyword ngxDirectiveDeprecated accesskey_arg
syn keyword ngxDirectiveDeprecated accesskey_hashmethod
syn keyword ngxDirectiveDeprecated accesskey_signature

" Asynchronous FastCGI Module <https://github.com/rsms/afcgi>
" Primarily a modified version of the Nginx FastCGI module which implements multiplexing of connections, allowing a single FastCGI server to handle many concurrent requests.
" syn keyword ngxDirectiveThirdParty fastcgi_bind
" syn keyword ngxDirectiveThirdParty fastcgi_buffer_size
" syn keyword ngxDirectiveThirdParty fastcgi_buffers
" syn keyword ngxDirectiveThirdParty fastcgi_busy_buffers_size
" syn keyword ngxDirectiveThirdParty fastcgi_cache
" syn keyword ngxDirectiveThirdParty fastcgi_cache_key
" syn keyword ngxDirectiveThirdParty fastcgi_cache_methods
" syn keyword ngxDirectiveThirdParty fastcgi_cache_min_uses
" syn keyword ngxDirectiveThirdParty fastcgi_cache_path
" syn keyword ngxDirectiveThirdParty fastcgi_cache_use_stale
" syn keyword ngxDirectiveThirdParty fastcgi_cache_valid
" syn keyword ngxDirectiveThirdParty fastcgi_catch_stderr
" syn keyword ngxDirectiveThirdParty fastcgi_connect_timeout
" syn keyword ngxDirectiveThirdParty fastcgi_hide_header
" syn keyword ngxDirectiveThirdParty fastcgi_ignore_client_abort
" syn keyword ngxDirectiveThirdParty fastcgi_ignore_headers
" syn keyword ngxDirectiveThirdParty fastcgi_index
" syn keyword ngxDirectiveThirdParty fastcgi_intercept_errors
" syn keyword ngxDirectiveThirdParty fastcgi_max_temp_file_size
" syn keyword ngxDirectiveThirdParty fastcgi_next_upstream
" syn keyword ngxDirectiveThirdParty fastcgi_param
" syn keyword ngxDirectiveThirdParty fastcgi_pass
" syn keyword ngxDirectiveThirdParty fastcgi_pass_header
" syn keyword ngxDirectiveThirdParty fastcgi_pass_request_body
" syn keyword ngxDirectiveThirdParty fastcgi_pass_request_headers
" syn keyword ngxDirectiveThirdParty fastcgi_read_timeout
" syn keyword ngxDirectiveThirdParty fastcgi_send_lowat
" syn keyword ngxDirectiveThirdParty fastcgi_send_timeout
" syn keyword ngxDirectiveThirdParty fastcgi_split_path_info
" syn keyword ngxDirectiveThirdParty fastcgi_store
" syn keyword ngxDirectiveThirdParty fastcgi_store_access
" syn keyword ngxDirectiveThirdParty fastcgi_temp_file_write_size
" syn keyword ngxDirectiveThirdParty fastcgi_temp_path
syn keyword ngxDirectiveDeprecated fastcgi_upstream_fail_timeout
syn keyword ngxDirectiveDeprecated fastcgi_upstream_max_fails

" Akamai G2O Module <https://github.com/kaltura/nginx_mod_akamai_g2o>
" Nginx Module for Authenticating Akamai G2O requests
syn keyword ngxDirectiveThirdParty g2o
syn keyword ngxDirectiveThirdParty g2o_nonce
syn keyword ngxDirectiveThirdParty g2o_key

" Lua Module <https://github.com/alacner/nginx_lua_module>
" You can be very simple to execute lua code for nginx
syn keyword ngxDirectiveThirdParty lua_file

" Array Variable Module <https://github.com/openresty/array-var-nginx-module>
" Add support for array-typed variables to nginx config files
syn keyword ngxDirectiveThirdParty array_split
syn keyword ngxDirectiveThirdParty array_join
syn keyword ngxDirectiveThirdParty array_map
syn keyword ngxDirectiveThirdParty array_map_op

" Nginx Audio Track for HTTP Live Streaming <https://github.com/flavioribeiro/nginx-audio-track-for-hls-module>
" This nginx module generates audio track for hls streams on the fly.
syn keyword ngxDirectiveThirdParty ngx_hls_audio_track
syn keyword ngxDirectiveThirdParty ngx_hls_audio_track_rootpath
syn keyword ngxDirectiveThirdParty ngx_hls_audio_track_output_format
syn keyword ngxDirectiveThirdParty ngx_hls_audio_track_output_header

" AWS Proxy Module <https://github.com/anomalizer/ngx_aws_auth>
" Nginx module to proxy to authenticated AWS services
syn keyword ngxDirectiveThirdParty aws_access_key
syn keyword ngxDirectiveThirdParty aws_key_scope
syn keyword ngxDirectiveThirdParty aws_signing_key
syn keyword ngxDirectiveThirdParty aws_endpoint
syn keyword ngxDirectiveThirdParty aws_s3_bucket
syn keyword ngxDirectiveThirdParty aws_sign

" Backtrace module <https://github.com/alibaba/nginx-backtrace>
" A Nginx module to dump backtrace when a worker process exits abnormally
syn keyword ngxDirectiveThirdParty backtrace_log
syn keyword ngxDirectiveThirdParty backtrace_max_stack_size

" Brotli Module <https://github.com/google/ngx_brotli>
" Nginx module for Brotli compression
syn keyword ngxDirectiveThirdParty brotli_static
syn keyword ngxDirectiveThirdParty brotli
syn keyword ngxDirectiveThirdParty brotli_types
syn keyword ngxDirectiveThirdParty brotli_buffers
syn keyword ngxDirectiveThirdParty brotli_comp_level
syn keyword ngxDirectiveThirdParty brotli_window
syn keyword ngxDirectiveThirdParty brotli_min_length

" Cache Purge Module <https://github.com/FRiCKLE/ngx_cache_purge>
" Adds ability to purge content from FastCGI, proxy, SCGI and uWSGI caches.
syn keyword ngxDirectiveThirdParty fastcgi_cache_purge
syn keyword ngxDirectiveThirdParty proxy_cache_purge
" syn keyword ngxDirectiveThirdParty scgi_cache_purge
" syn keyword ngxDirectiveThirdParty uwsgi_cache_purge

" Chunkin Module (DEPRECATED) <http://wiki.nginx.org/NginxHttpChunkinModule>
" HTTP 1.1 chunked-encoding request body support for Nginx.
syn keyword ngxDirectiveDeprecated chunkin
syn keyword ngxDirectiveDeprecated chunkin_keepalive
syn keyword ngxDirectiveDeprecated chunkin_max_chunks_per_buf
syn keyword ngxDirectiveDeprecated chunkin_resume

" Circle GIF Module <https://github.com/evanmiller/nginx_circle_gif>
" Generates simple circle images with the colors and size specified in the URL.
syn keyword ngxDirectiveThirdParty circle_gif
syn keyword ngxDirectiveThirdParty circle_gif_max_radius
syn keyword ngxDirectiveThirdParty circle_gif_min_radius
syn keyword ngxDirectiveThirdParty circle_gif_step_radius

" Nginx-Clojure Module <http://nginx-clojure.github.io/index.html>
" Parses the Accept-Language header and gives the most suitable locale from a list of supported locales.
syn keyword ngxDirectiveThirdParty jvm_path
syn keyword ngxDirectiveThirdParty jvm_var
syn keyword ngxDirectiveThirdParty jvm_classpath
syn keyword ngxDirectiveThirdParty jvm_classpath_check
syn keyword ngxDirectiveThirdParty jvm_workers
syn keyword ngxDirectiveThirdParty jvm_options
syn keyword ngxDirectiveThirdParty jvm_handler_type
syn keyword ngxDirectiveThirdParty jvm_init_handler_name
syn keyword ngxDirectiveThirdParty jvm_init_handler_code
syn keyword ngxDirectiveThirdParty jvm_exit_handler_name
syn keyword ngxDirectiveThirdParty jvm_exit_handler_code
syn keyword ngxDirectiveThirdParty handlers_lazy_init
syn keyword ngxDirectiveThirdParty auto_upgrade_ws
syn keyword ngxDirectiveThirdParty content_handler_type
syn keyword ngxDirectiveThirdParty content_handler_name
syn keyword ngxDirectiveThirdParty content_handler_code
syn keyword ngxDirectiveThirdParty rewrite_handler_type
syn keyword ngxDirectiveThirdParty rewrite_handler_name
syn keyword ngxDirectiveThirdParty rewrite_handler_code
syn keyword ngxDirectiveThirdParty access_handler_type
syn keyword ngxDirectiveThirdParty access_handler_name
syn keyword ngxDirectiveThirdParty access_handler_code
syn keyword ngxDirectiveThirdParty header_filter_type
syn keyword ngxDirectiveThirdParty header_filter_name
syn keyword ngxDirectiveThirdParty header_filter_code
syn keyword ngxDirectiveThirdParty content_handler_property
syn keyword ngxDirectiveThirdParty rewrite_handler_property
syn keyword ngxDirectiveThirdParty access_handler_property
syn keyword ngxDirectiveThirdParty header_filter_property
syn keyword ngxDirectiveThirdParty always_read_body
syn keyword ngxDirectiveThirdParty shared_map
syn keyword ngxDirectiveThirdParty write_page_size

" Upstream Consistent Hash <https://www.nginx.com/resources/wiki/modules/consistent_hash/>
" A load balancer that uses an internal consistent hash ring to select the right backend node.
syn keyword ngxDirectiveThirdParty consistent_hash

" Nginx Development Kit <https://github.com/simpl/ngx_devel_kit>
" The NDK is an Nginx module that is designed to extend the core functionality of the excellent Nginx webserver in a way that can be used as a basis of other Nginx modules.
" NDK_UPSTREAM_LIST
" This submodule provides a directive that creates a list of upstreams, with optional weighting. This list can then be used by other modules to hash over the upstreams however they choose.
syn keyword ngxDirectiveThirdParty upstream_list

" Drizzle Module <https://www.nginx.com/resources/wiki/modules/drizzle/>
" Upstream module for talking to MySQL and Drizzle directly
syn keyword ngxDirectiveThirdParty drizzle_server
syn keyword ngxDirectiveThirdParty drizzle_keepalive
syn keyword ngxDirectiveThirdParty drizzle_query
syn keyword ngxDirectiveThirdParty drizzle_pass
syn keyword ngxDirectiveThirdParty drizzle_connect_timeout
syn keyword ngxDirectiveThirdParty drizzle_send_query_timeout
syn keyword ngxDirectiveThirdParty drizzle_recv_cols_timeout
syn keyword ngxDirectiveThirdParty drizzle_recv_rows_timeout
syn keyword ngxDirectiveThirdParty drizzle_buffer_size
syn keyword ngxDirectiveThirdParty drizzle_module_header
syn keyword ngxDirectiveThirdParty drizzle_status

" Dynamic ETags Module <https://github.com/kali/nginx-dynamic-etags>
" Attempt at handling ETag / If-None-Match on proxied content.
syn keyword ngxDirectiveThirdParty dynamic_etags

" Echo Module <https://www.nginx.com/resources/wiki/modules/echo/>
" Bringing the power of "echo", "sleep", "time" and more to Nginx's config file
syn keyword ngxDirectiveThirdParty echo
syn keyword ngxDirectiveThirdParty echo_duplicate
syn keyword ngxDirectiveThirdParty echo_flush
syn keyword ngxDirectiveThirdParty echo_sleep
syn keyword ngxDirectiveThirdParty echo_blocking_sleep
syn keyword ngxDirectiveThirdParty echo_reset_timer
syn keyword ngxDirectiveThirdParty echo_read_request_body
syn keyword ngxDirectiveThirdParty echo_location_async
syn keyword ngxDirectiveThirdParty echo_location
syn keyword ngxDirectiveThirdParty echo_subrequest_async
syn keyword ngxDirectiveThirdParty echo_subrequest
syn keyword ngxDirectiveThirdParty echo_foreach_split
syn keyword ngxDirectiveThirdParty echo_end
syn keyword ngxDirectiveThirdParty echo_request_body
syn keyword ngxDirectiveThirdParty echo_exec
syn keyword ngxDirectiveThirdParty echo_status
syn keyword ngxDirectiveThirdParty echo_before_body
syn keyword ngxDirectiveThirdParty echo_after_body

" Encrypted Session Module <https://github.com/openresty/encrypted-session-nginx-module>
" Encrypt and decrypt nginx variable values
syn keyword ngxDirectiveThirdParty encrypted_session_key
syn keyword ngxDirectiveThirdParty encrypted_session_iv
syn keyword ngxDirectiveThirdParty encrypted_session_expires
syn keyword ngxDirectiveThirdParty set_encrypt_session
syn keyword ngxDirectiveThirdParty set_decrypt_session

" Enhanced Memcached Module <https://github.com/bpaquet/ngx_http_enhanced_memcached_module>
" This module is based on the standard Nginx Memcached module, with some additonal features
syn keyword ngxDirectiveThirdParty enhanced_memcached_pass
syn keyword ngxDirectiveThirdParty enhanced_memcached_hash_keys_with_md5
syn keyword ngxDirectiveThirdParty enhanced_memcached_allow_put
syn keyword ngxDirectiveThirdParty enhanced_memcached_allow_delete
syn keyword ngxDirectiveThirdParty enhanced_memcached_stats
syn keyword ngxDirectiveThirdParty enhanced_memcached_flush
syn keyword ngxDirectiveThirdParty enhanced_memcached_flush_namespace
syn keyword ngxDirectiveThirdParty enhanced_memcached_bind
syn keyword ngxDirectiveThirdParty enhanced_memcached_connect_timeout
syn keyword ngxDirectiveThirdParty enhanced_memcached_send_timeout
syn keyword ngxDirectiveThirdParty enhanced_memcached_buffer_size
syn keyword ngxDirectiveThirdParty enhanced_memcached_read_timeout

" Events Module (DEPRECATED) <http://docs.dutov.org/nginx_modules_events_en.html>
" Provides options for start/stop events.
syn keyword ngxDirectiveDeprecated on_start
syn keyword ngxDirectiveDeprecated on_stop

" EY Balancer Module <https://github.com/ezmobius/nginx-ey-balancer>
" Adds a request queue to Nginx that allows the limiting of concurrent requests passed to the upstream.
syn keyword ngxDirectiveThirdParty max_connections
syn keyword ngxDirectiveThirdParty max_connections_max_queue_length
syn keyword ngxDirectiveThirdParty max_connections_queue_timeout

" Upstream Fair Balancer <https://www.nginx.com/resources/wiki/modules/fair_balancer/>
" Sends an incoming request to the least-busy backend server, rather than distributing requests round-robin.
syn keyword ngxDirectiveThirdParty fair
syn keyword ngxDirectiveThirdParty upstream_fair_shm_size

" Fancy Indexes Module <https://github.com/aperezdc/ngx-fancyindex>
" Like the built-in autoindex module, but fancier.
syn keyword ngxDirectiveThirdParty fancyindex
syn keyword ngxDirectiveThirdParty fancyindex_default_sort
syn keyword ngxDirectiveThirdParty fancyindex_directories_first
syn keyword ngxDirectiveThirdParty fancyindex_css_href
syn keyword ngxDirectiveThirdParty fancyindex_exact_size
syn keyword ngxDirectiveThirdParty fancyindex_name_length
syn keyword ngxDirectiveThirdParty fancyindex_footer
syn keyword ngxDirectiveThirdParty fancyindex_header
syn keyword ngxDirectiveThirdParty fancyindex_show_path
syn keyword ngxDirectiveThirdParty fancyindex_ignore
syn keyword ngxDirectiveThirdParty fancyindex_hide_symlinks
syn keyword ngxDirectiveThirdParty fancyindex_localtime
syn keyword ngxDirectiveThirdParty fancyindex_time_format

" Form Auth Module <https://github.com/veruu/ngx_form_auth>
" Provides authentication and authorization with credentials submitted via POST request
syn keyword ngxDirectiveThirdParty form_auth
syn keyword ngxDirectiveThirdParty form_auth_pam_service
syn keyword ngxDirectiveThirdParty form_auth_login
syn keyword ngxDirectiveThirdParty form_auth_password
syn keyword ngxDirectiveThirdParty form_auth_remote_user

" Form Input Module <https://github.com/calio/form-input-nginx-module>
" Reads HTTP POST and PUT request body encoded in "application/x-www-form-urlencoded" and parses the arguments into nginx variables.
syn keyword ngxDirectiveThirdParty set_form_input
syn keyword ngxDirectiveThirdParty set_form_input_multi

" GeoIP Module (DEPRECATED) <http://wiki.nginx.org/NginxHttp3rdPartyGeoIPModule>
" Country code lookups via the MaxMind GeoIP API.
syn keyword ngxDirectiveDeprecated geoip_country_file

" GeoIP 2 Module <https://github.com/leev/ngx_http_geoip2_module>
" Creates variables with values from the maxmind geoip2 databases based on the client IP
syn keyword ngxDirectiveThirdParty geoip2

" GridFS Module <https://github.com/mdirolf/nginx-gridfs>
" Nginx module for serving files from MongoDB's GridFS
syn keyword ngxDirectiveThirdParty gridfs

" Headers More Module <https://github.com/openresty/headers-more-nginx-module>
" Set and clear input and output headers...more than "add"!
syn keyword ngxDirectiveThirdParty more_clear_headers
syn keyword ngxDirectiveThirdParty more_clear_input_headers
syn keyword ngxDirectiveThirdParty more_set_headers
syn keyword ngxDirectiveThirdParty more_set_input_headers

" Health Checks Upstreams Module <https://www.nginx.com/resources/wiki/modules/healthcheck/>
" Polls backends and if they respond with HTTP 200 + an optional request body, they are marked good. Otherwise, they are marked bad.
syn keyword ngxDirectiveThirdParty healthcheck_enabled
syn keyword ngxDirectiveThirdParty healthcheck_delay
syn keyword ngxDirectiveThirdParty healthcheck_timeout
syn keyword ngxDirectiveThirdParty healthcheck_failcount
syn keyword ngxDirectiveThirdParty healthcheck_send
syn keyword ngxDirectiveThirdParty healthcheck_expected
syn keyword ngxDirectiveThirdParty healthcheck_buffer
syn keyword ngxDirectiveThirdParty healthcheck_status

" HTTP Accounting Module <https://github.com/Lax/ngx_http_accounting_module>
" Add traffic stat function to nginx. Useful for http accounting based on nginx configuration logic
syn keyword ngxDirectiveThirdParty http_accounting
syn keyword ngxDirectiveThirdParty http_accounting_log
syn keyword ngxDirectiveThirdParty http_accounting_id
syn keyword ngxDirectiveThirdParty http_accounting_interval
syn keyword ngxDirectiveThirdParty http_accounting_perturb

" Nginx Digest Authentication module <https://github.com/atomx/nginx-http-auth-digest>
" Digest Authentication for Nginx
syn keyword ngxDirectiveThirdParty auth_digest
syn keyword ngxDirectiveThirdParty auth_digest_user_file
syn keyword ngxDirectiveThirdParty auth_digest_timeout
syn keyword ngxDirectiveThirdParty auth_digest_expires
syn keyword ngxDirectiveThirdParty auth_digest_replays
syn keyword ngxDirectiveThirdParty auth_digest_shm_size

" Auth PAM Module <https://github.com/sto/ngx_http_auth_pam_module>
" HTTP Basic Authentication using PAM.
syn keyword ngxDirectiveThirdParty auth_pam
syn keyword ngxDirectiveThirdParty auth_pam_service_name

" HTTP Auth Request Module <http://nginx.org/en/docs/http/ngx_http_auth_request_module.html>
" Implements client authorization based on the result of a subrequest
" syn keyword ngxDirectiveThirdParty auth_request
" syn keyword ngxDirectiveThirdParty auth_request_set

" HTTP Concatenation module for Nginx <https://github.com/alibaba/nginx-http-concat>
" A Nginx module for concatenating files in a given context: CSS and JS files usually
syn keyword ngxDirectiveThirdParty concat
syn keyword ngxDirectiveThirdParty concat_types
syn keyword ngxDirectiveThirdParty concat_unique
syn keyword ngxDirectiveThirdParty concat_max_files
syn keyword ngxDirectiveThirdParty concat_delimiter
syn keyword ngxDirectiveThirdParty concat_ignore_file_error

" HTTP Dynamic Upstream Module <https://github.com/yzprofile/ngx_http_dyups_module>
" Update upstreams' config by restful interface
syn keyword ngxDirectiveThirdParty dyups_interface
syn keyword ngxDirectiveThirdParty dyups_read_msg_timeout
syn keyword ngxDirectiveThirdParty dyups_shm_zone_size
syn keyword ngxDirectiveThirdParty dyups_upstream_conf
syn keyword ngxDirectiveThirdParty dyups_trylock

" HTTP Footer If Filter Module <https://github.com/flygoast/ngx_http_footer_if_filter>
" The ngx_http_footer_if_filter_module is used to add given content to the end of the response according to the condition specified.
syn keyword ngxDirectiveThirdParty footer_if

" HTTP Footer Filter Module <https://github.com/alibaba/nginx-http-footer-filter>
" This module implements a body filter that adds a given string to the page footer.
syn keyword ngxDirectiveThirdParty footer
syn keyword ngxDirectiveThirdParty footer_types

" HTTP Internal Redirect Module <https://github.com/flygoast/ngx_http_internal_redirect>
" Make an internal redirect to the uri specified according to the condition specified.
syn keyword ngxDirectiveThirdParty internal_redirect_if
syn keyword ngxDirectiveThirdParty internal_redirect_if_no_postponed

" HTTP JavaScript Module <https://github.com/peter-leonov/ngx_http_js_module>
" Embedding SpiderMonkey. Nearly full port on Perl module.
syn keyword ngxDirectiveThirdParty js
syn keyword ngxDirectiveThirdParty js_filter
syn keyword ngxDirectiveThirdParty js_filter_types
syn keyword ngxDirectiveThirdParty js_load
syn keyword ngxDirectiveThirdParty js_maxmem
syn keyword ngxDirectiveThirdParty js_require
syn keyword ngxDirectiveThirdParty js_set
syn keyword ngxDirectiveThirdParty js_utf8

" HTTP Push Module (DEPRECATED) <http://pushmodule.slact.net/>
" Turn Nginx into an adept long-polling HTTP Push (Comet) server.
syn keyword ngxDirectiveDeprecated push_buffer_size
syn keyword ngxDirectiveDeprecated push_listener
syn keyword ngxDirectiveDeprecated push_message_timeout
syn keyword ngxDirectiveDeprecated push_queue_messages
syn keyword ngxDirectiveDeprecated push_sender

" HTTP Redis Module <https://www.nginx.com/resources/wiki/modules/redis/>
" Redis <http://code.google.com/p/redis/> support.
syn keyword ngxDirectiveThirdParty redis_bind
syn keyword ngxDirectiveThirdParty redis_buffer_size
syn keyword ngxDirectiveThirdParty redis_connect_timeout
syn keyword ngxDirectiveThirdParty redis_next_upstream
syn keyword ngxDirectiveThirdParty redis_pass
syn keyword ngxDirectiveThirdParty redis_read_timeout
syn keyword ngxDirectiveThirdParty redis_send_timeout

" Iconv Module <https://github.com/calio/iconv-nginx-module>
" A character conversion nginx module using libiconv
syn keyword ngxDirectiveThirdParty set_iconv
syn keyword ngxDirectiveThirdParty iconv_buffer_size
syn keyword ngxDirectiveThirdParty iconv_filter

" IP Blocker Module <https://github.com/tmthrgd/nginx-ip-blocker>
" An efficient shared memory IP blocking system for nginx.
syn keyword ngxDirectiveThirdParty ip_blocker

" IP2Location Module <https://github.com/chrislim2888/ip2location-nginx>
" Allows user to lookup for geolocation information using IP2Location database
syn keyword ngxDirectiveThirdParty ip2location_database

" JS Module <https://github.com/peter-leonov/ngx_http_js_module>
" Reflect the nginx functionality in JS
syn keyword ngxDirectiveThirdParty js
syn keyword ngxDirectiveThirdParty js_access
syn keyword ngxDirectiveThirdParty js_load
syn keyword ngxDirectiveThirdParty js_set

" Limit Upload Rate Module <https://github.com/cfsego/limit_upload_rate>
" Limit client-upload rate when they are sending request bodies to you
syn keyword ngxDirectiveThirdParty limit_upload_rate
syn keyword ngxDirectiveThirdParty limit_upload_rate_after

" Limit Upstream Module <https://github.com/cfsego/nginx-limit-upstream>
" Limit the number of connections to upstream for NGINX
syn keyword ngxDirectiveThirdParty limit_upstream_zone
syn keyword ngxDirectiveThirdParty limit_upstream_conn
syn keyword ngxDirectiveThirdParty limit_upstream_log_level

" Log If Module <https://github.com/cfsego/ngx_log_if>
" Conditional accesslog for nginx
syn keyword ngxDirectiveThirdParty access_log_bypass_if

" Log Request Speed (DEPRECATED) <http://wiki.nginx.org/NginxHttpLogRequestSpeed>
" Log the time it took to process each request.
syn keyword ngxDirectiveDeprecated log_request_speed_filter
syn keyword ngxDirectiveDeprecated log_request_speed_filter_timeout

" Log ZeroMQ Module <https://github.com/alticelabs/nginx-log-zmq>
" ZeroMQ logger module for nginx
syn keyword ngxDirectiveThirdParty log_zmq_server
syn keyword ngxDirectiveThirdParty log_zmq_endpoint
syn keyword ngxDirectiveThirdParty log_zmq_format
syn keyword ngxDirectiveThirdParty log_zmq_off

" Lower/UpperCase Module <https://github.com/replay/ngx_http_lower_upper_case>
" This module simply uppercases or lowercases a string and saves it into a new variable.
syn keyword ngxDirectiveThirdParty lower
syn keyword ngxDirectiveThirdParty upper

" Lua Upstream Module <https://github.com/openresty/lua-upstream-nginx-module>
" Nginx C module to expose Lua API to ngx_lua for Nginx upstreams

" Lua Module <https://github.com/openresty/lua-nginx-module>
" Embed the Power of Lua into NGINX HTTP servers
syn keyword ngxDirectiveThirdParty lua_use_default_type
syn keyword ngxDirectiveThirdParty lua_malloc_trim
syn keyword ngxDirectiveThirdParty lua_code_cache
syn keyword ngxDirectiveThirdParty lua_regex_cache_max_entries
syn keyword ngxDirectiveThirdParty lua_regex_match_limit
syn keyword ngxDirectiveThirdParty lua_package_path
syn keyword ngxDirectiveThirdParty lua_package_cpath
syn keyword ngxDirectiveThirdParty init_by_lua
syn keyword ngxDirectiveThirdParty init_by_lua_file
syn keyword ngxDirectiveThirdParty init_worker_by_lua
syn keyword ngxDirectiveThirdParty init_worker_by_lua_file
syn keyword ngxDirectiveThirdParty set_by_lua
syn keyword ngxDirectiveThirdParty set_by_lua_file
syn keyword ngxDirectiveThirdParty content_by_lua
syn keyword ngxDirectiveThirdParty content_by_lua_file
syn keyword ngxDirectiveThirdParty rewrite_by_lua
syn keyword ngxDirectiveThirdParty rewrite_by_lua_file
syn keyword ngxDirectiveThirdParty access_by_lua
syn keyword ngxDirectiveThirdParty access_by_lua_file
syn keyword ngxDirectiveThirdParty header_filter_by_lua
syn keyword ngxDirectiveThirdParty header_filter_by_lua_file
syn keyword ngxDirectiveThirdParty body_filter_by_lua
syn keyword ngxDirectiveThirdParty body_filter_by_lua_file
syn keyword ngxDirectiveThirdParty log_by_lua
syn keyword ngxDirectiveThirdParty log_by_lua_file
syn keyword ngxDirectiveThirdParty balancer_by_lua_file
syn keyword ngxDirectiveThirdParty lua_need_request_body
syn keyword ngxDirectiveThirdParty ssl_certificate_by_lua_file
syn keyword ngxDirectiveThirdParty ssl_session_fetch_by_lua_file
syn keyword ngxDirectiveThirdParty ssl_session_store_by_lua_file
syn keyword ngxDirectiveThirdParty lua_shared_dict
syn keyword ngxDirectiveThirdParty lua_socket_connect_timeout
syn keyword ngxDirectiveThirdParty lua_socket_send_timeout
syn keyword ngxDirectiveThirdParty lua_socket_send_lowat
syn keyword ngxDirectiveThirdParty lua_socket_read_timeout
syn keyword ngxDirectiveThirdParty lua_socket_buffer_size
syn keyword ngxDirectiveThirdParty lua_socket_pool_size
syn keyword ngxDirectiveThirdParty lua_socket_keepalive_timeout
syn keyword ngxDirectiveThirdParty lua_socket_log_errors
syn keyword ngxDirectiveThirdParty lua_ssl_ciphers
syn keyword ngxDirectiveThirdParty lua_ssl_crl
syn keyword ngxDirectiveThirdParty lua_ssl_protocols
syn keyword ngxDirectiveThirdParty lua_ssl_trusted_certificate
syn keyword ngxDirectiveThirdParty lua_ssl_verify_depth
syn keyword ngxDirectiveThirdParty lua_http10_buffering
syn keyword ngxDirectiveThirdParty rewrite_by_lua_no_postpone
syn keyword ngxDirectiveThirdParty access_by_lua_no_postpone
syn keyword ngxDirectiveThirdParty lua_transform_underscores_in_response_headers
syn keyword ngxDirectiveThirdParty lua_check_client_abort
syn keyword ngxDirectiveThirdParty lua_max_pending_timers
syn keyword ngxDirectiveThirdParty lua_max_running_timers

" MD5 Filter Module <https://github.com/kainswor/nginx_md5_filter>
" A content filter for nginx, which returns the md5 hash of the content otherwise returned.
syn keyword ngxDirectiveThirdParty md5_filter

" Memc Module <https://github.com/openresty/memc-nginx-module>
" An extended version of the standard memcached module that supports set, add, delete, and many more memcached commands.
syn keyword ngxDirectiveThirdParty memc_buffer_size
syn keyword ngxDirectiveThirdParty memc_cmds_allowed
syn keyword ngxDirectiveThirdParty memc_connect_timeout
syn keyword ngxDirectiveThirdParty memc_flags_to_last_modified
syn keyword ngxDirectiveThirdParty memc_next_upstream
syn keyword ngxDirectiveThirdParty memc_pass
syn keyword ngxDirectiveThirdParty memc_read_timeout
syn keyword ngxDirectiveThirdParty memc_send_timeout
syn keyword ngxDirectiveThirdParty memc_upstream_fail_timeout
syn keyword ngxDirectiveThirdParty memc_upstream_max_fails

" Mod Security Module <https://github.com/SpiderLabs/ModSecurity>
" ModSecurity is an open source, cross platform web application firewall (WAF) engine
syn keyword ngxDirectiveThirdParty ModSecurityConfig
syn keyword ngxDirectiveThirdParty ModSecurityEnabled
syn keyword ngxDirectiveThirdParty pool_context
syn keyword ngxDirectiveThirdParty pool_context_hash_size

" Mogilefs Module <http://www.grid.net.ru/nginx/mogilefs.en.html>
" MogileFS client for nginx web server.
syn keyword ngxDirectiveThirdParty mogilefs_pass
syn keyword ngxDirectiveThirdParty mogilefs_methods
syn keyword ngxDirectiveThirdParty mogilefs_domain
syn keyword ngxDirectiveThirdParty mogilefs_class
syn keyword ngxDirectiveThirdParty mogilefs_tracker
syn keyword ngxDirectiveThirdParty mogilefs_noverify
syn keyword ngxDirectiveThirdParty mogilefs_connect_timeout
syn keyword ngxDirectiveThirdParty mogilefs_send_timeout
syn keyword ngxDirectiveThirdParty mogilefs_read_timeout

" Mongo Module <https://github.com/simpl/ngx_mongo>
" Upstream module that allows nginx to communicate directly with MongoDB database.
syn keyword ngxDirectiveThirdParty mongo_auth
syn keyword ngxDirectiveThirdParty mongo_pass
syn keyword ngxDirectiveThirdParty mongo_query
syn keyword ngxDirectiveThirdParty mongo_json
syn keyword ngxDirectiveThirdParty mongo_bind
syn keyword ngxDirectiveThirdParty mongo_connect_timeout
syn keyword ngxDirectiveThirdParty mongo_send_timeout
syn keyword ngxDirectiveThirdParty mongo_read_timeout
syn keyword ngxDirectiveThirdParty mongo_buffering
syn keyword ngxDirectiveThirdParty mongo_buffer_size
syn keyword ngxDirectiveThirdParty mongo_buffers
syn keyword ngxDirectiveThirdParty mongo_busy_buffers_size
syn keyword ngxDirectiveThirdParty mongo_next_upstream

" MP4 Streaming Lite Module <https://www.nginx.com/resources/wiki/modules/mp4_streaming/>
" Will seek to a certain time within H.264/MP4 files when provided with a 'start' parameter in the URL.
" syn keyword ngxDirectiveThirdParty mp4

" NAXSI Module <https://github.com/nbs-system/naxsi>
" NAXSI is an open-source, high performance, low rules maintenance WAF for NGINX
syn keyword ngxDirectiveThirdParty DeniedUrl denied_url
syn keyword ngxDirectiveThirdParty LearningMode learning_mode
syn keyword ngxDirectiveThirdParty SecRulesEnabled rules_enabled
syn keyword ngxDirectiveThirdParty SecRulesDisabled rules_disabled
syn keyword ngxDirectiveThirdParty CheckRule check_rule
syn keyword ngxDirectiveThirdParty BasicRule basic_rule
syn keyword ngxDirectiveThirdParty MainRule main_rule
syn keyword ngxDirectiveThirdParty LibInjectionSql libinjection_sql
syn keyword ngxDirectiveThirdParty LibInjectionXss libinjection_xss

" Nchan Module <https://nchan.slact.net/>
" Fast, horizontally scalable, multiprocess pub/sub queuing server and proxy for HTTP, long-polling, Websockets and EventSource (SSE)
syn keyword ngxDirectiveThirdParty nchan_channel_id
syn keyword ngxDirectiveThirdParty nchan_channel_id_split_delimiter
syn keyword ngxDirectiveThirdParty nchan_eventsource_event
syn keyword ngxDirectiveThirdParty nchan_longpoll_multipart_response
syn keyword ngxDirectiveThirdParty nchan_publisher
syn keyword ngxDirectiveThirdParty nchan_publisher_channel_id
syn keyword ngxDirectiveThirdParty nchan_publisher_upstream_request
syn keyword ngxDirectiveThirdParty nchan_pubsub
syn keyword ngxDirectiveThirdParty nchan_subscribe_request
syn keyword ngxDirectiveThirdParty nchan_subscriber
syn keyword ngxDirectiveThirdParty nchan_subscriber_channel_id
syn keyword ngxDirectiveThirdParty nchan_subscriber_compound_etag_message_id
syn keyword ngxDirectiveThirdParty nchan_subscriber_first_message
syn keyword ngxDirectiveThirdParty nchan_subscriber_http_raw_stream_separator
syn keyword ngxDirectiveThirdParty nchan_subscriber_last_message_id
syn keyword ngxDirectiveThirdParty nchan_subscriber_message_id_custom_etag_header
syn keyword ngxDirectiveThirdParty nchan_subscriber_timeout
syn keyword ngxDirectiveThirdParty nchan_unsubscribe_request
syn keyword ngxDirectiveThirdParty nchan_websocket_ping_interval
syn keyword ngxDirectiveThirdParty nchan_authorize_request
syn keyword ngxDirectiveThirdParty nchan_max_reserved_memory
syn keyword ngxDirectiveThirdParty nchan_message_buffer_length
syn keyword ngxDirectiveThirdParty nchan_message_timeout
syn keyword ngxDirectiveThirdParty nchan_redis_idle_channel_cache_timeout
syn keyword ngxDirectiveThirdParty nchan_redis_namespace
syn keyword ngxDirectiveThirdParty nchan_redis_pass
syn keyword ngxDirectiveThirdParty nchan_redis_ping_interval
syn keyword ngxDirectiveThirdParty nchan_redis_server
syn keyword ngxDirectiveThirdParty nchan_redis_storage_mode
syn keyword ngxDirectiveThirdParty nchan_redis_url
syn keyword ngxDirectiveThirdParty nchan_store_messages
syn keyword ngxDirectiveThirdParty nchan_use_redis
syn keyword ngxDirectiveThirdParty nchan_access_control_allow_origin
syn keyword ngxDirectiveThirdParty nchan_channel_group
syn keyword ngxDirectiveThirdParty nchan_channel_group_accounting
syn keyword ngxDirectiveThirdParty nchan_group_location
syn keyword ngxDirectiveThirdParty nchan_group_max_channels
syn keyword ngxDirectiveThirdParty nchan_group_max_messages
syn keyword ngxDirectiveThirdParty nchan_group_max_messages_disk
syn keyword ngxDirectiveThirdParty nchan_group_max_messages_memory
syn keyword ngxDirectiveThirdParty nchan_group_max_subscribers
syn keyword ngxDirectiveThirdParty nchan_subscribe_existing_channels_only
syn keyword ngxDirectiveThirdParty nchan_channel_event_string
syn keyword ngxDirectiveThirdParty nchan_channel_events_channel_id
syn keyword ngxDirectiveThirdParty nchan_stub_status
syn keyword ngxDirectiveThirdParty nchan_max_channel_id_length
syn keyword ngxDirectiveThirdParty nchan_max_channel_subscribers
syn keyword ngxDirectiveThirdParty nchan_channel_timeout
syn keyword ngxDirectiveThirdParty nchan_storage_engine

" Nginx Notice Module <https://github.com/kr/nginx-notice>
" Serve static file to POST requests.
syn keyword ngxDirectiveThirdParty notice
syn keyword ngxDirectiveThirdParty notice_type

" OCSP Proxy Module <https://github.com/kyprizel/nginx_ocsp_proxy-module>
" Nginx OCSP processing module designed for response caching
syn keyword ngxDirectiveThirdParty ocsp_proxy
syn keyword ngxDirectiveThirdParty ocsp_cache_timeout

" Eval Module <https://github.com/openresty/nginx-eval-module>
" Module for nginx web server evaluates response of proxy or memcached module into variables.
syn keyword ngxDirectiveThirdParty eval
syn keyword ngxDirectiveThirdParty eval_escalate
syn keyword ngxDirectiveThirdParty eval_buffer_size
syn keyword ngxDirectiveThirdParty eval_override_content_type
syn keyword ngxDirectiveThirdParty eval_subrequest_in_memory

" OpenSSL Version Module <https://github.com/apcera/nginx-openssl-version>
" Nginx OpenSSL version check at startup
syn keyword ngxDirectiveThirdParty openssl_version_minimum
syn keyword ngxDirectiveThirdParty openssl_builddate_minimum

" Owner Match Module <https://www.nginx.com/resources/wiki/modules/owner_match/>
" Control access for specific owners and groups of files
syn keyword ngxDirectiveThirdParty omallow
syn keyword ngxDirectiveThirdParty omdeny

" Accept Language Module <https://www.nginx.com/resources/wiki/modules/accept_language/>
" Parses the Accept-Language header and gives the most suitable locale from a list of supported locales.
syn keyword ngxDirectiveThirdParty pagespeed

" PHP Memcache Standard Balancer Module <https://github.com/replay/ngx_http_php_memcache_standard_balancer>
" Loadbalancer that is compatible to the standard loadbalancer in the php-memcache module
syn keyword ngxDirectiveThirdParty hash_key

" PHP Session Module <https://github.com/replay/ngx_http_php_session>
" Nginx module to parse php sessions
syn keyword ngxDirectiveThirdParty php_session_parse
syn keyword ngxDirectiveThirdParty php_session_strip_formatting

" Phusion Passenger Module <https://www.phusionpassenger.com/library/config/nginx/>
" Passenger is an open source web application server.
syn keyword ngxDirectiveThirdParty passenger_root
syn keyword ngxDirectiveThirdParty passenger_enabled
syn keyword ngxDirectiveThirdParty passenger_base_uri
syn keyword ngxDirectiveThirdParty passenger_document_root
syn keyword ngxDirectiveThirdParty passenger_ruby
syn keyword ngxDirectiveThirdParty passenger_python
syn keyword ngxDirectiveThirdParty passenger_nodejs
syn keyword ngxDirectiveThirdParty passenger_meteor_app_settings
syn keyword ngxDirectiveThirdParty passenger_app_env
syn keyword ngxDirectiveThirdParty passenger_app_root
syn keyword ngxDirectiveThirdParty passenger_app_group_name
syn keyword ngxDirectiveThirdParty passenger_app_type
syn keyword ngxDirectiveThirdParty passenger_startup_file
syn keyword ngxDirectiveThirdParty passenger_restart_dir
syn keyword ngxDirectiveThirdParty passenger_spawn_method
syn keyword ngxDirectiveThirdParty passenger_env_var
syn keyword ngxDirectiveThirdParty passenger_load_shell_envvars
syn keyword ngxDirectiveThirdParty passenger_rolling_restarts
syn keyword ngxDirectiveThirdParty passenger_resist_deployment_errors
syn keyword ngxDirectiveThirdParty passenger_user_switching
syn keyword ngxDirectiveThirdParty passenger_user
syn keyword ngxDirectiveThirdParty passenger_group
syn keyword ngxDirectiveThirdParty passenger_default_user
syn keyword ngxDirectiveThirdParty passenger_default_group
syn keyword ngxDirectiveThirdParty passenger_show_version_in_header
syn keyword ngxDirectiveThirdParty passenger_friendly_error_pages
syn keyword ngxDirectiveThirdParty passenger_disable_security_update_check
syn keyword ngxDirectiveThirdParty passenger_security_update_check_proxy
syn keyword ngxDirectiveThirdParty passenger_max_pool_size
syn keyword ngxDirectiveThirdParty passenger_min_instances
syn keyword ngxDirectiveThirdParty passenger_max_instances
syn keyword ngxDirectiveThirdParty passenger_max_instances_per_app
syn keyword ngxDirectiveThirdParty passenger_pool_idle_time
syn keyword ngxDirectiveThirdParty passenger_max_preloader_idle_time
syn keyword ngxDirectiveThirdParty passenger_force_max_concurrent_requests_per_process
syn keyword ngxDirectiveThirdParty passenger_start_timeout
syn keyword ngxDirectiveThirdParty passenger_concurrency_model
syn keyword ngxDirectiveThirdParty passenger_thread_count
syn keyword ngxDirectiveThirdParty passenger_max_requests
syn keyword ngxDirectiveThirdParty passenger_max_request_time
syn keyword ngxDirectiveThirdParty passenger_memory_limit
syn keyword ngxDirectiveThirdParty passenger_stat_throttle_rate
syn keyword ngxDirectiveThirdParty passenger_core_file_descriptor_ulimit
syn keyword ngxDirectiveThirdParty passenger_app_file_descriptor_ulimit
syn keyword ngxDirectiveThirdParty passenger_pre_start
syn keyword ngxDirectiveThirdParty passenger_set_header
syn keyword ngxDirectiveThirdParty passenger_max_request_queue_size
syn keyword ngxDirectiveThirdParty passenger_request_queue_overflow_status_code
syn keyword ngxDirectiveThirdParty passenger_sticky_sessions
syn keyword ngxDirectiveThirdParty passenger_sticky_sessions_cookie_name
syn keyword ngxDirectiveThirdParty passenger_abort_websockets_on_process_shutdown
syn keyword ngxDirectiveThirdParty passenger_ignore_client_abort
syn keyword ngxDirectiveThirdParty passenger_intercept_errors
syn keyword ngxDirectiveThirdParty passenger_pass_header
syn keyword ngxDirectiveThirdParty passenger_ignore_headers
syn keyword ngxDirectiveThirdParty passenger_headers_hash_bucket_size
syn keyword ngxDirectiveThirdParty passenger_headers_hash_max_size
syn keyword ngxDirectiveThirdParty passenger_buffer_response
syn keyword ngxDirectiveThirdParty passenger_response_buffer_high_watermark
syn keyword ngxDirectiveThirdParty passenger_buffer_size, passenger_buffers, passenger_busy_buffers_size
syn keyword ngxDirectiveThirdParty passenger_socket_backlog
syn keyword ngxDirectiveThirdParty passenger_log_level
syn keyword ngxDirectiveThirdParty passenger_log_file
syn keyword ngxDirectiveThirdParty passenger_file_descriptor_log_file
syn keyword ngxDirectiveThirdParty passenger_debugger
syn keyword ngxDirectiveThirdParty passenger_instance_registry_dir
syn keyword ngxDirectiveThirdParty passenger_data_buffer_dir
syn keyword ngxDirectiveThirdParty passenger_fly_with
syn keyword ngxDirectiveThirdParty union_station_support
syn keyword ngxDirectiveThirdParty union_station_key
syn keyword ngxDirectiveThirdParty union_station_proxy_address
syn keyword ngxDirectiveThirdParty union_station_filter
syn keyword ngxDirectiveThirdParty union_station_gateway_address
syn keyword ngxDirectiveThirdParty union_station_gateway_port
syn keyword ngxDirectiveThirdParty union_station_gateway_cert
syn keyword ngxDirectiveDeprecated rails_spawn_method
syn keyword ngxDirectiveDeprecated passenger_debug_log_file

" Postgres Module <http://labs.frickle.com/nginx_ngx_postgres/>
" Upstream module that allows nginx to communicate directly with PostgreSQL database.
syn keyword ngxDirectiveThirdParty postgres_server
syn keyword ngxDirectiveThirdParty postgres_keepalive
syn keyword ngxDirectiveThirdParty postgres_pass
syn keyword ngxDirectiveThirdParty postgres_query
syn keyword ngxDirectiveThirdParty postgres_rewrite
syn keyword ngxDirectiveThirdParty postgres_output
syn keyword ngxDirectiveThirdParty postgres_set
syn keyword ngxDirectiveThirdParty postgres_escape
syn keyword ngxDirectiveThirdParty postgres_connect_timeout
syn keyword ngxDirectiveThirdParty postgres_result_timeout

" Pubcookie Module <https://www.vanko.me/book/page/pubcookie-module-nginx>
" Authorizes users using encrypted cookies
syn keyword ngxDirectiveThirdParty pubcookie_inactive_expire
syn keyword ngxDirectiveThirdParty pubcookie_hard_expire
syn keyword ngxDirectiveThirdParty pubcookie_app_id
syn keyword ngxDirectiveThirdParty pubcookie_dir_depth
syn keyword ngxDirectiveThirdParty pubcookie_catenate_app_ids
syn keyword ngxDirectiveThirdParty pubcookie_app_srv_id
syn keyword ngxDirectiveThirdParty pubcookie_login
syn keyword ngxDirectiveThirdParty pubcookie_login_method
syn keyword ngxDirectiveThirdParty pubcookie_post
syn keyword ngxDirectiveThirdParty pubcookie_domain
syn keyword ngxDirectiveThirdParty pubcookie_granting_cert_file
syn keyword ngxDirectiveThirdParty pubcookie_session_key_file
syn keyword ngxDirectiveThirdParty pubcookie_session_cert_file
syn keyword ngxDirectiveThirdParty pubcookie_crypt_key_file
syn keyword ngxDirectiveThirdParty pubcookie_end_session
syn keyword ngxDirectiveThirdParty pubcookie_encryption
syn keyword ngxDirectiveThirdParty pubcookie_session_reauth
syn keyword ngxDirectiveThirdParty pubcookie_auth_type_names
syn keyword ngxDirectiveThirdParty pubcookie_no_prompt
syn keyword ngxDirectiveThirdParty pubcookie_on_demand
syn keyword ngxDirectiveThirdParty pubcookie_addl_request
syn keyword ngxDirectiveThirdParty pubcookie_no_obscure_cookies
syn keyword ngxDirectiveThirdParty pubcookie_no_clean_creds
syn keyword ngxDirectiveThirdParty pubcookie_egd_device
syn keyword ngxDirectiveThirdParty pubcookie_no_blank
syn keyword ngxDirectiveThirdParty pubcookie_super_debug
syn keyword ngxDirectiveThirdParty pubcookie_set_remote_user

" Push Stream Module <https://github.com/wandenberg/nginx-push-stream-module>
" A pure stream http push technology for your Nginx setup
syn keyword ngxDirectiveThirdParty push_stream_channels_statistics
syn keyword ngxDirectiveThirdParty push_stream_publisher
syn keyword ngxDirectiveThirdParty push_stream_subscriber
syn keyword ngxDirectiveThirdParty push_stream_shared_memory_size
syn keyword ngxDirectiveThirdParty push_stream_channel_deleted_message_text
syn keyword ngxDirectiveThirdParty push_stream_channel_inactivity_time
syn keyword ngxDirectiveThirdParty push_stream_ping_message_text
syn keyword ngxDirectiveThirdParty push_stream_timeout_with_body
syn keyword ngxDirectiveThirdParty push_stream_message_ttl
syn keyword ngxDirectiveThirdParty push_stream_max_subscribers_per_channel
syn keyword ngxDirectiveThirdParty push_stream_max_messages_stored_per_channel
syn keyword ngxDirectiveThirdParty push_stream_max_channel_id_length
syn keyword ngxDirectiveThirdParty push_stream_max_number_of_channels
syn keyword ngxDirectiveThirdParty push_stream_max_number_of_wildcard_channels
syn keyword ngxDirectiveThirdParty push_stream_wildcard_channel_prefix
syn keyword ngxDirectiveThirdParty push_stream_events_channel_id
syn keyword ngxDirectiveThirdParty push_stream_channels_path
syn keyword ngxDirectiveThirdParty push_stream_store_messages
syn keyword ngxDirectiveThirdParty push_stream_channel_info_on_publish
syn keyword ngxDirectiveThirdParty push_stream_authorized_channels_only
syn keyword ngxDirectiveThirdParty push_stream_header_template_file
syn keyword ngxDirectiveThirdParty push_stream_header_template
syn keyword ngxDirectiveThirdParty push_stream_message_template
syn keyword ngxDirectiveThirdParty push_stream_footer_template
syn keyword ngxDirectiveThirdParty push_stream_wildcard_channel_max_qtd
syn keyword ngxDirectiveThirdParty push_stream_ping_message_interval
syn keyword ngxDirectiveThirdParty push_stream_subscriber_connection_ttl
syn keyword ngxDirectiveThirdParty push_stream_longpolling_connection_ttl
syn keyword ngxDirectiveThirdParty push_stream_websocket_allow_publish
syn keyword ngxDirectiveThirdParty push_stream_last_received_message_time
syn keyword ngxDirectiveThirdParty push_stream_last_received_message_tag
syn keyword ngxDirectiveThirdParty push_stream_last_event_id
syn keyword ngxDirectiveThirdParty push_stream_user_agent
syn keyword ngxDirectiveThirdParty push_stream_padding_by_user_agent
syn keyword ngxDirectiveThirdParty push_stream_allowed_origins
syn keyword ngxDirectiveThirdParty push_stream_allow_connections_to_events_channel

" rDNS Module <https://github.com/flant/nginx-http-rdns>
" Make a reverse DNS (rDNS) lookup for incoming connection and provides simple access control of incoming hostname by allow/deny rules
syn keyword ngxDirectiveThirdParty rdns
syn keyword ngxDirectiveThirdParty rdns_allow
syn keyword ngxDirectiveThirdParty rdns_deny

" RDS CSV Module <https://github.com/openresty/rds-csv-nginx-module>
" Nginx output filter module to convert Resty-DBD-Streams (RDS) to Comma-Separated Values (CSV)
syn keyword ngxDirectiveThirdParty rds_csv
syn keyword ngxDirectiveThirdParty rds_csv_row_terminator
syn keyword ngxDirectiveThirdParty rds_csv_field_separator
syn keyword ngxDirectiveThirdParty rds_csv_field_name_header
syn keyword ngxDirectiveThirdParty rds_csv_content_type
syn keyword ngxDirectiveThirdParty rds_csv_buffer_size

" RDS JSON Module <https://github.com/openresty/rds-json-nginx-module>
" An output filter that formats Resty DBD Streams generated by ngx_drizzle and others to JSON
syn keyword ngxDirectiveThirdParty rds_json
syn keyword ngxDirectiveThirdParty rds_json_buffer_size
syn keyword ngxDirectiveThirdParty rds_json_format
syn keyword ngxDirectiveThirdParty rds_json_root
syn keyword ngxDirectiveThirdParty rds_json_success_property
syn keyword ngxDirectiveThirdParty rds_json_user_property
syn keyword ngxDirectiveThirdParty rds_json_errcode_key
syn keyword ngxDirectiveThirdParty rds_json_errstr_key
syn keyword ngxDirectiveThirdParty rds_json_ret
syn keyword ngxDirectiveThirdParty rds_json_content_type

" Redis Module <https://www.nginx.com/resources/wiki/modules/redis/>
" Use this module to perform simple caching
syn keyword ngxDirectiveThirdParty redis_pass
syn keyword ngxDirectiveThirdParty redis_bind
syn keyword ngxDirectiveThirdParty redis_connect_timeout
syn keyword ngxDirectiveThirdParty redis_read_timeout
syn keyword ngxDirectiveThirdParty redis_send_timeout
syn keyword ngxDirectiveThirdParty redis_buffer_size
syn keyword ngxDirectiveThirdParty redis_next_upstream
syn keyword ngxDirectiveThirdParty redis_gzip_flag

" Redis 2 Module <https://github.com/openresty/redis2-nginx-module>
" Nginx upstream module for the Redis 2.0 protocol
syn keyword ngxDirectiveThirdParty redis2_query
syn keyword ngxDirectiveThirdParty redis2_raw_query
syn keyword ngxDirectiveThirdParty redis2_raw_queries
syn keyword ngxDirectiveThirdParty redis2_literal_raw_query
syn keyword ngxDirectiveThirdParty redis2_pass
syn keyword ngxDirectiveThirdParty redis2_connect_timeout
syn keyword ngxDirectiveThirdParty redis2_send_timeout
syn keyword ngxDirectiveThirdParty redis2_read_timeout
syn keyword ngxDirectiveThirdParty redis2_buffer_size
syn keyword ngxDirectiveThirdParty redis2_next_upstream

" Replace Filter Module <https://github.com/openresty/replace-filter-nginx-module>
" Streaming regular expression replacement in response bodies
syn keyword ngxDirectiveThirdParty replace_filter
syn keyword ngxDirectiveThirdParty replace_filter_types
syn keyword ngxDirectiveThirdParty replace_filter_max_buffered_size
syn keyword ngxDirectiveThirdParty replace_filter_last_modified
syn keyword ngxDirectiveThirdParty replace_filter_skip

" Roboo Module <https://github.com/yuri-gushin/Roboo>
" HTTP Robot Mitigator

" RRD Graph Module <https://www.nginx.com/resources/wiki/modules/rrd_graph/>
" This module provides an HTTP interface to RRDtool's graphing facilities.
syn keyword ngxDirectiveThirdParty rrd_graph
syn keyword ngxDirectiveThirdParty rrd_graph_root

" RTMP Module <https://github.com/arut/nginx-rtmp-module>
" NGINX-based Media Streaming Server
syn keyword ngxDirectiveThirdParty rtmp
" syn keyword ngxDirectiveThirdParty server
" syn keyword ngxDirectiveThirdParty listen
syn keyword ngxDirectiveThirdParty application
" syn keyword ngxDirectiveThirdParty timeout
syn keyword ngxDirectiveThirdParty ping
syn keyword ngxDirectiveThirdParty ping_timeout
syn keyword ngxDirectiveThirdParty max_streams
syn keyword ngxDirectiveThirdParty ack_window
syn keyword ngxDirectiveThirdParty chunk_size
syn keyword ngxDirectiveThirdParty max_queue
syn keyword ngxDirectiveThirdParty max_message
syn keyword ngxDirectiveThirdParty out_queue
syn keyword ngxDirectiveThirdParty out_cork
" syn keyword ngxDirectiveThirdParty allow
" syn keyword ngxDirectiveThirdParty deny
syn keyword ngxDirectiveThirdParty exec_push
syn keyword ngxDirectiveThirdParty exec_pull
syn keyword ngxDirectiveThirdParty exec
syn keyword ngxDirectiveThirdParty exec_options
syn keyword ngxDirectiveThirdParty exec_static
syn keyword ngxDirectiveThirdParty exec_kill_signal
syn keyword ngxDirectiveThirdParty respawn
syn keyword ngxDirectiveThirdParty respawn_timeout
syn keyword ngxDirectiveThirdParty exec_publish
syn keyword ngxDirectiveThirdParty exec_play
syn keyword ngxDirectiveThirdParty exec_play_done
syn keyword ngxDirectiveThirdParty exec_publish_done
syn keyword ngxDirectiveThirdParty exec_record_done
syn keyword ngxDirectiveThirdParty live
syn keyword ngxDirectiveThirdParty meta
syn keyword ngxDirectiveThirdParty interleave
syn keyword ngxDirectiveThirdParty wait_key
syn keyword ngxDirectiveThirdParty wait_video
syn keyword ngxDirectiveThirdParty publish_notify
syn keyword ngxDirectiveThirdParty drop_idle_publisher
syn keyword ngxDirectiveThirdParty sync
syn keyword ngxDirectiveThirdParty play_restart
syn keyword ngxDirectiveThirdParty idle_streams
syn keyword ngxDirectiveThirdParty record
syn keyword ngxDirectiveThirdParty record_path
syn keyword ngxDirectiveThirdParty record_suffix
syn keyword ngxDirectiveThirdParty record_unique
syn keyword ngxDirectiveThirdParty record_append
syn keyword ngxDirectiveThirdParty record_lock
syn keyword ngxDirectiveThirdParty record_max_size
syn keyword ngxDirectiveThirdParty record_max_frames
syn keyword ngxDirectiveThirdParty record_interval
syn keyword ngxDirectiveThirdParty recorder
syn keyword ngxDirectiveThirdParty record_notify
syn keyword ngxDirectiveThirdParty play
syn keyword ngxDirectiveThirdParty play_temp_path
syn keyword ngxDirectiveThirdParty play_local_path
syn keyword ngxDirectiveThirdParty pull
syn keyword ngxDirectiveThirdParty push
syn keyword ngxDirectiveThirdParty push_reconnect
syn keyword ngxDirectiveThirdParty session_relay
syn keyword ngxDirectiveThirdParty on_connect
syn keyword ngxDirectiveThirdParty on_play
syn keyword ngxDirectiveThirdParty on_publish
syn keyword ngxDirectiveThirdParty on_done
syn keyword ngxDirectiveThirdParty on_play_done
syn keyword ngxDirectiveThirdParty on_publish_done
syn keyword ngxDirectiveThirdParty on_record_done
syn keyword ngxDirectiveThirdParty on_update
syn keyword ngxDirectiveThirdParty notify_update_timeout
syn keyword ngxDirectiveThirdParty notify_update_strict
syn keyword ngxDirectiveThirdParty notify_relay_redirect
syn keyword ngxDirectiveThirdParty notify_method
syn keyword ngxDirectiveThirdParty hls
syn keyword ngxDirectiveThirdParty hls_path
syn keyword ngxDirectiveThirdParty hls_fragment
syn keyword ngxDirectiveThirdParty hls_playlist_length
syn keyword ngxDirectiveThirdParty hls_sync
syn keyword ngxDirectiveThirdParty hls_continuous
syn keyword ngxDirectiveThirdParty hls_nested
syn keyword ngxDirectiveThirdParty hls_base_url
syn keyword ngxDirectiveThirdParty hls_cleanup
syn keyword ngxDirectiveThirdParty hls_fragment_naming
syn keyword ngxDirectiveThirdParty hls_fragment_slicing
syn keyword ngxDirectiveThirdParty hls_variant
syn keyword ngxDirectiveThirdParty hls_type
syn keyword ngxDirectiveThirdParty hls_keys
syn keyword ngxDirectiveThirdParty hls_key_path
syn keyword ngxDirectiveThirdParty hls_key_url
syn keyword ngxDirectiveThirdParty hls_fragments_per_key
syn keyword ngxDirectiveThirdParty dash
syn keyword ngxDirectiveThirdParty dash_path
syn keyword ngxDirectiveThirdParty dash_fragment
syn keyword ngxDirectiveThirdParty dash_playlist_length
syn keyword ngxDirectiveThirdParty dash_nested
syn keyword ngxDirectiveThirdParty dash_cleanup
" syn keyword ngxDirectiveThirdParty access_log
" syn keyword ngxDirectiveThirdParty log_format
syn keyword ngxDirectiveThirdParty max_connections
syn keyword ngxDirectiveThirdParty rtmp_stat
syn keyword ngxDirectiveThirdParty rtmp_stat_stylesheet
syn keyword ngxDirectiveThirdParty rtmp_auto_push
syn keyword ngxDirectiveThirdParty rtmp_auto_push_reconnect
syn keyword ngxDirectiveThirdParty rtmp_socket_dir
syn keyword ngxDirectiveThirdParty rtmp_control

" RTMPT Module <https://github.com/kwojtek/nginx-rtmpt-proxy-module>
" Module for nginx to proxy rtmp using http protocol
syn keyword ngxDirectiveThirdParty rtmpt_proxy_target
syn keyword ngxDirectiveThirdParty rtmpt_proxy_rtmp_timeout
syn keyword ngxDirectiveThirdParty rtmpt_proxy_http_timeout
syn keyword ngxDirectiveThirdParty rtmpt_proxy
syn keyword ngxDirectiveThirdParty rtmpt_proxy_stat
syn keyword ngxDirectiveThirdParty rtmpt_proxy_stylesheet

" Syntactically Awesome Module <https://github.com/mneudert/sass-nginx-module>
" Providing on-the-fly compiling of Sass files as an NGINX module.
syn keyword ngxDirectiveThirdParty sass_compile
syn keyword ngxDirectiveThirdParty sass_error_log
syn keyword ngxDirectiveThirdParty sass_include_path
syn keyword ngxDirectiveThirdParty sass_indent
syn keyword ngxDirectiveThirdParty sass_is_indented_syntax
syn keyword ngxDirectiveThirdParty sass_linefeed
syn keyword ngxDirectiveThirdParty sass_precision
syn keyword ngxDirectiveThirdParty sass_output_style
syn keyword ngxDirectiveThirdParty sass_source_comments
syn keyword ngxDirectiveThirdParty sass_source_map_embed

" Secure Download Module <https://www.nginx.com/resources/wiki/modules/secure_download/>
" Enables you to create links which are only valid until a certain datetime is reached
syn keyword ngxDirectiveThirdParty secure_download
syn keyword ngxDirectiveThirdParty secure_download_secret
syn keyword ngxDirectiveThirdParty secure_download_path_mode

" Selective Cache Purge Module <https://github.com/wandenberg/nginx-selective-cache-purge-module>
" A module to purge cache by GLOB patterns. The supported patterns are the same as supported by Redis.
syn keyword ngxDirectiveThirdParty selective_cache_purge_redis_unix_socket
syn keyword ngxDirectiveThirdParty selective_cache_purge_redis_host
syn keyword ngxDirectiveThirdParty selective_cache_purge_redis_port
syn keyword ngxDirectiveThirdParty selective_cache_purge_redis_database
syn keyword ngxDirectiveThirdParty selective_cache_purge_query

" Set cconv Module <https://github.com/liseen/set-cconv-nginx-module>
" Cconv rewrite set commands
syn keyword ngxDirectiveThirdParty set_cconv_to_simp
syn keyword ngxDirectiveThirdParty set_cconv_to_trad
syn keyword ngxDirectiveThirdParty set_pinyin_to_normal

" Set Hash Module <https://github.com/simpl/ngx_http_set_hash>
" Nginx module that allows the setting of variables to the value of a variety of hashes
syn keyword ngxDirectiveThirdParty set_md5
syn keyword ngxDirectiveThirdParty set_md5_upper
syn keyword ngxDirectiveThirdParty set_murmur2
syn keyword ngxDirectiveThirdParty set_murmur2_upper
syn keyword ngxDirectiveThirdParty set_sha1
syn keyword ngxDirectiveThirdParty set_sha1_upper

" Set Lang Module <https://github.com/simpl/ngx_http_set_lang>
" Provides a variety of ways for setting a variable denoting the langauge that content should be returned in.
syn keyword ngxDirectiveThirdParty set_lang
syn keyword ngxDirectiveThirdParty set_lang_method
syn keyword ngxDirectiveThirdParty lang_cookie
syn keyword ngxDirectiveThirdParty lang_get_var
syn keyword ngxDirectiveThirdParty lang_list
syn keyword ngxDirectiveThirdParty lang_post_var
syn keyword ngxDirectiveThirdParty lang_host
syn keyword ngxDirectiveThirdParty lang_referer

" Set Misc Module <https://github.com/openresty/set-misc-nginx-module>
" Various set_xxx directives added to nginx's rewrite module
syn keyword ngxDirectiveThirdParty set_if_empty
syn keyword ngxDirectiveThirdParty set_quote_sql_str
syn keyword ngxDirectiveThirdParty set_quote_pgsql_str
syn keyword ngxDirectiveThirdParty set_quote_json_str
syn keyword ngxDirectiveThirdParty set_unescape_uri
syn keyword ngxDirectiveThirdParty set_escape_uri
syn keyword ngxDirectiveThirdParty set_hashed_upstream
syn keyword ngxDirectiveThirdParty set_encode_base32
syn keyword ngxDirectiveThirdParty set_base32_padding
syn keyword ngxDirectiveThirdParty set_misc_base32_padding
syn keyword ngxDirectiveThirdParty set_base32_alphabet
syn keyword ngxDirectiveThirdParty set_decode_base32
syn keyword ngxDirectiveThirdParty set_encode_base64
syn keyword ngxDirectiveThirdParty set_decode_base64
syn keyword ngxDirectiveThirdParty set_encode_hex
syn keyword ngxDirectiveThirdParty set_decode_hex
syn keyword ngxDirectiveThirdParty set_sha1
syn keyword ngxDirectiveThirdParty set_md5
syn keyword ngxDirectiveThirdParty set_hmac_sha1
syn keyword ngxDirectiveThirdParty set_random
syn keyword ngxDirectiveThirdParty set_secure_random_alphanum
syn keyword ngxDirectiveThirdParty set_secure_random_lcalpha
syn keyword ngxDirectiveThirdParty set_rotate
syn keyword ngxDirectiveThirdParty set_local_today
syn keyword ngxDirectiveThirdParty set_formatted_gmt_time
syn keyword ngxDirectiveThirdParty set_formatted_local_time

" SFlow Module <https://github.com/sflow/nginx-sflow-module>
" A binary, random-sampling nginx module designed for: lightweight, centralized, continuous, real-time monitoring of very large and very busy web farms.
syn keyword ngxDirectiveThirdParty sflow

" Shibboleth Module <https://github.com/nginx-shib/nginx-http-shibboleth>
" Shibboleth auth request module for nginx
syn keyword ngxDirectiveThirdParty shib_request
syn keyword ngxDirectiveThirdParty shib_request_set
syn keyword ngxDirectiveThirdParty shib_request_use_headers

" Slice Module <https://github.com/alibaba/nginx-http-slice>
" Nginx module for serving a file in slices (reverse byte-range)
" syn keyword ngxDirectiveThirdParty slice
syn keyword ngxDirectiveThirdParty slice_arg_begin
syn keyword ngxDirectiveThirdParty slice_arg_end
syn keyword ngxDirectiveThirdParty slice_header
syn keyword ngxDirectiveThirdParty slice_footer
syn keyword ngxDirectiveThirdParty slice_header_first
syn keyword ngxDirectiveThirdParty slice_footer_last

" SlowFS Cache Module <https://github.com/FRiCKLE/ngx_slowfs_cache/>
" Module adding ability to cache static files.
syn keyword ngxDirectiveThirdParty slowfs_big_file_size
syn keyword ngxDirectiveThirdParty slowfs_cache
syn keyword ngxDirectiveThirdParty slowfs_cache_key
syn keyword ngxDirectiveThirdParty slowfs_cache_min_uses
syn keyword ngxDirectiveThirdParty slowfs_cache_path
syn keyword ngxDirectiveThirdParty slowfs_cache_purge
syn keyword ngxDirectiveThirdParty slowfs_cache_valid
syn keyword ngxDirectiveThirdParty slowfs_temp_path

" Small Light Module <https://github.com/cubicdaiya/ngx_small_light>
" Dynamic Image Transformation Module For nginx.
syn keyword ngxDirectiveThirdParty small_light
syn keyword ngxDirectiveThirdParty small_light_getparam_mode
syn keyword ngxDirectiveThirdParty small_light_material_dir
syn keyword ngxDirectiveThirdParty small_light_pattern_define
syn keyword ngxDirectiveThirdParty small_light_radius_max
syn keyword ngxDirectiveThirdParty small_light_sigma_max
syn keyword ngxDirectiveThirdParty small_light_imlib2_temp_dir
syn keyword ngxDirectiveThirdParty small_light_buffer

" Sorted Querystring Filter Module <https://github.com/wandenberg/nginx-sorted-querystring-module>
" Nginx module to expose querystring parameters sorted in a variable to be used on cache_key as example
syn keyword ngxDirectiveThirdParty sorted_querystring_filter_parameter

" Sphinx2 Module <https://github.com/reeteshranjan/sphinx2-nginx-module>
" Nginx upstream module for Sphinx 2.x
syn keyword ngxDirectiveThirdParty sphinx2_pass
syn keyword ngxDirectiveThirdParty sphinx2_bind
syn keyword ngxDirectiveThirdParty sphinx2_connect_timeout
syn keyword ngxDirectiveThirdParty sphinx2_send_timeout
syn keyword ngxDirectiveThirdParty sphinx2_buffer_size
syn keyword ngxDirectiveThirdParty sphinx2_read_timeout
syn keyword ngxDirectiveThirdParty sphinx2_next_upstream

" HTTP SPNEGO auth Module <https://github.com/stnoonan/spnego-http-auth-nginx-module>
" This module implements adds SPNEGO support to nginx(http://nginx.org). It currently supports only Kerberos authentication via GSSAPI
syn keyword ngxDirectiveThirdParty auth_gss
syn keyword ngxDirectiveThirdParty auth_gss_keytab
syn keyword ngxDirectiveThirdParty auth_gss_realm
syn keyword ngxDirectiveThirdParty auth_gss_service_name
syn keyword ngxDirectiveThirdParty auth_gss_authorized_principal
syn keyword ngxDirectiveThirdParty auth_gss_allow_basic_fallback

" SR Cache Module <https://github.com/openresty/srcache-nginx-module>
" Transparent subrequest-based caching layout for arbitrary nginx locations
syn keyword ngxDirectiveThirdParty srcache_fetch
syn keyword ngxDirectiveThirdParty srcache_fetch_skip
syn keyword ngxDirectiveThirdParty srcache_store
syn keyword ngxDirectiveThirdParty srcache_store_max_size
syn keyword ngxDirectiveThirdParty srcache_store_skip
syn keyword ngxDirectiveThirdParty srcache_store_statuses
syn keyword ngxDirectiveThirdParty srcache_store_ranges
syn keyword ngxDirectiveThirdParty srcache_header_buffer_size
syn keyword ngxDirectiveThirdParty srcache_store_hide_header
syn keyword ngxDirectiveThirdParty srcache_store_pass_header
syn keyword ngxDirectiveThirdParty srcache_methods
syn keyword ngxDirectiveThirdParty srcache_ignore_content_encoding
syn keyword ngxDirectiveThirdParty srcache_request_cache_control
syn keyword ngxDirectiveThirdParty srcache_response_cache_control
syn keyword ngxDirectiveThirdParty srcache_store_no_store
syn keyword ngxDirectiveThirdParty srcache_store_no_cache
syn keyword ngxDirectiveThirdParty srcache_store_private
syn keyword ngxDirectiveThirdParty srcache_default_expire
syn keyword ngxDirectiveThirdParty srcache_max_expire

" SSSD Info Module <https://github.com/veruu/ngx_sssd_info>
" Retrives additional attributes from SSSD for current authentizated user
syn keyword ngxDirectiveThirdParty sssd_info
syn keyword ngxDirectiveThirdParty sssd_info_output_to
syn keyword ngxDirectiveThirdParty sssd_info_groups
syn keyword ngxDirectiveThirdParty sssd_info_group
syn keyword ngxDirectiveThirdParty sssd_info_group_separator
syn keyword ngxDirectiveThirdParty sssd_info_attributes
syn keyword ngxDirectiveThirdParty sssd_info_attribute
syn keyword ngxDirectiveThirdParty sssd_info_attribute_separator

" Static Etags Module <https://github.com/mikewest/nginx-static-etags>
" Generate etags for static content
syn keyword ngxDirectiveThirdParty FileETag

" Statsd Module <https://github.com/zebrafishlabs/nginx-statsd>
" An nginx module for sending statistics to statsd
syn keyword ngxDirectiveThirdParty statsd_server
syn keyword ngxDirectiveThirdParty statsd_sample_rate
syn keyword ngxDirectiveThirdParty statsd_count
syn keyword ngxDirectiveThirdParty statsd_timing

" Sticky Module <https://bitbucket.org/nginx-goodies/nginx-sticky-module-ng>
" Add a sticky cookie to be always forwarded to the same upstream server
" syn keyword ngxDirectiveThirdParty sticky

" Stream Echo Module <https://github.com/openresty/stream-echo-nginx-module>
" TCP/stream echo module for NGINX (a port of ngx_http_echo_module)
syn keyword ngxDirectiveThirdParty echo
syn keyword ngxDirectiveThirdParty echo_duplicate
syn keyword ngxDirectiveThirdParty echo_flush_wait
syn keyword ngxDirectiveThirdParty echo_sleep
syn keyword ngxDirectiveThirdParty echo_send_timeout
syn keyword ngxDirectiveThirdParty echo_read_bytes
syn keyword ngxDirectiveThirdParty echo_read_line
syn keyword ngxDirectiveThirdParty echo_request_data
syn keyword ngxDirectiveThirdParty echo_discard_request
syn keyword ngxDirectiveThirdParty echo_read_buffer_size
syn keyword ngxDirectiveThirdParty echo_read_timeout
syn keyword ngxDirectiveThirdParty echo_client_error_log_level
syn keyword ngxDirectiveThirdParty echo_lingering_close
syn keyword ngxDirectiveThirdParty echo_lingering_time
syn keyword ngxDirectiveThirdParty echo_lingering_timeout

" Stream Lua Module <https://github.com/openresty/stream-lua-nginx-module>
" Embed the power of Lua into Nginx stream/TCP Servers.
syn keyword ngxDirectiveThirdParty lua_resolver
syn keyword ngxDirectiveThirdParty lua_resolver_timeout
syn keyword ngxDirectiveThirdParty lua_lingering_close
syn keyword ngxDirectiveThirdParty lua_lingering_time
syn keyword ngxDirectiveThirdParty lua_lingering_timeout

" Stream Upsync Module <https://github.com/xiaokai-wang/nginx-stream-upsync-module>
" Sync upstreams from consul or others, dynamiclly modify backend-servers attribute(weight, max_fails,...), needn't reload nginx.
syn keyword ngxDirectiveThirdParty upsync
syn keyword ngxDirectiveThirdParty upsync_dump_path
syn keyword ngxDirectiveThirdParty upsync_lb
syn keyword ngxDirectiveThirdParty upsync_show

" Strip Module <https://github.com/evanmiller/mod_strip>
" Whitespace remover.
syn keyword ngxDirectiveThirdParty strip

" Subrange Module <https://github.com/Qihoo360/ngx_http_subrange_module>
" Split one big HTTP/Range request to multiple subrange requesets
syn keyword ngxDirectiveThirdParty subrange

" Substitutions Module <https://www.nginx.com/resources/wiki/modules/substitutions/>
" A filter module which can do both regular expression and fixed string substitutions on response bodies.
syn keyword ngxDirectiveThirdParty subs_filter
syn keyword ngxDirectiveThirdParty subs_filter_types

" Summarizer Module <https://github.com/reeteshranjan/summarizer-nginx-module>
" Upstream nginx module to get summaries of documents using the summarizer daemon service
syn keyword ngxDirectiveThirdParty smrzr_filename
syn keyword ngxDirectiveThirdParty smrzr_ratio

" Supervisord Module <https://github.com/FRiCKLE/ngx_supervisord/>
" Module providing nginx with API to communicate with supervisord and manage (start/stop) backends on-demand.
syn keyword ngxDirectiveThirdParty supervisord
syn keyword ngxDirectiveThirdParty supervisord_inherit_backend_status
syn keyword ngxDirectiveThirdParty supervisord_name
syn keyword ngxDirectiveThirdParty supervisord_start
syn keyword ngxDirectiveThirdParty supervisord_stop

" Tarantool Upstream Module <https://github.com/tarantool/nginx_upstream_module>
" Tarantool NginX upstream module (REST, JSON API, websockets, load balancing)
syn keyword ngxDirectiveThirdParty tnt_pass
syn keyword ngxDirectiveThirdParty tnt_http_methods
syn keyword ngxDirectiveThirdParty tnt_http_rest_methods
syn keyword ngxDirectiveThirdParty tnt_pass_http_request
syn keyword ngxDirectiveThirdParty tnt_pass_http_request_buffer_size
syn keyword ngxDirectiveThirdParty tnt_method
syn keyword ngxDirectiveThirdParty tnt_http_allowed_methods - experemental
syn keyword ngxDirectiveThirdParty tnt_send_timeout
syn keyword ngxDirectiveThirdParty tnt_read_timeout
syn keyword ngxDirectiveThirdParty tnt_buffer_size
syn keyword ngxDirectiveThirdParty tnt_next_upstream
syn keyword ngxDirectiveThirdParty tnt_connect_timeout
syn keyword ngxDirectiveThirdParty tnt_next_upstream
syn keyword ngxDirectiveThirdParty tnt_next_upstream_tries
syn keyword ngxDirectiveThirdParty tnt_next_upstream_timeout

" TCP Proxy Module <http://yaoweibin.github.io/nginx_tcp_proxy_module/>
" Add the feature of tcp proxy with nginx, with health check and status monitor
syn keyword ngxDirectiveBlock tcp
" syn keyword ngxDirectiveThirdParty server
" syn keyword ngxDirectiveThirdParty listen
" syn keyword ngxDirectiveThirdParty allow
" syn keyword ngxDirectiveThirdParty deny
" syn keyword ngxDirectiveThirdParty so_keepalive
" syn keyword ngxDirectiveThirdParty tcp_nodelay
" syn keyword ngxDirectiveThirdParty timeout
" syn keyword ngxDirectiveThirdParty server_name
" syn keyword ngxDirectiveThirdParty resolver
" syn keyword ngxDirectiveThirdParty resolver_timeout
" syn keyword ngxDirectiveThirdParty upstream
syn keyword ngxDirectiveThirdParty check
syn keyword ngxDirectiveThirdParty check_http_send
syn keyword ngxDirectiveThirdParty check_http_expect_alive
syn keyword ngxDirectiveThirdParty check_smtp_send
syn keyword ngxDirectiveThirdParty check_smtp_expect_alive
syn keyword ngxDirectiveThirdParty check_shm_size
syn keyword ngxDirectiveThirdParty check_status
" syn keyword ngxDirectiveThirdParty ip_hash
" syn keyword ngxDirectiveThirdParty proxy_pass
" syn keyword ngxDirectiveThirdParty proxy_buffer
" syn keyword ngxDirectiveThirdParty proxy_connect_timeout
" syn keyword ngxDirectiveThirdParty proxy_read_timeout
syn keyword ngxDirectiveThirdParty proxy_write_timeout

" Testcookie Module <https://github.com/kyprizel/testcookie-nginx-module>
" NGINX module for L7 DDoS attack mitigation
syn keyword ngxDirectiveThirdParty testcookie
syn keyword ngxDirectiveThirdParty testcookie_name
syn keyword ngxDirectiveThirdParty testcookie_domain
syn keyword ngxDirectiveThirdParty testcookie_expires
syn keyword ngxDirectiveThirdParty testcookie_path
syn keyword ngxDirectiveThirdParty testcookie_secret
syn keyword ngxDirectiveThirdParty testcookie_session
syn keyword ngxDirectiveThirdParty testcookie_arg
syn keyword ngxDirectiveThirdParty testcookie_max_attempts
syn keyword ngxDirectiveThirdParty testcookie_p3p
syn keyword ngxDirectiveThirdParty testcookie_fallback
syn keyword ngxDirectiveThirdParty testcookie_whitelist
syn keyword ngxDirectiveThirdParty testcookie_pass
syn keyword ngxDirectiveThirdParty testcookie_redirect_via_refresh
syn keyword ngxDirectiveThirdParty testcookie_refresh_template
syn keyword ngxDirectiveThirdParty testcookie_refresh_status
syn keyword ngxDirectiveThirdParty testcookie_deny_keepalive
syn keyword ngxDirectiveThirdParty testcookie_get_only
syn keyword ngxDirectiveThirdParty testcookie_https_location
syn keyword ngxDirectiveThirdParty testcookie_refresh_encrypt_cookie
syn keyword ngxDirectiveThirdParty testcookie_refresh_encrypt_cookie_key
syn keyword ngxDirectiveThirdParty testcookie_refresh_encrypt_iv
syn keyword ngxDirectiveThirdParty testcookie_internal
syn keyword ngxDirectiveThirdParty testcookie_httponly_flag
syn keyword ngxDirectiveThirdParty testcookie_secure_flag

" Types Filter Module <https://github.com/flygoast/ngx_http_types_filter>
" Change the `Content-Type` output header depending on an extension variable according to a condition specified in the 'if' clause.
syn keyword ngxDirectiveThirdParty types_filter
syn keyword ngxDirectiveThirdParty types_filter_use_default

" Unzip Module <https://github.com/youzee/nginx-unzip-module>
" Enabling fetching of files that are stored in zipped archives.
syn keyword ngxDirectiveThirdParty file_in_unzip_archivefile
syn keyword ngxDirectiveThirdParty file_in_unzip_extract
syn keyword ngxDirectiveThirdParty file_in_unzip

" Upload Progress Module <https://www.nginx.com/resources/wiki/modules/upload_progress/>
" An upload progress system, that monitors RFC1867 POST upload as they are transmitted to upstream servers
syn keyword ngxDirectiveThirdParty upload_progress
syn keyword ngxDirectiveThirdParty track_uploads
syn keyword ngxDirectiveThirdParty report_uploads
syn keyword ngxDirectiveThirdParty upload_progress_content_type
syn keyword ngxDirectiveThirdParty upload_progress_header
syn keyword ngxDirectiveThirdParty upload_progress_jsonp_parameter
syn keyword ngxDirectiveThirdParty upload_progress_json_output
syn keyword ngxDirectiveThirdParty upload_progress_jsonp_output
syn keyword ngxDirectiveThirdParty upload_progress_template

" Upload Module <https://www.nginx.com/resources/wiki/modules/upload/>
" Parses request body storing all files being uploaded to a directory specified by upload_store directive
syn keyword ngxDirectiveThirdParty upload_pass
syn keyword ngxDirectiveThirdParty upload_resumable
syn keyword ngxDirectiveThirdParty upload_store
syn keyword ngxDirectiveThirdParty upload_state_store
syn keyword ngxDirectiveThirdParty upload_store_access
syn keyword ngxDirectiveThirdParty upload_set_form_field
syn keyword ngxDirectiveThirdParty upload_aggregate_form_field
syn keyword ngxDirectiveThirdParty upload_pass_form_field
syn keyword ngxDirectiveThirdParty upload_cleanup
syn keyword ngxDirectiveThirdParty upload_buffer_size
syn keyword ngxDirectiveThirdParty upload_max_part_header_len
syn keyword ngxDirectiveThirdParty upload_max_file_size
syn keyword ngxDirectiveThirdParty upload_limit_rate
syn keyword ngxDirectiveThirdParty upload_max_output_body_len
syn keyword ngxDirectiveThirdParty upload_tame_arrays
syn keyword ngxDirectiveThirdParty upload_pass_args

" Upstream Fair Module <https://github.com/gnosek/nginx-upstream-fair>
" The fair load balancer module for nginx http://nginx.localdomain.pl
syn keyword ngxDirectiveThirdParty fair
syn keyword ngxDirectiveThirdParty upstream_fair_shm_size

" Upstream Hash Module (DEPRECATED) <http://wiki.nginx.org/NginxHttpUpstreamRequestHashModule>
" Provides simple upstream load distribution by hashing a configurable variable.
" syn keyword ngxDirectiveDeprecated hash
syn keyword ngxDirectiveDeprecated hash_again

" Upstream Domain Resolve Module <https://www.nginx.com/resources/wiki/modules/domain_resolve/>
" A load-balancer that resolves an upstream domain name asynchronously.
syn keyword ngxDirectiveThirdParty jdomain

" Upsync Module <https://github.com/weibocom/nginx-upsync-module>
" Sync upstreams from consul or others, dynamiclly modify backend-servers attribute(weight, max_fails,...), needn't reload nginx
syn keyword ngxDirectiveThirdParty upsync
syn keyword ngxDirectiveThirdParty upsync_dump_path
syn keyword ngxDirectiveThirdParty upsync_lb
syn keyword ngxDirectiveThirdParty upstream_show

" URL Module <https://github.com/vozlt/nginx-module-url>
" Nginx url encoding converting module
syn keyword ngxDirectiveThirdParty url_encoding_convert
syn keyword ngxDirectiveThirdParty url_encoding_convert_from
syn keyword ngxDirectiveThirdParty url_encoding_convert_to

" User Agent Module <https://github.com/alibaba/nginx-http-user-agent>
" Match browsers and crawlers
syn keyword ngxDirectiveThirdParty user_agent

" Upstrema Ketama Chash Module <https://github.com/flygoast/ngx_http_upstream_ketama_chash>
" Nginx load-balancer module implementing ketama consistent hashing.
syn keyword ngxDirectiveThirdParty ketama_chash

" Video Thumbextractor Module <https://github.com/wandenberg/nginx-video-thumbextractor-module>
" Extract thumbs from a video file
syn keyword ngxDirectiveThirdParty video_thumbextractor
syn keyword ngxDirectiveThirdParty video_thumbextractor_video_filename
syn keyword ngxDirectiveThirdParty video_thumbextractor_video_second
syn keyword ngxDirectiveThirdParty video_thumbextractor_image_width
syn keyword ngxDirectiveThirdParty video_thumbextractor_image_height
syn keyword ngxDirectiveThirdParty video_thumbextractor_only_keyframe
syn keyword ngxDirectiveThirdParty video_thumbextractor_next_time
syn keyword ngxDirectiveThirdParty video_thumbextractor_tile_rows
syn keyword ngxDirectiveThirdParty video_thumbextractor_tile_cols
syn keyword ngxDirectiveThirdParty video_thumbextractor_tile_max_rows
syn keyword ngxDirectiveThirdParty video_thumbextractor_tile_max_cols
syn keyword ngxDirectiveThirdParty video_thumbextractor_tile_sample_interval
syn keyword ngxDirectiveThirdParty video_thumbextractor_tile_color
syn keyword ngxDirectiveThirdParty video_thumbextractor_tile_margin
syn keyword ngxDirectiveThirdParty video_thumbextractor_tile_padding
syn keyword ngxDirectiveThirdParty video_thumbextractor_threads
syn keyword ngxDirectiveThirdParty video_thumbextractor_processes_per_worker

" Eval Module <http://www.grid.net.ru/nginx/eval.en.html>
" Module for nginx web server evaluates response of proxy or memcached module into variables.
syn keyword ngxDirectiveThirdParty eval
syn keyword ngxDirectiveThirdParty eval_escalate
syn keyword ngxDirectiveThirdParty eval_override_content_type

" VTS Module <https://github.com/vozlt/nginx-module-vts>
" Nginx virtual host traffic status module
syn keyword ngxDirectiveThirdParty vhost_traffic_status
syn keyword ngxDirectiveThirdParty vhost_traffic_status_zone
syn keyword ngxDirectiveThirdParty vhost_traffic_status_display
syn keyword ngxDirectiveThirdParty vhost_traffic_status_display_format
syn keyword ngxDirectiveThirdParty vhost_traffic_status_display_jsonp
syn keyword ngxDirectiveThirdParty vhost_traffic_status_filter
syn keyword ngxDirectiveThirdParty vhost_traffic_status_filter_by_host
syn keyword ngxDirectiveThirdParty vhost_traffic_status_filter_by_set_key
syn keyword ngxDirectiveThirdParty vhost_traffic_status_filter_check_duplicate
syn keyword ngxDirectiveThirdParty vhost_traffic_status_limit
syn keyword ngxDirectiveThirdParty vhost_traffic_status_limit_traffic
syn keyword ngxDirectiveThirdParty vhost_traffic_status_limit_traffic_by_set_key
syn keyword ngxDirectiveThirdParty vhost_traffic_status_limit_check_duplicate

" XSS Module <https://github.com/openresty/xss-nginx-module>
" Native support for cross-site scripting (XSS) in an nginx.
syn keyword ngxDirectiveThirdParty xss_get
syn keyword ngxDirectiveThirdParty xss_callback_arg
syn keyword ngxDirectiveThirdParty xss_override_status
syn keyword ngxDirectiveThirdParty xss_check_status
syn keyword ngxDirectiveThirdParty xss_input_types

" CT Module <https://github.com/grahamedgecombe/nginx-ct>
" Certificate Transparency module for nginx
syn keyword ngxDirectiveThirdParty ssl_ct
syn keyword ngxDirectiveThirdParty ssl_ct_static_scts

" Dynamic TLS records patch <https://github.com/cloudflare/sslconfig/blob/master/patches/nginx__dynamic_tls_records.patch>
" TLS Dynamic Record Resizing
syn keyword ngxDirectiveThirdParty ssl_dyn_rec_enable
syn keyword ngxDirectiveThirdParty ssl_dyn_rec_size_hi
syn keyword ngxDirectiveThirdParty ssl_dyn_rec_size_lo
syn keyword ngxDirectiveThirdParty ssl_dyn_rec_threshold
syn keyword ngxDirectiveThirdParty ssl_dyn_rec_timeout

" ZIP Module <https://www.nginx.com/resources/wiki/modules/zip/>
" ZIP archiver for nginx

" Contained LUA blocks for embedded syntax highlighting
syn keyword ngxThirdPartyLuaBlock balancer_by_lua_block contained
syn keyword ngxThirdPartyLuaBlock init_by_lua_block contained
syn keyword ngxThirdPartyLuaBlock init_worker_by_lua_block contained
syn keyword ngxThirdPartyLuaBlock set_by_lua_block contained
syn keyword ngxThirdPartyLuaBlock content_by_lua_block contained
syn keyword ngxThirdPartyLuaBlock rewrite_by_lua_block contained
syn keyword ngxThirdPartyLuaBlock access_by_lua_block contained
syn keyword ngxThirdPartyLuaBlock header_filter_by_lua_block contained
syn keyword ngxThirdPartyLuaBlock body_filter_by_lua_block contained
syn keyword ngxThirdPartyLuaBlock log_by_lua_block contained
syn keyword ngxThirdPartyLuaBlock ssl_certificate_by_lua_block contained
syn keyword ngxThirdPartyLuaBlock ssl_session_fetch_by_lua_block contained
syn keyword ngxThirdPartyLuaBlock ssl_session_store_by_lua_block contained


" Nested syntax in ERB templating statements
" Subtype needs to be set to '', otherwise recursive errors occur when opening *.nginx files
let b:eruby_subtype = ''
unlet b:current_syntax
syn include @ERB syntax/eruby.vim
syn region ngxTemplate start=+<%[^\=]+ end=+%>+ oneline contains=@ERB
syn region ngxTemplateVar start=+<%=+ end=+%>+ oneline
let b:current_syntax = "nginx"

" Nested syntax in Jinja templating statements
" This dependend on https://github.com/lepture/vim-jinja
unlet b:current_syntax
try
  syn include @JINJA syntax/jinja.vim
  syn region ngxTemplate start=+{%+ end=+%}+ oneline contains=@JINJA
  syn region ngxTemplateVar start=+{{+ end=+}}+ oneline
catch
endtry
let b:current_syntax = "nginx"

" Enable nested LUA syntax highlighting
unlet b:current_syntax
syn include @LUA syntax/lua.vim
syn region ngxLua start=+^\s*\w\+_by_lua_block\s*{+ end=+}+me=s-1 contains=ngxBlock,@LUA
let b:current_syntax = "nginx"


" Highlight
hi link ngxComment Comment
hi link ngxVariable Identifier
hi link ngxVariableBlock Identifier
hi link ngxVariableString PreProc
hi link ngxString String
hi link ngxIPaddr Delimiter
hi link ngxBoolean Boolean
hi link ngxInteger Number
hi link ngxDirectiveBlock Statement
hi link ngxDirectiveImportant Type
hi link ngxDirectiveControl Keyword
hi link ngxDirectiveDeprecated Error
hi link ngxDirective Function
hi link ngxDirectiveThirdParty Function
hi link ngxListenOptions PreProc
hi link ngxUpstreamServerOptions PreProc
hi link ngxProxyNextUpstreamOptions PreProc
hi link ngxMailProtocol Keyword
hi link ngxSSLProtocol PreProc
hi link ngxSSLProtocolDeprecated Error
hi link ngxStickyOptions ngxDirective
hi link ngxCookieOptions PreProc
hi link ngxTemplateVar Identifier

hi link ngxSSLSessionTicketsOff ngxBoolean
hi link ngxSSLSessionTicketsOn Error
hi link ngxSSLPreferServerCiphersOn ngxBoolean
hi link ngxSSLPreferServerCiphersOff Error
hi link ngxGzipOff ngxBoolean
hi link ngxGzipOn Error
hi link ngxSSLCipherInsecure Error

hi link ngxThirdPartyLuaBlock Function
