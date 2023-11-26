" Vim syntax file
" Language:	JAM
" Maintainer:	Ralf Lemke (ralflemk@t-online.de)
" Last change:	2012 Jan 08 by Thilo Six

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

setlocal iskeyword=@,48-57,_,-

" A bunch of useful jam keywords
syn keyword	jamStatement	break call dbms flush global include msg parms proc public receive return send unload vars
syn keyword	jamConditional	if else
syn keyword	jamRepeat	for while next step

syn keyword	jamTodo		contained TODO FIXME XXX
syn keyword	jamDBState1	alias binary catquery close close_all_connections column_names connection continue continue_bottom continue_down continue_top continue_up
syn keyword	jamDBState2	     cursor declare engine execute format occur onentry onerror onexit sql start store unique with
syn keyword	jamSQLState1	all alter and any avg between by count create current data database delete distinct drop exists fetch from grant group
syn keyword	jamSQLState2	having index insert into like load max min of open order revoke rollback runstats select set show stop sum synonym table to union update values view where bundle

syn keyword     jamLibFunc1     dm_bin_create_occur dm_bin_delete_occur dm_bin_get_dlength dm_bin_get_occur dm_bin_length dm_bin_max_occur dm_bin_set_dlength dm_convert_empty dm_cursor_connection dm_cursor_consistent dm_cursor_engine dm_dbi_init dm_dbms dm_dbms_noexp dm_disable_styles dm_enable_styles dm_exec_sql dm_expand dm_free_sql_info dm_gen_change_execute_using dm_gen_change_select_from dm_gen_change_select_group_by dm_gen_change_select_having dm_gen_change_select_list dm_gen_change_select_order_by dm_gen_change_select_suffix dm_gen_change_select_where dm_gen_get_tv_alias dm_gen_sql_info

syn keyword     jamLibFunc2     dm_get_db_conn_handle dm_get_db_cursor_handle dm_get_driver_option dm_getdbitext dm_init dm_is_connection dm_is_cursor dm_is_engine dm_odb_preserves_cursor dm_reset dm_set_driver_option dm_set_max_fetches dm_set_max_rows_per_fetch dm_set_tm_clear_fast dm_val_relative sm_adjust_area sm_allget sm_amt_format sm_e_amt_format sm_i_amt_format sm_n_amt_format sm_o_amt_format sm_append_bundle_data sm_append_bundle_done sm_append_bundle_item sm_d_at_cur sm_l_at_cur sm_r_at_cur sm_mw_attach_drawing_func sm_mwn_attach_drawing_func sm_mwe_attach_drawing_func sm_xm_attach_drawing_func sm_xmn_attach_drawing_func sm_xme_attach_drawing_func sm_backtab sm_bel sm_bi_comparesm_bi_copy sm_bi_initialize sm_bkrect sm_c_off sm_c_on sm_c_vis sm_calc sm_cancel sm_ckdigit sm_cl_all_mdts sm_cl_unprot sm_clear_array sm_n_clear_array sm_1clear_array sm_n_1clear_array sm_close_window sm_com_load_picture sm_com_QueryInterface sm_com_result sm_com_result_msg sm_com_set_handler sm_copyarray sm_n_copyarray sm_create_bundle

syn keyword     jamLibFunc3     sm_d_msg_line sm_dblval sm_e_dblval sm_i_dblval sm_n_dblval sm_o_dblval sm_dd_able sm_dde_client_connect_cold sm_dde_client_connect_hot sm_dde_client_connect_warm sm_dde_client_disconnect sm_dde_client_off sm_dde_client_on sm_dde_client_paste_link_cold sm_dde_client_paste_link_hot sm_dde_client_paste_link_warm sm_dde_client_request sm_dde_execute sm_dde_install_notify sm_dde_poke sm_dde_server_off sm_dde_server_on sm_delay_cursor sm_deselect sm_dicname sm_disp_off sm_dlength sm_e_dlength sm_i_dlength sm_n_dlength sm_o_dlength sm_do_uinstalls sm_i_doccur sm_o_doccur sm_drawingarea sm_xm_drawingarea sm_dtofield sm_e_dtofield sm_i_dtofield sm_n_dtofield sm_o_dtofield sm_femsg sm_ferr_reset sm_fi_path sm_file_copy sm_file_exists sm_file_move sm_file_remove sm_fi_open sm_fi_path sm_filebox sm_filetypes sm_fio_a2f sm_fio_close sm_fio_editor sm_fio_error sm_fio_error_set sm_fio_f2a sm_fio_getc sm_fio_gets sm_fio_handle sm_fio_open sm_fio_putc sm_fio_puts sm_fio_rewind sm_flush sm_d_form sm_l_form

