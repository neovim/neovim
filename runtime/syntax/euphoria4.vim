" Vim syntax file
" Language:	Euphoria 4.0.5 (http://www.openeuphoria.org/)
" Maintainer:	Shian Lee  
" Last Change:	2014 Feb 26 (for Vim 7.4)
" Remark:       Euphoria has two syntax files, euphoria3.vim and euphoria4.vim; 
"               For details see :help ft-euphoria-syntax

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Reset compatible-options to Vim default value, just in case: 
let s:save_cpo = &cpo
set cpo&vim

" Should suffice for very long strings and expressions:
syn sync lines=40

" Euphoria is a case-sensitive language (with only 4 builtin types):
syntax case match 

" Some keywords/Builtins for Debug - from $EUDIR/include/euphoria/keywords.e:
syn keyword euphoria4Debug	with without trace profile batch check indirect 
syn keyword euphoria4Debug	includes inline warning define

" Keywords for conditional compilation - from $EUDIR/include/euphoria/keywords.e:
syn keyword euphoria4PreProc	elsedef elsifdef ifdef 

" Keywords (Statements) - from $EUDIR/include/euphoria/keywords.e:
syn keyword euphoria4Keyword	and as break by case constant continue do else     
syn keyword euphoria4Keyword	elsif end entry enum exit export
syn keyword euphoria4Keyword	fallthru for function global goto if include
syn keyword euphoria4Keyword	label loop namespace not or override procedure
syn keyword euphoria4Keyword	public retry return routine switch then to type
syn keyword euphoria4Keyword	until while xor

" Builtins (Identifiers) - from $EUDIR/include/euphoria/keywords.e:
syn keyword euphoria4Builtin	abort and_bits append arctan atom c_func c_proc 
syn keyword euphoria4Builtin	call call_func call_proc clear_screen close 
syn keyword euphoria4Builtin	command_line compare cos date delete delete_routine 
syn keyword euphoria4Builtin	equal find floor get_key getc getenv gets hash 
syn keyword euphoria4Builtin	head include_paths insert integer length log 
syn keyword euphoria4Builtin	machine_func machine_proc match mem_copy mem_set 
syn keyword euphoria4Builtin	not_bits object open option_switches or_bits peek 
syn keyword euphoria4Builtin	peek2s peek2u peek4s peek4u peek_string peeks pixel 
syn keyword euphoria4Builtin	platform poke poke2 poke4 position power prepend 
syn keyword euphoria4Builtin	print printf puts rand remainder remove repeat 
syn keyword euphoria4Builtin	replace routine_id sequence sin splice sprintf
syn keyword euphoria4Builtin	sqrt system system_exec tail tan task_clock_start
syn keyword euphoria4Builtin	task_clock_stop task_create task_list task_schedule
syn keyword euphoria4Builtin	task_self task_status task_suspend task_yield time
syn keyword euphoria4Builtin	xor_bits
" Builtins (Identifiers) shortcuts for length() and print():
syn match   euphoria4Builtin	"\$" 
syn match   euphoria4Builtin	"?"

