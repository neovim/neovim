" Vim syntax file
" Language:	Squid config file
" Maintainer:	Klaus Muth <klaus@hampft.de>
" Last Change:	2005 Jun 12
" URL:		http://www.hampft.de/vim/syntax/squid.vim
" ThanksTo:	Ilya Sher <iso8601@mail.ru>,
"               Michael Dotzler <Michael.Dotzler@leoni.com>


" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" squid.conf syntax seems to be case insensitive
syn case ignore

syn keyword	squidTodo	contained TODO
syn match	squidComment	"#.*$" contains=squidTodo,squidTag
syn match	squidTag	contained "TAG: .*$"

" Lots & lots of Keywords!
syn keyword	squidConf	acl always_direct announce_host announce_period
syn keyword	squidConf	announce_port announce_to anonymize_headers
syn keyword	squidConf	append_domain as_whois_server auth_param_basic
syn keyword	squidConf	authenticate_children authenticate_program
syn keyword	squidConf	authenticate_ttl broken_posts buffered_logs
syn keyword	squidConf	cache_access_log cache_announce cache_dir
syn keyword	squidConf	cache_dns_program cache_effective_group
syn keyword	squidConf	cache_effective_user cache_host cache_host_acl
syn keyword	squidConf	cache_host_domain cache_log cache_mem
syn keyword	squidConf	cache_mem_high cache_mem_low cache_mgr
syn keyword	squidConf	cachemgr_passwd cache_peer cache_peer_access
syn keyword	squidConf	cache_replacement_policy cache_stoplist
syn keyword	squidConf	cache_stoplist_pattern cache_store_log cache_swap
syn keyword	squidConf	cache_swap_high cache_swap_log cache_swap_low
syn keyword	squidConf	client_db client_lifetime client_netmask
syn keyword	squidConf	connect_timeout coredump_dir dead_peer_timeout
syn keyword	squidConf	debug_options delay_access delay_class
syn keyword	squidConf	delay_initial_bucket_level delay_parameters
syn keyword	squidConf	delay_pools deny_info dns_children dns_defnames
syn keyword	squidConf	dns_nameservers dns_testnames emulate_httpd_log
syn keyword	squidConf	err_html_text fake_user_agent firewall_ip
syn keyword	squidConf	forwarded_for forward_snmpd_port fqdncache_size
syn keyword	squidConf	ftpget_options ftpget_program ftp_list_width
syn keyword	squidConf	ftp_passive ftp_user half_closed_clients
syn keyword	squidConf	header_access header_replace hierarchy_stoplist
syn keyword	squidConf	high_response_time_warning high_page_fault_warning
syn keyword	squidConf	htcp_port http_access http_anonymizer httpd_accel
syn keyword	squidConf	httpd_accel_host httpd_accel_port
syn keyword	squidConf	httpd_accel_uses_host_header
syn keyword	squidConf	httpd_accel_with_proxy http_port http_reply_access
syn keyword	squidConf	icp_access icp_hit_stale icp_port
syn keyword	squidConf	icp_query_timeout ident_lookup ident_lookup_access
syn keyword	squidConf	ident_timeout incoming_http_average
syn keyword	squidConf	incoming_icp_average inside_firewall ipcache_high
syn keyword	squidConf	ipcache_low ipcache_size local_domain local_ip
syn keyword	squidConf	logfile_rotate log_fqdn log_icp_queries
syn keyword	squidConf	log_mime_hdrs maximum_object_size
syn keyword	squidConf	maximum_single_addr_tries mcast_groups
syn keyword	squidConf	mcast_icp_query_timeout mcast_miss_addr
syn keyword	squidConf	mcast_miss_encode_key mcast_miss_port memory_pools
syn keyword	squidConf	memory_pools_limit memory_replacement_policy
syn keyword	squidConf	mime_table min_http_poll_cnt min_icp_poll_cnt
syn keyword	squidConf	minimum_direct_hops minimum_object_size
syn keyword	squidConf	minimum_retry_timeout miss_access negative_dns_ttl
syn keyword	squidConf	negative_ttl neighbor_timeout neighbor_type_domain
syn keyword	squidConf	netdb_high netdb_low netdb_ping_period
syn keyword	squidConf	netdb_ping_rate never_direct no_cache
syn keyword	squidConf	passthrough_proxy pconn_timeout pid_filename
syn keyword	squidConf	pinger_program positive_dns_ttl prefer_direct
syn keyword	squidConf	proxy_auth proxy_auth_realm query_icmp quick_abort
syn keyword	squidConf	quick_abort quick_abort_max quick_abort_min
syn keyword	squidConf	quick_abort_pct range_offset_limit read_timeout
syn keyword	squidConf	redirect_children redirect_program
syn keyword	squidConf	redirect_rewrites_host_header reference_age
syn keyword	squidConf	reference_age refresh_pattern reload_into_ims
syn keyword	squidConf	request_body_max_size request_size request_timeout
syn keyword	squidConf	shutdown_lifetime single_parent_bypass
syn keyword	squidConf	siteselect_timeout snmp_access
syn keyword	squidConf	snmp_incoming_address snmp_port source_ping
syn keyword	squidConf	ssl_proxy store_avg_object_size
syn keyword	squidConf	store_objects_per_bucket strip_query_terms
syn keyword	squidConf	swap_level1_dirs swap_level2_dirs
syn keyword	squidConf	tcp_incoming_address tcp_outgoing_address
syn keyword	squidConf	tcp_recv_bufsize test_reachability udp_hit_obj
syn keyword	squidConf	udp_hit_obj_size udp_incoming_address
syn keyword	squidConf	udp_outgoing_address unique_hostname
syn keyword	squidConf	unlinkd_program uri_whitespace useragent_log
syn keyword	squidConf	visible_hostname wais_relay wais_relay_host
syn keyword	squidConf	wais_relay_port