syn keyword     jamLibFunc4     sm_r_form sm_formlist sm_fptr sm_e_fptr sm_i_fptr sm_n_fptr sm_o_fptr sm_fqui_msg sm_fquiet_err sm_free_bundle sm_ftog sm_e_ftog sm_i_ftog sm_n_ftog sm_o_ftog sm_fval sm_e_fval sm_i_fval sm_n_fval sm_o_fval sm_i_get_bi_data sm_o_get_bi_data sm_get_bundle_data sm_get_bundle_item_count sm_get_bundle_occur_count sm_get_next_bundle_name sm_i_get_tv_bi_data sm_o_get_tv_bi_data sm_getfield sm_e_getfield sm_i_getfield sm_n_getfield sm_o_getfield sm_getkey sm_gofield sm_e_gofield sm_i_gofield sm_n_gofield sm_o_gofield sm_gtof sm_gval sm_i_gtof sm_n_gval sm_hlp_by_name sm_home sm_inimsg sm_initcrt sm_jinitcrt sm_jxinitcrt sm_input sm_inquire sm_install sm_intval sm_e_intval sm_i_intval sm_n_intval sm_o_intval sm_i_ioccur sm_o_ioccur sm_is_bundle sm_is_no sm_e_is_no sm_i_is_no sm_n_is_no sm_o_is_no sm_is_yes sm_e_is_yes sm_i_is_yes sm_n_is_yes sm_o_is_yes sm_isabort sm_iset sm_issv sm_itofield sm_e_itofield sm_i_itofield sm_n_itofield sm_o_itofield sm_jclose sm_jfilebox sm_jform sm_djplcall sm_jplcall

syn keyword     jamLibFunc5     sm_sjplcall sm_jplpublic sm_jplunload sm_jtop sm_jwindow sm_key_integer sm_keyfilter sm_keyhit sm_keyinit sm_n_keyinit sm_keylabel sm_keyoption sm_l_close sm_l_open sm_l_open_syslib sm_last sm_launch sm_h_ldb_fld_get sm_n_ldb_fld_get sm_h_ldb_n_fld_get sm_n_ldb_n_fld_get sm_h_ldb_fld_store sm_n_ldb_fld_store sm_h_ldb_n_fld_store sm_n_ldb_n_fld_store sm_ldb_get_active sm_ldb_get_inactive sm_ldb_get_next_active sm_ldb_get_next_inactive sm_ldb_getfield sm_i_ldb_getfield sm_n_ldb_getfield sm_o_ldb_getfield sm_ldb_h_getfield sm_i_ldb_h_getfield sm_n_ldb_h_getfield sm_o_ldb_h_getfield sm_ldb_handle sm_ldb_init sm_ldb_is_loaded sm_ldb_load sm_ldb_name sm_ldb_next_handle sm_ldb_pop sm_ldb_push sm_ldb_putfield sm_i_ldb_putfield sm_n_ldb_putfield sm_o_ldb_putfield sm_ldb_h_putfield sm_i_ldb_h_putfield sm_n_ldb_h_putfield sm_o_ldb_h_putfield sm_ldb_state_get sm_ldb_h_state_get sm_ldb_state_set sm_ldb_h_state_set sm_ldb_unload sm_ldb_h_unload sm_leave sm_list_objects_count sm_list_objects_end sm_list_objects_next

syn keyword     jamLibFunc6     sm_list_objects_start sm_lngval sm_e_lngval sm_i_lngval sm_n_lngval sm_o_lngval sm_load_screen sm_log sm_lstore sm_ltofield sm_e_ltofield sm_i_ltofield sm_n_ltofield sm_o_ltofield sm_m_flush sm_menu_bar_error sm_menu_change sm_menu_create sm_menu_delete sm_menu_get_int sm_menu_get_str sm_menu_install sm_menu_remove sm_message_box sm_mncrinit6 sm_mnitem_change sm_n_mnitem_change sm_mnitem_create sm_n_mnitem_create sm_mnitem_delete sm_n_mnitem_delete sm_mnitem_get_int sm_n_mnitem_get_int sm_mnitem_get_str sm_n_mnitem_get_str sm_mnscript_load sm_mnscript_unload sm_ms_inquire sm_msg sm_msg_del sm_msg_get sm_msg_read sm_d_msg_read sm_n_msg_read sm_msgfind sm_mts_CreateInstance sm_mts_CreateProperty sm_mts_CreatePropertyGroup sm_mts_DisableCommit sm_mts_EnableCommit sm_mts_GetPropertyValue sm_mts_IsCallerInRole sm_mts_IsInTransaction sm_mts_IsSecurityEnabled sm_mts_PutPropertyValue sm_mts_SetAbort sm_mts_SetComplete sm_mus_time sm_mw_get_client_wnd sm_mw_get_cmd_show sm_mw_get_frame_wnd sm_mw_get_instance

syn keyword     jamLibFunc7     sm_mw_get_prev_instance sm_mw_PrintScreen sm_next_sync sm_nl sm_null sm_e_null sm_i_null sm_n_null sm_o_null sm_obj_call sm_obj_copy sm_obj_copy_id sm_obj_create sm_obj_delete sm_obj_delete_id sm_obj_get_property sm_obj_onerror sm_obj_set_property sm_obj_sort sm_obj_sort_auto sm_occur_no sm_off_gofield sm_e_off_gofield sm_i_off_gofield sm_n_off_gofield sm_o_off_gofield sm_option sm_optmnu_id sm_pinquire sm_popup_at_cur sm_prop_error sm_prop_get_int sm_prop_get_str sm_prop_get_dbl sm_prop_get_x_int sm_prop_get_x_str sm_prop_get_x_dbl sm_prop_get_m_int sm_prop_get_m_str sm_prop_get_m_dbl sm_prop_id sm_prop_name_to_id sm_prop_set_int sm_prop_set_str sm_prop_set_dbl sm_prop_set_x_int sm_prop_set_x_str sm_prop_set_x_dbl sm_prop_set_m_int sm_prop_set_m_str sm_prop_set_m_dbl sm_pset sm_putfield sm_e_putfield sm_i_putfield sm_n_putfield sm_o_putfield sm_raise_exception sm_receive sm_receive_args sm_rescreen sm_resetcrt sm_jresetcrt sm_jxresetcrt sm_resize sm_restore_data sm_return sm_return_args sm_rmformlist sm_rs_data

