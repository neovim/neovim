" Vim syntax file
" Language:	VOS CM macro
" Maintainer:	Andrew McGill andrewm at lunch.za.net
" Last Change:	Apr 06, 2007
" Version:	1
" URL:	http://lunch.za.net/
"

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn case match
" set iskeyword=48-57,_,a-z,A-Z

syn match   voscmStatement     "^!"
syn match voscmStatement	"&\(label\|begin_parameters\|end_parameters\|goto\|attach_input\|break\|continue\|control\|detach_input\|display_line\|display_line_partial\|echo\|eof\|eval\|if\|mode\|return\|while\|set\|set_string\|then\|else\|do\|done\|end\)\>"
syn match  voscmJump		"\(&label\|&goto\)  *"  nextgroup=voscmLabelId
syn match   voscmLabelId	contained "\<[A-Za-z][A-Z_a-z0-9]* *$"
syn match  voscmSetvar		"\(&set_string\|&set\)  *"  nextgroup=voscmVariable
syn match voscmError            "\(&set_string\|&set\)  *&" 
syn match   voscmVariable	contained "\<[A-Za-z][A-Z_a-z0-9]\+\>"
syn keyword voscmParamKeyword   contained number req string switch allow byte disable_input hidden length longword max min no_abbrev output_path req required req_for_form word 
syn region  voscmParamList	matchgroup=voscmParam start="&begin_parameters" end="&end_parameters" contains=voscmParamKeyword,voscmString,voscmParamName,voscmParamId
syn match   voscmParamName	contained "\(^\s*[A-Za-z_0-9]\+\s\+\)\@<=\k\+"
syn match   voscmParamId	contained "\(^\s*\)\@<=\k\+"
syn region par1 matchgroup=par1 start=/(/ end=/)/ contains=voscmFunction,voscmIdentifier,voscmString transparent
" FIXME: functions should only be allowed after a bracket ... ie  (ask ...):
syn keyword voscmFunction     contained abs access after ask before break byte calc ceil command_status concat
syn keyword voscmFunction     contained contents path_name copy count current_dir current_module date date_time
syn keyword voscmFunction     contained decimal directory_name end_of_file exists file_info floor given group_name
syn keyword voscmFunction     contained has_access hexadecimal home_dir index iso_date iso_date_time language_name
syn keyword voscmFunction     contained length lock_type locked ltrim master_disk max message min mod module_info
syn keyword voscmFunction     contained module_name object_name online path_name person_name process_dir process_info
syn keyword voscmFunction     contained process_type quote rank referencing_dir reverse rtrim search
syn keyword voscmFunction     contained software_purchased string substitute substr system_name terminal_info
syn keyword voscmFunction     contained terminal_name time translate trunc unique_string unquote user_name verify
syn keyword voscmFunction     contained where_path
syn keyword voscmTodo contained	TODO FIXME XXX DEBUG NOTE
syn match voscmTab              "\t\+"

syn keyword voscmCommand        add_entry_names add_library_path add_profile analyze_pc_samples attach_default_output attach_port batch bind break_process c c_preprocess call_thru cancel_batch_requests cancel_device_reservation cancel_print_requests cc change_current_dir check_posix cobol comment_on_manual compare_dirs compare_files convert_text_file copy_dir copy_file copy_tape cpp create_data_object create_deleted_record_index create_dir create_file create_index create_record_index create_tape_volumes cvt_fixed_to_stream cvt_stream_to_fixed debug delete_dir delete_file delete_index delete_library_path detach_default_output detach_port dismount_tape display display_access display_access_list display_batch_status display_current_dir display_current_module display_date_time display_default_access_list display_device_info display_dir_status display_disk_info display_disk_usage display_error display_file display_file_status display_line display_notices display_object_module_info display_print_defaults display_print_status display_program_module display_system_usage display_tape_params display_terminal_parameters dump_file dump_record dump_tape edit edit_form emacs enforce_region_locks fortran get_external_variable give_access give_default_access handle_sig_dfl harvest_pc_samples help kill line_edit link link_dirs list list_batch_requests list_devices list_gateways list_library_paths list_modules list_port_attachments list_print_requests list_process_cmd_limits list_save_tape list_systems list_tape list_terminal_types list_users locate_files locate_large_files login logout mount_tape move_device_reservation move_dir move_file mp_debug nls_edit_form pascal pl1 position_tape preprocess_file print profile propagate_access read_tape ready remove_access remove_default_access rename reserve_device restore_object save_object send_message set set_cpu_time_limit set_expiration_date set_external_variable set_file_allocation set_implicit_locking set_index_flags set_language set_library_paths set_line_wrap_width set_log_protected_file set_owner_access set_pipe_file set_priority set_ready set_safety_switch set_second_tape set_tape_drive_params set_tape_file_params set_tape_mount_params set_terminal_parameters set_text_file set_time_zone sleep sort start_logging start_process stop_logging stop_process tail_file text_data_merge translate_links truncate_file unlink update_batch_requests update_print_requests update_process_cmd_limits use_abbreviations use_message_file vcc verify_posix_access verify_save verify_system_access walk_dir where_command where_path who_locked write_tape 

syn match voscmIdentifier	"&[A-Za-z][a-z0-9_A-Z]*&"

syn match voscmString		"'[^']*'"

" Number formats
syn match voscmNumber		"\<\d\+\>"
"Floating point number part only
syn match voscmDecimalNumber	"\.\d\+\([eE][-+]\=\d\)\=\>"

"syn region voscmComment	start="^[ 	]*&[ 	]+"	end="$"
"syn match voscmComment		"^[ 	]*&[ 	].*$"
"syn match voscmComment		"^&$"
syn region voscmComment		start="^[ 	]*&[ 	]" end="$" contains=voscmTodo
syn match voscmComment		"^&$"
syn match voscmContinuation	"&+$"

"syn match  voscmIdentifier	"[A-Za-z0-9&._-]\+"

"Synchronization with Statement terminator $
" syn sync maxlines=100

hi def link voscmConditional	Conditional
hi def link voscmStatement	Statement
hi def link voscmSetvar         Statement
hi def link voscmNumber         Number
hi def link voscmDecimalNumber	Float
hi def link voscmString         String
hi def link voscmIdentifier	Identifier
hi def link voscmVariable	Identifier
hi def link voscmComment	Comment
hi def link voscmJump	        Statement
hi def link voscmContinuation	Macro
hi def link voscmLabelId	String
hi def link voscmParamList	NONE
hi def link voscmParamId	Identifier
hi def link voscmParamName	String
hi def link voscmParam	        Statement
hi def link voscmParamKeyword	Statement
hi def link voscmFunction	Function
hi def link voscmCommand	Structure
"hi def link voscmIdentifier	NONE
"hi def link voscmSpecial	Special   " not used 
hi def link voscmTodo           Todo
hi def link voscmTab          	Error
hi def link voscmError         	Error

let b:current_syntax = "voscm"

" vim: ts=8
