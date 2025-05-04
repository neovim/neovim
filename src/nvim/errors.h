#pragma once

#include "nvim/gettext_defs.h"
#include "nvim/macros_defs.h"

//
// Shared error messages. Excludes errors only used once and debugging messages.
//
// uncrustify:off
EXTERN const char e_abort[] INIT(= N_("E470: Command aborted"));
EXTERN const char e_afterinit[] INIT(= N_("E905: Cannot set this option after startup"));
EXTERN const char e_api_spawn_failed[] INIT(= N_("E903: Could not spawn API job"));
EXTERN const char e_argreq[] INIT(= N_("E471: Argument required"));
EXTERN const char e_backslash[] INIT(= N_("E10: \\ should be followed by /, ? or &"));
EXTERN const char e_cmdwin[] INIT(= N_("E11: Invalid in command-line window; <CR> executes, CTRL-C quits"));
EXTERN const char e_curdir[] INIT(= N_("E12: Command not allowed in secure mode in current dir or tag search"));
EXTERN const char e_invalid_buffer_name_str[] INIT(= N_("E158: Invalid buffer name: %s"));
EXTERN const char e_command_too_recursive[] INIT(= N_("E169: Command too recursive"));
EXTERN const char e_buffer_is_not_loaded[] INIT(= N_("E681: Buffer is not loaded"));
EXTERN const char e_endif[] INIT(= N_("E171: Missing :endif"));
EXTERN const char e_endtry[] INIT(= N_("E600: Missing :endtry"));
EXTERN const char e_endwhile[] INIT(= N_("E170: Missing :endwhile"));
EXTERN const char e_endfor[] INIT(= N_("E170: Missing :endfor"));
EXTERN const char e_while[] INIT(= N_("E588: :endwhile without :while"));
EXTERN const char e_for[] INIT(= N_("E588: :endfor without :for"));
EXTERN const char e_exists[] INIT(= N_("E13: File exists (add ! to override)"));
EXTERN const char e_failed[] INIT(= N_("E472: Command failed"));
EXTERN const char e_internal[] INIT(= N_("E473: Internal error"));
EXTERN const char e_intern2[] INIT(= N_("E685: Internal error: %s"));
EXTERN const char e_interr[] INIT(= N_("Interrupted"));
EXTERN const char e_invarg[] INIT(= N_("E474: Invalid argument"));
EXTERN const char e_invarg2[] INIT(= N_("E475: Invalid argument: %s"));
EXTERN const char e_invargval[] INIT(= N_("E475: Invalid value for argument %s"));
EXTERN const char e_invargNval[] INIT(= N_("E475: Invalid value for argument %s: %s"));
EXTERN const char e_duparg2[] INIT(= N_("E983: Duplicate argument: %s"));
EXTERN const char e_invexpr2[] INIT(= N_("E15: Invalid expression: \"%s\""));
EXTERN const char e_invrange[] INIT(= N_("E16: Invalid range"));
EXTERN const char e_invcmd[] INIT(= N_("E476: Invalid command"));
EXTERN const char e_isadir2[] INIT(= N_("E17: \"%s\" is a directory"));
EXTERN const char e_no_spell[] INIT(= N_("E756: Spell checking is not possible"));
EXTERN const char e_invchan[] INIT(= N_("E900: Invalid channel id"));
EXTERN const char e_invchanjob[] INIT(= N_("E900: Invalid channel id: not a job"));
EXTERN const char e_jobtblfull[] INIT(= N_("E901: Job table is full"));
EXTERN const char e_jobspawn[] INIT(= N_("E903: Process failed to start: %s: \"%s\""));
EXTERN const char e_channotpty[] INIT(= N_("E904: channel is not a pty"));
EXTERN const char e_stdiochan2[] INIT(= N_("E905: Couldn't open stdio channel: %s"));
EXTERN const char e_invstream[] INIT(= N_("E906: invalid stream for channel"));
EXTERN const char e_invstreamrpc[] INIT(= N_("E906: invalid stream for rpc channel, use 'rpc'"));
EXTERN const char e_streamkey[] INIT(= N_("E5210: dict key '%s' already set for buffered stream in channel %" PRIu64));
EXTERN const char e_libcall[] INIT(= N_("E364: Library call failed for \"%s()\""));
EXTERN const char e_fsync[] INIT(= N_("E667: Fsync failed: %s"));
EXTERN const char e_mkdir[] INIT(= N_("E739: Cannot create directory %s: %s"));
EXTERN const char e_markinval[] INIT(= N_("E19: Mark has invalid line number"));
EXTERN const char e_marknotset[] INIT(= N_("E20: Mark not set"));
EXTERN const char e_modifiable[] INIT(= N_("E21: Cannot make changes, 'modifiable' is off"));
EXTERN const char e_nesting[] INIT(= N_("E22: Scripts nested too deep"));
EXTERN const char e_noalt[] INIT(= N_("E23: No alternate file"));
EXTERN const char e_noabbr[] INIT(= N_("E24: No such abbreviation"));
EXTERN const char e_nobang[] INIT(= N_("E477: No ! allowed"));
EXTERN const char e_nogroup[] INIT(= N_("E28: No such highlight group name: %s"));
EXTERN const char e_noinstext[] INIT(= N_("E29: No inserted text yet"));
EXTERN const char e_nolastcmd[] INIT(= N_("E30: No previous command line"));
EXTERN const char e_nomap[] INIT(= N_("E31: No such mapping"));
EXTERN const char e_nomatch[] INIT(= N_("E479: No match"));
EXTERN const char e_nomatch2[] INIT(= N_("E480: No match: %s"));
EXTERN const char e_noname[] INIT(= N_("E32: No file name"));
EXTERN const char e_nopresub[] INIT(= N_("E33: No previous substitute regular expression"));
EXTERN const char e_noprev[] INIT(= N_("E34: No previous command"));
EXTERN const char e_noprevre[] INIT(= N_("E35: No previous regular expression"));
EXTERN const char e_norange[] INIT(= N_("E481: No range allowed"));
EXTERN const char e_noroom[] INIT(= N_("E36: Not enough room"));
EXTERN const char e_notmp[] INIT(= N_("E483: Can't get temp file name"));
EXTERN const char e_notopen[] INIT(= N_("E484: Can't open file %s"));
EXTERN const char e_notopen_2[] INIT(= N_("E484: Can't open file %s: %s"));
EXTERN const char e_notread[] INIT(= N_("E485: Can't read file %s"));
EXTERN const char e_null[] INIT(= N_("E38: Null argument"));
EXTERN const char e_number_exp[] INIT(= N_("E39: Number expected"));
EXTERN const char e_openerrf[] INIT(= N_("E40: Can't open errorfile %s"));
EXTERN const char e_outofmem[] INIT(= N_("E41: Out of memory!"));
EXTERN const char e_patnotf[] INIT(= N_("Pattern not found"));
EXTERN const char e_patnotf2[] INIT(= N_("E486: Pattern not found: %s"));
EXTERN const char e_positive[] INIT(= N_("E487: Argument must be positive"));
EXTERN const char e_prev_dir[] INIT(= N_("E459: Cannot go back to previous directory"));