syn keyword     jamLibFunc8     sm_rw_error_message sm_rw_play_metafile sm_rw_runreport sm_s_val sm_save_data sm_sdtime sm_select sm_send sm_set_help sm_setbkstat sm_setsibling sm_setstatus sm_sh_off sm_shell sm_shrink_to_fit sm_slib_error sm_slib_install sm_slib_load sm_soption sm_strip_amt_ptr sm_e_strip_amt_ptr sm_i_strip_amt_ptr sm_n_strip_amt_ptr sm_o_strip_amt_ptr sm_sv_data sm_sv_free sm_svscreen sm_tab sm_tm_clear sm_tm_clear_model_events sm_tm_command sm_tm_command_emsgset sm_tm_command_errset sm_tm_continuation_validity sm_tm_dbi_checker sm_tm_error sm_tm_errorlog sm_tm_event sm_tm_event_name sm_tm_failure_message sm_tm_handling sm_tm_inquire sm_tm_iset sm_tm_msg_count_error sm_tm_msg_emsg sm_tm_msg_error sm_tm_old_bi_context sm_tm_pcopy sm_tm_pinquire sm_tm_pop_model_event sm_tm_pset sm_tm_push_model_event sm_tmpnam sm_tp_exec sm_tp_free_arg_buf sm_tp_gen_insert sm_tp_gen_sel_return sm_tp_gen_sel_where sm_tp_gen_val_link sm_tp_gen_val_return sm_tp_get_svc_alias sm_tp_get_tux_callid sm_translatecoords sm_tst_all_mdts

syn keyword     jamLibFunc9     sm_udtime sm_ungetkey sm_unload_screen sm_unsvscreen sm_upd_select sm_validate sm_n_validate sm_vinit sm_n_vinit sm_wcount sm_wdeselect sm_web_get_cookie sm_web_invoke_url sm_web_log_error sm_web_save_global sm_web_set_cookie sm_web_unsave_all_globals sm_web_unsave_global sm_mw_widget sm_mwe_widget sm_mwn_widget sm_xm_widget sm_xme_widget sm_xmn_widget sm_win_shrink sm_d_window sm_d_at_cur sm_l_window sm_l_at_cur sm_r_window sm_r_at_cur sm_winsize sm_wrotate sm_wselect sm_n_wselect sm_ww_length sm_n_ww_length sm_ww_read sm_n_ww_read sm_ww_write sm_n_ww_write sm_xlate_table sm_xm_get_base_window sm_xm_get_display

syn keyword     jamVariable1    SM_SCCS_ID SM_ENTERTERM SM_MALLOC SM_CANCEL SM_BADTERM SM_FNUM SM_DZERO SM_EXPONENT SM_INVDATE SM_MATHERR SM_FRMDATA SM_NOFORM SM_FRMERR SM_BADKEY SM_DUPKEY SM_ERROR SM_SP1 SM_SP2 SM_RENTRY SM_MUSTFILL SM_AFOVRFLW SM_TOO_FEW_DIGITS  SM_CKDIGIT SM_HITANY SM_NOHELP SM_MAXHELP SM_OUTRANGE SM_ENTERTERM1 SM_SYSDATE SM_DATFRM SM_DATCLR SM_DATINV SM_KSDATA SM_KSERR SM_KSNONE SM_KSMORE SM_DAYA1 SM_DAYA2 SM_DAYA3 SM_DAYA4 SM_DAYA5 SM_DAYA6 SM_DAYA7 SM_DAYL1 SM_DAYL2 SM_DAYL3 SM_DAYL4 SM_DAYL5 SM_DAYL6 SM_DAYL7 SM_MNSCR_LOAD SM_MENU_INSTALL SM_INSTDEFSCRL SM_INSTSCROLL SM_MOREDATA SM_READY SM_WAIT SM_YES SM_NO SM_NOTEMP SM_FRMHELP SM_FILVER SM_ONLYONE SM_WMSMOVE SM_WMSSIZE SM_WMSOFF SM_LPRINT SM_FMODE SM_NOFILE SM_NOSECTN SM_FFORMAT SM_FREAD SM_RX1 SM_RX2 SM_RX3 SM_TABLOOK SM_MISKET SM_ILLKET SM_ILLBRA SM_MISDBLKET SM_ILLDBLKET SM_ILLDBLBRA SM_ILL_RIGHT SM_ILLELSE SM_NUMBER SM_EOT SM_BREAK SM_NOARGS SM_BIGVAR SM_EXCESS SM_EOL SM_FILEIO SM_FOR SM_RCURLY SM_NONAME SM_1JPL_ERR SM_2JPL_ERR SM_3JPL_ERR