" Library Identifiers (Function) - grep from $EUDIR/include/*:
syn keyword euphoria4Library	DEP_on SyntaxColor abbreviate_path abs absolute_path
syn keyword euphoria4Library 	accept add add_item all_copyrights all_matches
syn keyword euphoria4Library	allocate allocate_code allocate_data allocate_low
syn keyword euphoria4Library 	allocate_pointer_array allocate_protect
syn keyword euphoria4Library 	allocate_string allocate_string_pointer_array
syn keyword euphoria4Library	allocate_wstring allocations allow_break any_key
syn keyword euphoria4Library	append_lines apply approx arccos arccosh arcsin
syn keyword euphoria4Library 	arcsinh arctanh assert at atan2 atom_to_float32
syn keyword euphoria4Library 	atom_to_float64 attr_to_colors avedev average
syn keyword euphoria4Library 	begins binary_search bind binop_ok bits_to_int
syn keyword euphoria4Library 	bk_color breakup build_commandline build_list
syn keyword euphoria4Library 	bytes_to_int calc_hash calc_primes call_back
syn keyword euphoria4Library 	canon2win canonical canonical_path ceil
syn keyword euphoria4Library 	central_moment chance char_test chdir
syn keyword euphoria4Library 	check_all_blocks check_break check_free_list
syn keyword euphoria4Library 	checksum clear clear_directory cmd_parse
syn keyword euphoria4Library 	colors_to_attr columnize combine connect
syn keyword euphoria4Library 	console_colors copy copy_file cosh count crash
syn keyword euphoria4Library 	crash_file crash_message crash_routine create
syn keyword euphoria4Library 	create_directory create_file curdir current_dir
syn keyword euphoria4Library	cursor custom_sort datetime days_in_month
syn keyword euphoria4Library 	days_in_year db_cache_clear db_clear_table db_close
syn keyword euphoria4Library	db_compress db_connect db_create db_create_table
syn keyword euphoria4Library 	db_current db_current_table db_delete_record
syn keyword euphoria4Library 	db_delete_table db_dump db_fetch_record db_find_key
syn keyword euphoria4Library	db_get_errors db_get_recid db_insert db_open
syn keyword euphoria4Library	db_record_data db_record_key db_record_recid
syn keyword euphoria4Library 	db_rename_table db_replace_data db_replace_recid
syn keyword euphoria4Library 	db_select db_select_table db_set_caching
syn keyword euphoria4Library 	db_table_list db_table_size deallocate decanonical
syn keyword euphoria4Library 	decode defaulted_value defaultext define_c_func
syn keyword euphoria4Library 	define_c_proc define_c_var deg2rad delete_file
syn keyword euphoria4Library 	dep_works dequote deserialize diff dir dir_size
syn keyword euphoria4Library 	dirname disk_metrics disk_size display
syn keyword euphoria4Library 	display_text_image dnsquery driveid dump dup emovavg
syn keyword euphoria4Library 	encode ends ensure_in_list ensure_in_range
syn keyword euphoria4Library 	error_code error_message error_no error_string
syn keyword euphoria4Library 	error_to_string escape euphoria_copyright exec
syn keyword euphoria4Library 	exp extract fetch fib file_exists file_length
syn keyword euphoria4Library 	file_timestamp file_type filebase fileext filename
syn keyword euphoria4Library	filter find_all find_all_but find_any find_each
syn keyword euphoria4Library 	find_nested find_replace find_replace_callback
syn keyword euphoria4Library	find_replace_limit flags_to_string flatten
syn keyword euphoria4Library 	float32_to_atom float64_to_atom flush for_each
syn keyword euphoria4Library 	format frac free free_code free_console free_low
syn keyword euphoria4Library	free_pointer_array from_date from_unix gcd geomean
syn keyword euphoria4Library	get get_bytes get_charsets get_def_lang
syn keyword euphoria4Library 	get_display_page get_dstring get_encoding_properties
syn keyword euphoria4Library 	get_integer16 get_integer32 get_lang_path get_lcid
syn keyword euphoria4Library 	get_mouse get_option get_ovector_size get_pid
syn keyword euphoria4Library 	get_position get_rand get_screen_char get_text
syn keyword euphoria4Library 	get_vector getaddrinfo getmxrr getnsrr graphics_mode
syn keyword euphoria4Library 	harmean has has_console has_match hex_text
syn keyword euphoria4Library 	host_by_addr host_by_name http_get http_post iff
syn keyword euphoria4Library 	iif info init_class init_curdir insertion_sort
syn keyword euphoria4Library 	instance int_to_bits int_to_bytes intdiv
syn keyword euphoria4Library 	is_DEP_supported is_empty is_even is_even_obj
syn keyword euphoria4Library 	is_in_list is_in_range is_inetaddr is_leap_year
syn keyword euphoria4Library 	is_match is_using_DEP is_win_nt join join_path
syn keyword euphoria4Library 	keep_comments keep_newlines key_codes keys keyvalues
syn keyword euphoria4Library	kill kurtosis lang_load larger_of largest last
syn keyword euphoria4Library 	listen load load_map locate_file lock_file
syn keyword euphoria4Library	lock_memory log10 lookup lower malloc mapping
syn keyword euphoria4Library 	match_all match_any match_replace matches max
syn keyword euphoria4Library 	maybe_any_key median memory_used merge message_box
syn keyword euphoria4Library	mid min minsize mod mode money mouse_events
syn keyword euphoria4Library	mouse_pointer movavg move_file nested_get
syn keyword euphoria4Library 	nested_put new new_extra new_from_kvpairs
syn keyword euphoria4Library 	new_from_string new_time next_prime now now_gmt
syn keyword euphoria4Library 	number open_dll optimize option_spec_to_string
syn keyword euphoria4Library 	or_all	pad_head pad_tail pairs parse
syn keyword euphoria4Library 	parse_commandline parse_ip_address parse_querystring
syn keyword euphoria4Library 	parse_url patch pathinfo pathname pcre_copyright
syn keyword euphoria4Library 	peek_end peek_top peek_wstring pivot platform_name
syn keyword euphoria4Library 	poke_string poke_wstring pop powof2 prepare_block
syn keyword euphoria4Library 	pretty_print pretty_sprint prime_list process_lines
syn keyword euphoria4Library 	product project prompt_number prompt_string proper
syn keyword euphoria4Library 	push put put_integer16 put_integer32 put_screen_char
syn keyword euphoria4Library 	quote rad2deg rand_range range raw_frequency read
syn keyword euphoria4Library 	read_bitmap read_file read_lines receive receive_from
syn keyword euphoria4Library	register_block rehash remove_all remove_directory
syn keyword euphoria4Library 	remove_dups remove_item remove_subseq rename_file
syn keyword euphoria4Library	repeat_pattern reset retain_all reverse rfind rmatch
syn keyword euphoria4Library 	rnd rnd_1 roll rotate rotate_bits round safe_address
syn keyword euphoria4Library 	sample save_bitmap save_map save_text_image scroll
syn keyword euphoria4Library	seek select send send_to serialize series
syn keyword euphoria4Library	service_by_name service_by_port set
syn keyword euphoria4Library 	set_accumulate_summary set_charsets set_colors
syn keyword euphoria4Library 	set_decimal_mark set_def_lang set_default_charsets
syn keyword euphoria4Library 	set_encoding_properties set_keycodes set_lang_path
syn keyword euphoria4Library 	set_option set_rand set_test_abort set_test_verbosity
syn keyword euphoria4Library 	set_vector set_wait_on_summary setenv shift_bits
syn keyword euphoria4Library 	show_block show_help show_tokens shuffle shutdown
syn keyword euphoria4Library 	sign sim_index sinh size skewness sleep slice small
syn keyword euphoria4Library 	smaller_of smallest sort sort_columns sound split
syn keyword euphoria4Library 	split_any split_limit split_path sprint start_time
syn keyword euphoria4Library 	statistics stdev store string_numbers subtract sum
syn keyword euphoria4Library 	sum_central_moments swap tanh task_delay temp_file
syn keyword euphoria4Library 	test_equal test_exec test_fail test_false
syn keyword euphoria4Library 	test_not_equal test_pass test_read test_report
syn keyword euphoria4Library	test_true test_write text_color text_rows threshold
syn keyword euphoria4Library 	tick_rate to_integer to_number to_string to_unix
syn keyword euphoria4Library	tokenize_file tokenize_string top transform translate
syn keyword euphoria4Library 	transmute trim trim_head trim_tail trsprintf trunc
syn keyword euphoria4Library 	type_of uname unlock_file unregister_block unsetenv
syn keyword euphoria4Library	upper use_vesa valid valid_index value values version
syn keyword euphoria4Library	version_date version_major version_minor version_node
syn keyword euphoria4Library 	version_patch version_revision version_string
syn keyword euphoria4Library 	version_string_long version_string_short version_type
syn keyword euphoria4Library 	video_config vlookup vslice wait_key walk_dir
syn keyword euphoria4Library 	warning_file weeks_day where which_bit wildcard_file
syn keyword euphoria4Library 	wildcard_match wrap write write_file write_lines
syn keyword euphoria4Library 	writef writefln years_day