EXTERN const char e_no_errors[] INIT(= N_("E42: No Errors"));
EXTERN const char e_loclist[] INIT(= N_("E776: No location list"));
EXTERN const char e_re_damg[] INIT(= N_("E43: Damaged match string"));
EXTERN const char e_re_corr[] INIT(= N_("E44: Corrupted regexp program"));
EXTERN const char e_readonly[] INIT(= N_("E45: 'readonly' option is set (add ! to override)"));
EXTERN const char e_letwrong[] INIT(= N_("E734: Wrong variable type for %s="));
EXTERN const char e_illvar[] INIT(= N_("E461: Illegal variable name: %s"));
EXTERN const char e_cannot_mod[] INIT(= N_("E995: Cannot modify existing variable"));
EXTERN const char e_readonlyvar[] INIT(= N_("E46: Cannot change read-only variable \"%.*s\""));
EXTERN const char e_stringreq[] INIT(= N_("E928: String required"));
EXTERN const char e_dictreq[] INIT(= N_("E715: Dictionary required"));
EXTERN const char e_blobidx[] INIT(= N_("E979: Blob index out of range: %" PRId64));
EXTERN const char e_invalblob[] INIT(= N_("E978: Invalid operation for Blob"));
EXTERN const char e_toomanyarg[] INIT(= N_("E118: Too many arguments for function: %s"));
EXTERN const char e_toofewarg[] INIT(= N_("E119: Not enough arguments for function: %s"));
EXTERN const char e_dictkey[] INIT(= N_("E716: Key not present in Dictionary: \"%s\""));
EXTERN const char e_dictkey_len[] INIT(= N_("E716: Key not present in Dictionary: \"%.*s\""));
EXTERN const char e_listreq[] INIT(= N_("E714: List required"));
EXTERN const char e_listblobreq[] INIT(= N_("E897: List or Blob required"));
EXTERN const char e_listdictarg[] INIT(= N_("E712: Argument of %s must be a List or Dictionary"));
EXTERN const char e_listdictblobarg[] INIT(= N_("E896: Argument of %s must be a List, Dictionary or Blob"));
EXTERN const char e_readerrf[] INIT(= N_("E47: Error while reading errorfile"));
EXTERN const char e_sandbox[] INIT(= N_("E48: Not allowed in sandbox"));
EXTERN const char e_secure[] INIT(= N_("E523: Not allowed here"));
EXTERN const char e_textlock[] INIT(= N_("E565: Not allowed to change text or change window"));
EXTERN const char e_screenmode[] INIT(= N_("E359: Screen mode setting not supported"));
EXTERN const char e_scroll[] INIT(= N_("E49: Invalid scroll size"));
EXTERN const char e_shellempty[] INIT(= N_("E91: 'shell' option is empty"));
EXTERN const char e_signdata[] INIT(= N_("E255: Couldn't read in sign data!"));
EXTERN const char e_swapclose[] INIT(= N_("E72: Close error on swap file"));
EXTERN const char e_toocompl[] INIT(= N_("E74: Command too complex"));
EXTERN const char e_longname[] INIT(= N_("E75: Name too long"));
EXTERN const char e_toomsbra[] INIT(= N_("E76: Too many ["));
EXTERN const char e_toomany[] INIT(= N_("E77: Too many file names"));
EXTERN const char e_trailing[] INIT(= N_("E488: Trailing characters"));
EXTERN const char e_trailing_arg[] INIT(= N_("E488: Trailing characters: %s"));
EXTERN const char e_umark[] INIT(= N_("E78: Unknown mark"));
EXTERN const char e_wildexpand[] INIT(= N_("E79: Cannot expand wildcards"));
EXTERN const char e_winheight[] INIT(= N_("E591: 'winheight' cannot be smaller than 'winminheight'"));
EXTERN const char e_winwidth[] INIT(= N_("E592: 'winwidth' cannot be smaller than 'winminwidth'"));
EXTERN const char e_write[] INIT(= N_("E80: Error while writing"));
EXTERN const char e_zerocount[] INIT(= N_("E939: Positive count required"));
EXTERN const char e_usingsid[] INIT(= N_("E81: Using <SID> not in a script context"));
EXTERN const char e_missingparen[] INIT(= N_("E107: Missing parentheses: %s"));
EXTERN const char e_empty_buffer[] INIT(= N_("E749: Empty buffer"));
EXTERN const char e_nobufnr[] INIT(= N_("E86: Buffer %" PRId64 " does not exist"));