syn keyword     jamVariable2    SM_JPLATCH SM_FORMAT SM_DESTINATION SM_ORAND SM_ORATOR SM_ILL_LEFT SM_MISSPARENS SM_ILLCLOSE_COMM SM_FUNCTION SM_EQUALS SM_MISMATCH SM_QUOTE SM_SYNTAX SM_NEXT SM_VERB_UNKNOWN SM_JPLFORM SM_NOT_LOADED SM_GA_FLG SM_GA_CHAR SM_GA_ARG SM_GA_DIG SM_NOFUNC SM_BADPROTO SM_JPLPUBLIC SM_NOCOMPILE SM_NULLEDIT SM_RP_NULL SM_DBI_NOT_INST SM_NOTJY SM_MAXLIB SM_FL_FLLIB SM_TPI_NOT_INST SM_RW_NOT_INST SM_MONA1 SM_MONA2 SM_MONA3 SM_MONA4 SM_MONA5 SM_MONA6 SM_MONA7 SM_MONA8 SM_MONA9 SM_MONA10 SM_MONA11 SM_MONA12 SM_MONL1 SM_MONL2 SM_MONL3 SM_MONL4 SM_MONL5 SM_MONL6 SM_MONL7 SM_MONL8 SM_MONL9 SM_MONL10 SM_MONL11 SM_MONL12 SM_AM SM_PM SM_0DEF_DTIME SM_1DEF_DTIME SM_2DEF_DTIME SM_3DEF_DTIME SM_4DEF_DTIME SM_5DEF_DTIME SM_6DEF_DTIME SM_7DEF_DTIME SM_8DEF_DTIME SM_9DEF_DTIME SM_CALC_DATE SM_BAD_DIGIT SM_BAD_YN SM_BAD_ALPHA SM_BAD_NUM SM_BAD_ALPHNUM SM_DECIMAL SM_1STATS SM_VERNO SM_DIG_ERR SM_YN_ERR SM_LET_ERR SM_NUM_ERR SM_ANUM_ERR SM_REXP_ERR SM_POSN_ERR SM_FBX_OPEN SM_FBX_WINDOW SM_FBX_SIBLING SM_OPENDIR

syn keyword     jamVariable3    SM_GETFILES SM_CHDIR SM_GETCWD SM_UNCLOSED_COMM SM_MB_OKLABEL SM_MB_CANCELLABEL SM_MB_YESLABEL SM_MB_NOLABEL SM_MB_RETRYLABEL SM_MB_IGNORELABEL SM_MB_ABORTLABEL SM_MB_HELPLABEL SM_MB_STOP SM_MB_QUESTION SM_MB_WARNING SM_MB_INFORMATION SM_MB_YESALLLABEL SM_0MN_CURRDEF SM_1MN_CURRDEF SM_2MN_CURRDEF SM_0DEF_CURR SM_1DEF_CURR SM_2DEF_CURR SM_3DEF_CURR SM_4DEF_CURR SM_5DEF_CURR SM_6DEF_CURR SM_7DEF_CURR SM_8DEF_CURR SM_9DEF_CURR SM_SEND_SYNTAX SM_SEND_ITEM SM_SEND_INVALID_BUNDLE SM_RECEIVE_SYNTAX SM_RECEIVE_ITEM_NUMBER SM_RECEIVE_OVERFLOW SM_RECEIVE_ITEM SM_SYNCH_RECEIVE SM_EXEC_FAIL SM_DYNA_HELP_NOT_AVAIL SM_DLL_LOAD_ERR SM_DLL_UNRESOLVED SM_DLL_VERSION_ERR SM_DLL_OPTION_ERR SM_DEMOERR SM_MB_OKALLLABEL SM_MB_NOALLLABEL SM_BADPROP SM_BETWEEN SM_ATLEAST SM_ATMOST SM_PR_ERROR SM_PR_OBJID SM_PR_OBJECT SM_PR_ITEM SM_PR_PROP SM_PR_PROP_ITEM SM_PR_PROP_VAL SM_PR_CONVERT SM_PR_OBJ_TYPE SM_PR_RANGE SM_PR_NO_SET SM_PR_BYND_SCRN SM_PR_WW_SCROLL SM_PR_NO_SYNC SM_PR_TOO_BIG SM_PR_BAD_MASK SM_EXEC_MEM_ERR

syn keyword     jamVariable4    SM_EXEC_NO_PROG SM_PR_NO_KEYSTRUCT SM_REOPEN_AS_SLIB SM_REOPEN_THE_SLIB SM_ERRLIB SM_WARNLIB SM_LIB_DOWNGRADE SM_OLDER SM_NEWER SM_UPGRADE SM_LIB_READONLY SM_LOPEN_ERR SM_LOPEN_WARN SM_MLOPEN_CREAT SM_MLOPEN_INIT SM_LIB_ERR SM_LIB_ISOLATE SM_LIB_NO_ERR SM_LIB_REC_ERR SM_LIB_FATAL_ERR SM_LIB_LERR_FILE SM_LIB_LERR_NOTLIB SM_LIB_LERR_BADVERS SM_LIB_LERR_FORMAT SM_LIB_LERR_BADCM SM_LIB_LERR_LOCK SM_LIB_LERR_RESERVED SM_LIB_LERR_READONLY SM_LIB_LERR_NOENTRY SM_LIB_LERR_BUSY SM_LIB_LERR_ROVERS SM_LIB_LERR_DEFAULT SM_LIB_BADCM SM_LIB_LERR_NEW SM_STANDALONE_MODE SM_FEATURE_RESTRICT FM_CH_LOST FM_JPL_PROMPT FM_YR4 FM_YR2 FM_MON FM_MON2 FM_DATE FM_DATE2 FM_HOUR FM_HOUR2 FM_MIN FM_MIN2 FM_SEC FM_SEC2 FM_YRDAY FM_AMPM FM_DAYA FM_DAYL FM_MONA FM_MONL FM_0MN_DEF_DT FM_1MN_DEF_DT FM_2MN_DEF_DT FM_DAY JM_QTERMINATE JM_HITSPACE JM_HITACK JM_NOJWIN UT_MEMERR UT_P_OPT UT_V_OPT UT_E_BINOPT UT_NO_INPUT UT_SECLONG UT_1FNAME UT_SLINE UT_FILE UT_ERROR UT_WARNING UT_MISSEQ UT_VOPT UT_M2_DESCR

