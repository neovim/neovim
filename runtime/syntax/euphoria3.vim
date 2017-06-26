" Vim syntax file
" Language:	Euphoria 3.1.1 - supports DOS - (http://www.rapideuphoria.com/)
" Maintainer:	Shian Lee  
" Last Change:	2014 Feb 24 (for Vim 7.4)
" Remark:       Euphoria has two syntax files, euphoria3.vim and euphoria4.vim; 
"               For details see :help ft-euphoria-syntax

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Reset compatible-options to Vim default value, just in case: 
let s:save_cpo = &cpo
set cpo&vim

" Should suffice for very long expressions:
syn sync lines=40

" Euphoria is a case-sensitive language (with only 4 builtin types):
syntax case match 

" Keywords/Builtins for Debug - from $EUDIR/bin/keywords.e:
syn keyword euphoria3Debug	with without trace profile  
syn keyword euphoria3Debug	profile_time warning type_check 

" Keywords (Statments) - from $EUDIR/bin/keywords.e:
syn keyword euphoria3Keyword	if end then procedure else for return 	
syn keyword euphoria3Keyword	do elsif while type constant to and or
syn keyword euphoria3Keyword	exit function global by not include
syn keyword euphoria3Keyword	xor                      

" Builtins (Identifiers) - from $EUDIR/bin/keywords.e:
syn keyword euphoria3Builtin	length puts integer sequence position object
syn keyword euphoria3Builtin	append prepend print printf 
syn keyword euphoria3Builtin	clear_screen floor getc gets get_key
syn keyword euphoria3Builtin	rand repeat atom compare find match
syn keyword euphoria3Builtin	time command_line open close getenv
syn keyword euphoria3Builtin	sqrt sin cos tan log system date remainder
syn keyword euphoria3Builtin	power machine_func machine_proc abort peek poke 
syn keyword euphoria3Builtin	call sprintf arctan and_bits or_bits xor_bits
syn keyword euphoria3Builtin	not_bits pixel get_pixel mem_copy mem_set
syn keyword euphoria3Builtin	c_proc c_func routine_id call_proc call_func 
syn keyword euphoria3Builtin	poke4 peek4s peek4u equal system_exec
syn keyword euphoria3Builtin	platform task_create task_schedule task_yield
syn keyword euphoria3Builtin	task_self task_suspend task_list
syn keyword euphoria3Builtin	task_status task_clock_stop task_clock_start 
syn keyword euphoria3Builtin	find_from match_from  
" Builtins (Identifiers) shortcuts for length() and print():
syn match   euphoria3Builtin	"\$" 
syn match   euphoria3Builtin	"?"

" Library Identifiers (Function) - from $EUDIR/doc/library.doc:
syn keyword euphoria3Library	reverse sort custom_sort lower upper
syn keyword euphoria3Library	wildcard_match wildcard_file arcsin 
syn keyword euphoria3Library	arccos PI flush lock_file unlock_file
syn keyword euphoria3Library	pretty_print sprint get_bytes prompt_string 
syn keyword euphoria3Library	wait_key get prompt_number value seek where 
syn keyword euphoria3Library	current_dir chdir dir walk_dir allow_break 
syn keyword euphoria3Library	check_break get_mouse mouse_events mouse_pointer
syn keyword euphoria3Library	tick_rate sleep get_position graphics_mode 
syn keyword euphoria3Library	video_config scroll wrap text_color bk_color 
syn keyword euphoria3Library	palette all_palette get_all_palette read_bitmap 
syn keyword euphoria3Library	save_bitmap get_active_page set_active_page 
syn keyword euphoria3Library	get_display_page set_display_page sound
syn keyword euphoria3Library	cursor text_rows get_screen_char put_screen_char
syn keyword euphoria3Library	save_text_image display_text_image draw_line 
syn keyword euphoria3Library	polygon ellipse save_screen save_image display_image 
syn keyword euphoria3Library	dos_interrupt allocate free allocate_low free_low 
syn keyword euphoria3Library	allocate_string register_block unregister_block 
syn keyword euphoria3Library	get_vector set_vector lock_memory int_to_bytes 
syn keyword euphoria3Library	bytes_to_int int_to_bits bits_to_int atom_to_float64 
syn keyword euphoria3Library	atom_to_float32 float64_to_atom float32_to_atom 
syn keyword euphoria3Library	set_rand use_vesa crash_file crash_message
syn keyword euphoria3Library	crash_routine open_dll define_c_proc define_c_func
syn keyword euphoria3Library	define_c_var call_back message_box free_console 
syn keyword euphoria3Library	instance

" Library Identifiers (Function) - from $EUDIR/doc/database.doc:
syn keyword euphoria3Library 	db_create db_open db_select db_close db_create_table
syn keyword euphoria3Library 	db_select_table db_rename_table db_delete_table
syn keyword euphoria3Library 	db_table_list db_table_size db_find_key db_record_key
syn keyword euphoria3Library 	db_record_data db_insert db_delete_record 
syn keyword euphoria3Library	db_replace_data	db_compress db_dump db_fatal_id

" Linux shell comment (#!...):
syn match   euphoria3Comment	"\%^#!.*$"
" Comment on one line:
syn region  euphoria3Comment 	start=/--/ end=/$/

" Delimiters and brackets:
syn match   euphoria3Delimit	"[([\])]"
syn match   euphoria3Delimit	"\.\."
syn match   euphoria3Operator	"[{}]"

" Character constant:
syn region  euphoria3Char	start=/'/ skip=/\\'\|\\\\/ end=/'/ oneline

" String constant: 
syn region  euphoria3String	start=/"/ skip=/\\"\|\\\\/ end=/"/ oneline

" Hexadecimal integer:
syn match   euphoria3Number 	"#[0-9A-F]\+\>"

" Integer/Floating point without a dot:
syn match   euphoria3Number	"\<\d\+\>"
" Floating point with dot:
syn match   euphoria3Number	"\<\d\+\.\d*\>"
" Floating point starting with a dot:
syn match   euphoria3Number	"\.\d\+\>"
" Boolean constants: 
syn keyword euphoria3Boolean	true TRUE false FALSE

" Define the default highlighting.
" Only used when an item doesn't have highlighting yet:
hi def link euphoria3Comment	Comment
hi def link euphoria3String	String
hi def link euphoria3Char	Character
hi def link euphoria3Number	Number	
hi def link euphoria3Boolean	Boolean	
hi def link euphoria3Builtin	Identifier	
hi def link euphoria3Library 	Function	
hi def link euphoria3Keyword	Statement	
hi def link euphoria3Operator	Statement	
hi def link euphoria3Debug	Debug	
hi def link euphoria3Delimit	Delimiter	
 	
let b:current_syntax = "euphoria3"

" Restore current compatible-options: 
let &cpo = s:save_cpo
unlet s:save_cpo