" Library Identifiers (Type) - grep from $EUDIR/include/*:
syn keyword euphoria4Type	ascii_string boolean bordered_address byte_range
syn keyword euphoria4Type	case_flagset_type color cstring 
syn keyword euphoria4Type	file_number file_position graphics_point
syn keyword euphoria4Type	integer_array lcid lock_type machine_addr map 
syn keyword euphoria4Type	mixture number_array option_spec
syn keyword euphoria4Type	page_aligned_address positive_int process regex
syn keyword euphoria4Type	sequence_array socket stack std_library_address
syn keyword euphoria4Type	string t_alnum t_alpha t_ascii t_boolean
syn keyword euphoria4Type	t_bytearray t_cntrl t_consonant t_digit t_display
syn keyword euphoria4Type	t_graph t_identifier t_lower t_print t_punct
syn keyword euphoria4Type	t_space t_specword t_text t_upper t_vowel t_xdigit
syn keyword euphoria4Type	valid_memory_protection_constant valid_wordsize

" Linux shell comment (#!...):
syn match   euphoria4Comment	"\%^#!.*$"
" Single and multilines comments: 
syn region  euphoria4Comment 	start=/--/ end=/$/ 
syn region  euphoria4Comment 	start="/\*" end="\*/" 

" Delimiters and brackets:
syn match   euphoria4Delimit	"[([\])]"
syn match   euphoria4Delimit	"\.\."
syn match   euphoria4Delimit	":"
syn match   euphoria4Operator	"[{}]"