syn keyword     jamVariable5    UT_M2_PROGNAME UT_M2_USAGE UT_M2_O_OPT UT_M2_COM UT_M2_BADTAG UT_M2_MSSQUOT UT_M2_AFTRQUOT UT_M2_DUPSECT UT_M2_BADUCLSS UT_M2_USECPRFX UT_M2_MPTYUSCT UT_M2_DUPMSGTG UT_M2_TOOLONG UT_M2_LONG UT_K2_DESCR UT_K2_PROGNAME UT_K2_USAGE UT_K2_MNEM UT_K2_NKEYDEF UT_K2_DUPKEY UT_K2_NOTFOUND UT_K2_1FNAME UT_K2_VOPT UT_K2_EXCHAR UT_V2_DESCR UT_V2_PROGNAME UT_V2_USAGE UT_V2_SLINE UT_V2_SEQUAL UT_V2_SVARNAME UT_V2_SNAME UT_V2_VOPT UT_V2_1REQ UT_CB_DESCR UT_CB_PROGNAME UT_CB_USAGE UT_CB_VOPT UT_CB_MIEXT UT_CB_AEXT UT_CB_UNKNOWN UT_CB_ISCHEME UT_CB_BKFGS UT_CB_ABGS UT_CB_REC UT_CB_GUI UT_CB_CONT UT_CB_CONTFG UT_CB_AFILE UT_CB_LEFT_QUOTE UT_CB_NO_EQUAL UT_CB_EXTRA_EQ UT_CB_BAD_LHS UT_CB_BAD_RHS UT_CB_BAD_QUOTED UT_CB_FILE UT_CB_FILE_LINE UT_CB_DUP_ALIAS UT_CB_LINE_LOOP UT_CB_BAD_STYLE UT_CB_DUP_STYLE UT_CB_NO_SECT UT_CB_DUP_SCHEME DM_ERROR DM_NODATABASE DM_NOTLOGGEDON DM_ALREADY_ON DM_ARGS_NEEDED DM_LOGON_DENIED DM_BAD_ARGS DM_BAD_CMD DM_NO_MORE_ROWS DM_ABORTED DM_NO_CURSOR DM_MANY_CURSORS DM_KEYWORD

syn keyword     jamVariable6    DM_INVALID_DATE DM_COMMIT DM_ROLLBACK DM_PARSE_ERROR DM_BIND_COUNT DM_BIND_VAR DM_DESC_COL DM_FETCH DM_NO_NAME DM_END_OF_PROC DM_NOCONNECTION DM_NOTSUPPORTED DM_TRAN_PEND DM_NO_TRANSACTION DM_ALREADY_INIT DM_INIT_ERROR DM_MAX_DEPTH DM_NO_PARENT DM_NO_CHILD DM_MODALITY_NOT_FOUND DM_NATIVE_NO_SUPPORT DM_NATIVE_CANCEL DM_TM_ALREADY DM_TM_IN_PROGRESS DM_TM_CLOSE_ERROR DM_TM_BAD_MODE DM_TM_BAD_CLOSE_ACTION DM_TM_INTERNAL DM_TM_MODEL_INTERNAL DM_TM_NO_ROOT DM_TM_NO_TRANSACTION DM_TM_INITIAL_MODE DM_TM_PARENT_NAME DM_TM_BAD_MEMBER DM_TM_FLD_NAM_LEN DM_TM_NO_PARENT DM_TM_BAD_REQUEST DM_TM_CANNOT_GEN_SQL DM_TM_CANNOT_EXEC_SQL DM_TM_DBI_ERROR DM_TM_DISCARD_ALL DM_TM_DISCARD_LATEST DM_TM_CALL_ERROR DM_TM_CALL_TYPE DM_TM_HOOK_MODEL DM_TM_ROOT_NAME DM_TM_TV_INVALID DM_TM_COL_NOT_FOUND DM_TM_BAD_LINK DM_TM_HOOK_MODEL_ERROR DM_TM_ONE_ROW DM_TM_SOME_ROWS DM_TM_GENERAL DM_TM_NO_HOOK DM_TM_NOSET DM_TM_TBLNAME DM_TM_PRIMARY_KEY DM_TM_INCOMPLETE_KEY DM_TM_CMD_MODE DM_TM_NO_SUCH_CMD DM_TM_NO_SUCH_SCOPE

