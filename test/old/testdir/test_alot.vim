" A series of tests that can run in one Vim invocation.
" This makes testing go faster, since Vim doesn't need to restart.

source test_backup.vim
source test_compiler.vim
source test_ex_equal.vim
source test_ex_undo.vim
source test_ex_z.vim
source test_ex_mode.vim
source test_expand.vim
source test_expand_func.vim
source test_file_perm.vim
source test_fnamemodify.vim
source test_ga.vim
source test_glob2regpat.vim
source test_global.vim
source test_move.vim
source test_put.vim
source test_reltime.vim
source test_searchpos.vim
source test_set.vim
source test_shift.vim
source test_sha256.vim
source test_tabline.vim
source test_tagcase.vim
source test_tagfunc.vim
source test_unlet.vim
source test_version.vim
source test_wnext.vim

" encoding=utf-8 tests, previously in test_alot_utf8.vim
source test_charsearch_utf8.vim
source test_expr_utf8.vim
source test_mksession_utf8.vim
source test_regexp_utf8.vim
source test_source_utf8.vim
source test_startup_utf8.vim
source test_utf8.vim
source test_utf8_comparisons.vim