EXTERN const char e_unknown_function_str[] INIT(= N_("E117: Unknown function: %s"));
EXTERN const char e_str_not_inside_function[] INIT(= N_("E193: %s not inside a function"));

EXTERN const char e_invalpat[] INIT(= N_("E682: Invalid search pattern or delimiter"));
EXTERN const char e_bufloaded[] INIT(= N_("E139: File is loaded in another buffer"));
EXTERN const char e_notset[] INIT(= N_("E764: Option '%s' is not set"));
EXTERN const char e_invalidreg[] INIT(= N_("E850: Invalid register name"));
EXTERN const char e_dirnotf[] INIT(= N_("E919: Directory not found in '%s': \"%s\""));
EXTERN const char e_au_recursive[] INIT(= N_("E952: Autocommand caused recursive behavior"));
EXTERN const char e_menu_only_exists_in_another_mode[]
INIT(= N_("E328: Menu only exists in another mode"));
EXTERN const char e_autocmd_close[] INIT(= N_("E813: Cannot close autocmd window"));
EXTERN const char e_listarg[] INIT(= N_("E686: Argument of %s must be a List"));
EXTERN const char e_unsupportedoption[] INIT(= N_("E519: Option not supported"));
EXTERN const char e_fnametoolong[] INIT(= N_("E856: Filename too long"));
EXTERN const char e_using_float_as_string[] INIT(= N_("E806: Using a Float as a String"));
EXTERN const char e_cannot_edit_other_buf[] INIT(= N_("E788: Not allowed to edit another buffer now"));
EXTERN const char e_using_number_as_bool_nr[] INIT(= N_("E1023: Using a Number as a Bool: %d"));
EXTERN const char e_not_callable_type_str[] INIT(= N_("E1085: Not a callable type: %s"));
EXTERN const char e_auabort[] INIT(= N_("E855: Autocommands caused command to abort"));