syn keyword	squidOpt	proxy-only weight ttl no-query default
syn keyword	squidOpt	round-robin multicast-responder
syn keyword	squidOpt	on off all deny allow
syn keyword	squidopt	via parent no-digest heap lru realm
syn keyword	squidopt	children credentialsttl none disable
syn keyword	squidopt	offline_toggle diskd q1 q2

" Security Actions for cachemgr_passwd
syn keyword	squidAction	shutdown info parameter server_list
syn keyword	squidAction	client_list
syn match	squidAction	"stats/\(objects\|vm_objects\|utilization\|ipcache\|fqdncache\|dns\|redirector\|io\|reply_headers\|filedescriptors\|netdb\)"
syn match	squidAction	"log\(/\(status\|enable\|disable\|clear\)\)\="
syn match	squidAction	"squid\.conf"

" Keywords for the acl-config
syn keyword	squidAcl	url_regex urlpath_regex referer_regex port proto
syn keyword	squidAcl	req_mime_type rep_mime_type
syn keyword	squidAcl	method browser user src dst
syn keyword	squidAcl	time dstdomain ident snmp_community

syn match	squidNumber	"\<\d\+\>"
syn match	squidIP		"\<\d\{1,3}\.\d\{1,3}\.\d\{1,3}\.\d\{1,3}\>"
syn match	squidStr	"\(^\s*acl\s\+\S\+\s\+\(\S*_regex\|re[pq]_mime_type\|browser\|_domain\|user\)\+\s\+\)\@<=.*" contains=squidRegexOpt
syn match	squidRegexOpt	contained "\(^\s*acl\s\+\S\+\s\+\S\+\(_regex\|_mime_type\)\s\+\)\@<=[-+]i\s\+"

" All config is in one line, so this has to be sufficient
" Make it fast like hell :)
syn sync minlines=3

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link squidTodo	Todo
hi def link squidComment	Comment
hi def link squidTag	Special
hi def link squidConf	Keyword
hi def link squidOpt	Constant
hi def link squidAction	String
hi def link squidNumber	Number
hi def link squidIP	Number
hi def link squidAcl	Keyword
hi def link squidStr	String
hi def link squidRegexOpt	Special


let b:current_syntax = "squid"

" vim: ts=8
