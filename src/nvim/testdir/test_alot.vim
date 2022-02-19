" A series of tests that can run in one Vim invocation.
" This makes testing go faster, since Vim doesn't need to restart.

source test_backup.vim
source test_behave.vim
source test_cd.vim
source test_changedtick.vim
source test_compiler.vim
source test_cursor_func.vim
source test_cursorline.vim
source test_ex_equal.vim
source test_ex_undo.vim
source test_ex_z.vim
source test_ex_mode.vim
source test_execute_func.vim
source test_expand_func.vim
source test_feedkeys.vim
source test_filter_cmd.vim
source test_filter_map.vim
source test_findfile.vim
source test_float_func.vim
source test_functions.vim
source test_ga.vim
source test_global.vim
source test_goto.vim
source test_join.vim
source test_jumps.vim
source test_fileformat.vim
source test_filetype.vim
source test_filetype_lua.vim
source test_lambda.vim
source test_menu.vim
source test_messages.vim
source test_modeline.vim
source test_move.vim
source test_partial.vim
source test_popup.vim
source test_put.vim
source test_rename.vim
source test_scroll_opt.vim
source test_shift.vim
" Test fails on windows CI when using the MSVC compiler.
" source test_sort.vim
source test_sha256.vim
source test_suspend.vim
source test_syn_attr.vim
source test_tabline.vim
source test_tabpage.vim
source test_tagcase.vim
source test_tagfunc.vim
source test_tagjump.vim
source test_taglist.vim
source test_true_false.vim
source test_unlet.vim
source test_version.vim
source test_virtualedit.vim
source test_window_cmd.vim
source test_wnext.vim