EXTERN const char e_api_error[] INIT(= N_("E5555: API call: %s"));

EXTERN const char e_fast_api_disabled[] INIT(= N_("E5560: %s must not be called in a fast event context"));

EXTERN const char e_floatonly[] INIT(= N_("E5601: Cannot close window, only floating window would remain"));
EXTERN const char e_floatexchange[] INIT(= N_("E5602: Cannot exchange or rotate float"));

EXTERN const char e_cant_find_directory_str_in_cdpath[] INIT(= N_("E344: Can't find directory \"%s\" in cdpath"));
EXTERN const char e_cant_find_file_str_in_path[] INIT(= N_("E345: Can't find file \"%s\" in path"));
EXTERN const char e_no_more_directory_str_found_in_cdpath[] INIT(= N_("E346: No more directory \"%s\" found in cdpath"));
EXTERN const char e_no_more_file_str_found_in_path[] INIT(= N_("E347: No more file \"%s\" found in path"));

EXTERN const char e_cannot_define_autocommands_for_all_events[] INIT(= N_("E1155: Cannot define autocommands for ALL events"));

EXTERN const char e_resulting_text_too_long[] INIT(= N_("E1240: Resulting text too long"));

EXTERN const char e_line_number_out_of_range[] INIT(= N_("E1247: Line number out of range"));

EXTERN const char e_highlight_group_name_invalid_char[] INIT(= N_("E5248: Invalid character in group name"));

EXTERN const char e_highlight_group_name_too_long[] INIT(= N_("E1249: Highlight group name too long"));

EXTERN const char e_invalid_column_number_nr[] INIT( = N_("E964: Invalid column number: %ld"));
EXTERN const char e_invalid_line_number_nr[] INIT(= N_("E966: Invalid line number: %ld"));

EXTERN const char e_stray_closing_curly_str[]
INIT(= N_("E1278: Stray '}' without a matching '{': %s"));
EXTERN const char e_missing_close_curly_str[]
INIT(= N_("E1279: Missing '}': %s"));

EXTERN const char e_val_too_large[] INIT(= N_("E1510: Value too large: %s"));

EXTERN const char e_undobang_cannot_redo_or_move_branch[]
INIT(= N_("E5767: Cannot use :undo! to redo or move to a different undo branch"));

EXTERN const char e_winfixbuf_cannot_go_to_buffer[]
INIT(= N_("E1513: Cannot switch buffer. 'winfixbuf' is enabled"));
EXTERN const char e_invalid_return_type_from_findfunc[] INIT( = N_("E1514: 'findfunc' did not return a List type"));
EXTERN const char e_cannot_switch_to_a_closing_buffer[] INIT( = N_("E1546: Cannot switch to a closing buffer"));

EXTERN const char e_trustfile[] INIT(= N_("E5570: Cannot update trust file: %s"));

EXTERN const char e_unknown_option2[] INIT(= N_("E355: Unknown option: %s"));

EXTERN const char top_bot_msg[] INIT(= N_("search hit TOP, continuing at BOTTOM"));
EXTERN const char bot_top_msg[] INIT(= N_("search hit BOTTOM, continuing at TOP"));

EXTERN const char line_msg[] INIT(= N_(" line "));
// uncrustify:on