syn keyword     jamVariable7    DM_TM_NO_SUCH_TV DM_TM_EVENT_LOOP DM_TM_UNSUPPORTED DM_TM_NO_MODEL DM_TM_SYNCH_SV DM_TM_WRONG_FORM  DM_TM_VC_FIELD DM_TM_VC_DATE DM_TM_VC_TYPE DM_TM_BAD_CONTINUE DM_JDB_OUT_OF_MEMORY DM_JDB_DUPTABLEALIAS DM_JDB_DUPCURSORNAME DM_JDB_NODB DM_JDB_BINDCOUNT DM_JDB_NO_MORE_ROWS DM_JDB_AMBIGUOUS_COLUMN_REF DM_JDB_UNRESOLVED_COLUMN_REF DM_JDB_TABLE_READ_WRITE_CONFLICT DM_JDB_SYNTAX_ERROR DM_JDB_DUP_COLUMN_ASSIGNMENT DM_JDB_NO_MSG_FILE DM_JDB_NO_MSG DM_JDB_NOT_IMPLEMENTED DM_JDB_AGGREGATE_NOT_ALLOWED DM_JDB_TYPE_MISMATCH DM_JDB_NO_CURRENT_ROW DM_JDB_DB_CORRUPT DM_JDB_BUF_OVERFLOW DM_JDB_FILE_IO_ERR DM_JDB_BAD_HANDLE DM_JDB_DUP_TNAME DM_JDB_INVALID_TABLE_OP DM_JDB_TABLE_NOT_FOUND DM_JDB_CONVERSION_FAILED DM_JDB_INVALID_COLUMN_LIST DM_JDB_TABLE_OPEN DM_JDB_BAD_INPUT DM_JDB_DATATYPE_OVERFLOW DM_JDB_DATABASE_EXISTS DM_JDB_DATABASE_OPEN DM_JDB_DUP_CNAME DM_JDB_TMPDATABASE_ERR DM_JDB_INVALID_VALUES_COUNT DM_JDB_INVALID_COLUMN_COUNT DM_JDB_MAX_RECLEN_EXCEEDED DM_JDB_END_OF_GROUP

syn keyword     jamVariable8    TP_EXC_INVALID_CLIENT_COMMAND  TP_EXC_INVALID_CLIENT_OPTION  TP_EXC_INVALID_COMMAND TP_EXC_INVALID_COMMAND_SYNTAX TP_EXC_INVALID_CONNECTION TP_EXC_INVALID_CONTEXT TP_EXC_INVALID_FORWARD TP_EXC_INVALID_JAM_VARIABLE_REF  TP_EXC_INVALID_MONITOR_COMMAND TP_EXC_INVALID_MONITOR_OPTION TP_EXC_INVALID_OPTION TP_EXC_INVALID_OPTION_VALUE  TP_EXC_INVALID_SERVER_COMMAND TP_EXC_INVALID_SERVER_OPTION TP_EXC_INVALID_SERVICE TP_EXC_INVALID_TRANSACTION TP_EXC_JIF_ACCESS_FAILED TP_EXC_JIF_LOWER_VERSION TP_EXC_LOGFILE_ERROR TP_EXC_MONITOR_ERROR TP_EXC_NO_OUTSIDE_TRANSACTION TP_EXC_NO_OUTSTANDING_CALLS TP_EXC_NO_OUTSTANDING_MESSAGE TP_EXC_NO_SERVICES_ADVERTISED TP_EXC_NO_SIGNALS TP_EXC_NONTRANSACTIONAL_SERVICE TP_EXC_NONTRANSACTIONAL_ACTION TP_EXC_OUT_OF_MEMORY TP_EXC_POSTING_FAILED TP_EXC_PERMISSION_DENIED  TP_EXC_REQUEST_LIMIT TP_EXC_ROLLBACK_COMMITTED  TP_EXC_ROLLBACK_FAILED TP_EXC_SERVICE_FAILED TP_EXC_SERVICE_NOT_IN_JIF  TP_EXC_SERVICE_PROTOCOL_ERROR  TP_EXC_SUBSCRIPTION_LIMIT

syn keyword     jamVariable9    TP_EXC_SUBSCRIPTION_MATCH TP_EXC_SVC_ADVERTISE_LIMIT TP_EXC_SVC_WORK_OUTSTANDING TP_EXC_SVCROUTINE_MISSING TP_EXC_SVRINIT_WORK_OUTSTANDING TP_EXC_TIMEOUT TP_EXC_TRANSACTION_LIMIT TP_EXC_UNLOAD_FAILED TP_EXC_UNSUPPORTED_BUFFER TP_EXC_UNSUPPORTED_BUF_W_SUBT TP_EXC_USER_ABORT TP_EXC_WORK_OUTSTANDING TP_EXC_XA_CLOSE_FAILED TP_EXC_XA_OPEN_FAILED TP_EXC_QUEUE_BAD_MSGID TP_EXC_QUEUE_BAD_NAMESPACE TP_EXC_QUEUE_BAD_QUEUE TP_EXC_QUEUE_CANT_START_TRAN TP_EXC_QUEUE_FULL TP_EXC_QUEUE_MSG_IN_USE TP_EXC_QUEUE_NO_MSG TP_EXC_QUEUE_NOT_IN_QSPACE TP_EXC_QUEUE_RSRC_NOT_OPEN TP_EXC_QUEUE_SPACE_NOT_IN_JIF TP_EXC_QUEUE_TRAN_ABORTED TP_EXC_QUEUE_TRAN_ABSENT TP_EXC_QUEUE_UNEXPECTED TP_EXC_DCE_LOGIN_REQUIRED TP_EXC_ENC_CELL_NAME_REQUIRED TP_EXC_ENC_CONN_INFO_DIFFS TP_EXC_ENC_SVC_REGISTRY_ERROR TP_INVALID_START_ROUTINE TP_JIF_NOT_FOUND TP_JIF_OPEN_ERROR TP_NO_JIF TP_NO_MONITORS_ERROR TP_NO_SESSIONS_ERROR TP_NO_START_ROUTINE TP_ADV_SERVICE TP_ADV_SERVICE_IN_GROUP  TP_PRE_SVCHDL_WINOPEN_FAILED