" Character constant:
syn region  euphoria4Char	start=/'/ skip=/\\'\|\\\\/ end=/'/ oneline

" String constant (""" must be *after* "): 
syn region  euphoria4String	start=/"/ skip=/\\"\|\\\\/ end=/"/ oneline 
syn region  euphoria4String	start=/b"\|x"/ end=/"/ 
syn region  euphoria4String	start=/`/ end=/`/
syn region  euphoria4String	start=/"""/ end=/"""/

" Binary/Octal/Decimal/Hexadecimal integer:
syn match   euphoria4Number 	"\<0b[01_]\+\>"
syn match   euphoria4Number 	"\<0t[0-7_]\+\>"
syn match   euphoria4Number 	"\<0d[0-9_]\+\>"
syn match   euphoria4Number 	"\<0x[0-9A-Fa-f_]\+\>"
syn match   euphoria4Number 	"#[0-9A-Fa-f_]\+\>"

" Integer/Floating point without a dot:
syn match   euphoria4Number	"\<\d\+\>"
" Floating point with dot:
syn match   euphoria4Number	"\<\d\+\.\d*\>"
" Floating point starting with a dot:
syn match   euphoria4Number	"\.\d\+\>"
" Boolean constants: 
syn keyword euphoria4Boolean	true TRUE false FALSE

" Define the default highlighting.
" Only used when an item doesn't have highlighting yet:
hi def link euphoria4Comment	Comment
hi def link euphoria4String	String
hi def link euphoria4Char	Character
hi def link euphoria4Number	Number	
hi def link euphoria4Boolean	Boolean	
hi def link euphoria4Builtin	Identifier	
hi def link euphoria4Library 	Function	
hi def link euphoria4Type 	Type	
hi def link euphoria4Keyword	Statement	
hi def link euphoria4Operator	Statement		
hi def link euphoria4Debug	Debug	
hi def link euphoria4Delimit	Delimiter	
hi def link euphoria4PreProc	PreProc	
	
let b:current_syntax = "euphoria4"

" Restore current compatible-options: 
let &cpo = s:save_cpo
unlet s:save_cpo