syn keyword     jamVariable10   PV_YES PV_NO TRUE FALSE TM_TRAN_NAME

" jamCommentGroup allows adding matches for special things in comments
syn cluster	jamCommentGroup	contains=jamTodo

" String and Character constants
" Highlight special characters (those which have a backslash) differently
syn match	jamSpecial	contained "\\\(x\x\+\|\o\{1,3}\|.\|$\)"
if !exists("c_no_utf")
  syn match	jamSpecial	contained "\\\(u\x\{4}\|U\x\{8}\)"
endif
if exists("c_no_cformat")
  syn region	jamString		start=+L\="+ skip=+\\\\\|\\"+ end=+"+ contains=cSpecial
else
  syn match	jamFormat		"%\(\d\+\$\)\=[-+' #0*]*\(\d*\|\*\|\*\d\+\$\)\(\.\(\d*\|\*\|\*\d\+\$\)\)\=\([hlL]\|ll\)\=\([diuoxXfeEgGcCsSpn]\|\[\^\=.[^]]*\]\)" contained
  syn match	jamFormat		"%%" contained
  syn region	jamString		start=+L\="+ skip=+\\\\\|\\"+ end=+"+ contains=cSpecial,cFormat
  hi link jamFormat jamSpecial
endif
syn match	jamCharacter	"L\='[^\\]'"
syn match	jamCharacter	"L'[^']*'" contains=jamSpecial
syn match	jamSpecialError	"L\='\\[^'\"?\\abfnrtv]'"
syn match	jamSpecialCharacter "L\='\\['\"?\\abfnrtv]'"
syn match	jamSpecialCharacter "L\='\\\o\{1,3}'"
syn match	jamSpecialCharacter "'\\x\x\{1,2}'"
syn match	jamSpecialCharacter "L'\\x\x\+'"

"catch errors caused by wrong parenthesis and brackets
syn cluster	jamParenGroup	contains=jamParenError,jamIncluded,jamSpecial,@jamCommentGroup,jamUserCont,jamUserLabel,jamBitField,jamCommentSkip,jamOctalZero,jamCppOut,jamCppOut2,jamCppSkip,jamFormat,jamNumber,jamFloat,jamOctal,jamOctalError,jamNumbersCom

syn region	jamParen		transparent start='(' end=')' contains=ALLBUT,@jamParenGroup,jamErrInBracket
syn match	jamParenError	"[\])]"
syn match	jamErrInParen	contained "[\]{}]"
syn region	jamBracket	transparent start='\[' end=']' contains=ALLBUT,@jamParenGroup,jamErrInParen
syn match	jamErrInBracket	contained "[);{}]"

"integer number, or floating point number without a dot and with "f".
syn case ignore
syn match	jamNumbers	transparent "\<\d\|\,\d" contains=jamNumber,jamFloat,jamOctalError,jamOctal
" Same, but without octal error (for comments)
syn match	jamNumbersCom	contained transparent "\<\d\|\,\d" contains=jamNumber,jamFloat,jamOctal
syn match	jamNumber		contained "\d\+\(u\=l\{0,2}\|ll\=u\)\>"
"hex number
syn match	jamNumber		contained "0x\x\+\(u\=l\{0,2}\|ll\=u\)\>"
" Flag the first zero of an octal number as something special
syn match	jamOctal		contained "0\o\+\(u\=l\{0,2}\|ll\=u\)\>" contains=cOctalZero
syn match	jamOctalZero	contained "\<0"
syn match	jamFloat		contained "\d\+f"
"floating point number, with dot, optional exponent
syn match	jamFloat		contained "\d\+\,\d*\(e[-+]\=\d\+\)\=[fl]\="
"floating point number, starting with a dot, optional exponent
syn match	jamFloat		contained "\,\d\+\(e[-+]\=\d\+\)\=[fl]\=\>"
"floating point number, without dot, with exponent
syn match	jamFloat		contained "\d\+e[-+]\=\d\+[fl]\=\>"
" flag an octal number with wrong digits
syn match	jamOctalError	contained "0\o*[89]\d*"
syn case match

syntax match	jamOperator1	"\#\#"
syntax match	jamOperator6	"/"
syntax match	jamOperator2	"+"
syntax match	jamOperator3	"*"
syntax match	jamOperator4	"-"
syntax match	jamOperator5	"|"
syntax match	jamOperator6	"/"
syntax match	jamOperator7	"&"
syntax match	jamOperator8	":"
syntax match	jamOperator9	"<"
syntax match	jamOperator10	">"
syntax match	jamOperator11	"!"
syntax match	jamOperator12	"%"
syntax match	jamOperator13	"^"
syntax match	jamOperator14	"@"

syntax match	jamCommentL	"//"

if exists("jam_comment_strings")
  " A comment can contain jamString, jamCharacter and jamNumber.
  " But a "*/" inside a jamString in a jamComment DOES end the comment!  So we
  " need to use a special type of jamString: jamCommentString, which also ends on
  " "*/", and sees a "*" at the start of the line as comment again.
  " Unfortunately this doesn't very well work for // type of comments :-(
  syntax match	jamCommentSkip	contained "^\s*\*\($\|\s\+\)"
  syntax region jamCommentString	contained start=+L\="+ skip=+\\\\\|\\"+ end=+"+ end=+\*/+me=s-1 contains=jamSpecial,jamCommentSkip
  syntax region jamComment2String	contained start=+L\="+ skip=+\\\\\|\\"+ end=+"+ end="$" contains=jamSpecial
  syntax region  jamCommentL	start="//" skip="\\$" end="$" keepend contains=@jamCommentGroup,jamComment2String,jamCharacter,jamNumbersCom,jamSpaceError
  syntax region  jamCommentL2		  start="^#\|^\s\+\#" skip="\\$" end="$" keepend contains=@jamCommentGroup,jamComment2String,jamCharacter,jamNumbersCom,jamSpaceError
  syntax region jamComment	start="/\*" end="\*/" contains=@jamCommentGroup,jamCommentString,jamCharacter,jamNumbersCom,jamSpaceError
else
  syn region	jamCommentL	start="//" skip="\\$" end="$" keepend contains=@jamCommentGroup,jamSpaceError
  syn region	jamCommentL2      start="^\#\|^\s\+\#" skip="\\$" end="$" keepend contains=@jamCommentGroup,jamSpaceError
  syn region	jamComment	start="/\*" end="\*/" contains=@jamCommentGroup,jamSpaceError
endif

" keep a // comment separately, it terminates a preproc. conditional
syntax match	jamCommentError	"\*/"

syntax match    jamOperator3Error   "*/"

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link jamCommentL		jamComment
hi def link jamCommentL2		jamComment
hi def link jamOperator3Error	jamError
hi def link jamConditional	Conditional
hi def link jamRepeat		Repeat
hi def link jamCharacter		Character
hi def link jamSpecialCharacter	jamSpecial
hi def link jamNumber		Number
hi def link jamParenError	jamError
hi def link jamErrInParen	jamError
hi def link jamErrInBracket	jamError
hi def link jamCommentError	jamError
hi def link jamSpaceError	jamError
hi def link jamSpecialError	jamError
hi def link jamOperator1		jamOperator
hi def link jamOperator2		jamOperator
hi def link jamOperator3		jamOperator
hi def link jamOperator4		jamOperator
hi def link jamOperator5		jamOperator
hi def link jamOperator6		jamOperator
hi def link jamOperator7		jamOperator
hi def link jamOperator8		jamOperator
hi def link jamOperator9		jamOperator
hi def link jamOperator10	jamOperator
hi def link jamOperator11	jamOperator
hi def link jamOperator12	jamOperator
hi def link jamOperator13	jamOperator
hi def link jamOperator14	jamOperator
hi def link jamError		Error
hi def link jamStatement		Statement
hi def link jamPreCondit		PreCondit
hi def link jamCommentError	jamError
hi def link jamCommentString	jamString
hi def link jamComment2String	jamString
hi def link jamCommentSkip	jamComment
hi def link jamString		String
hi def link jamComment		Comment
hi def link jamSpecial		SpecialChar
hi def link jamTodo		Todo
hi def link jamCppSkip		jamCppOut
hi def link jamCppOut2		jamCppOut
hi def link jamCppOut		Comment
hi def link jamDBState1		Identifier
hi def link jamDBState2		Identifier
hi def link jamSQLState1		jamSQL
hi def link jamSQLState2		jamSQL
hi def link jamLibFunc1		jamLibFunc
hi def link jamLibFunc2		jamLibFunc
hi def link jamLibFunc3		jamLibFunc
hi def link jamLibFunc4		jamLibFunc
hi def link jamLibFunc5		jamLibFunc
hi def link jamLibFunc6		jamLibFunc
hi def link jamLibFunc7		jamLibFunc
hi def link jamLibFunc8		jamLibFunc
hi def link jamLibFunc9		jamLibFunc
hi def link jamVariable1		jamVariablen
hi def link jamVariable2		jamVariablen
hi def link jamVariable3		jamVariablen
hi def link jamVariable4		jamVariablen
hi def link jamVariable5		jamVariablen
hi def link jamVariable6		jamVariablen
hi def link jamVariable7		jamVariablen
hi def link jamVariable8		jamVariablen
hi def link jamVariable9		jamVariablen
hi def link jamVariable10	jamVariablen
hi def link jamVariablen		Constant
hi def link jamSQL		Type
hi def link jamLibFunc		PreProc
hi def link jamOperator		Special


let b:current_syntax = "jam"

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: ts=8
