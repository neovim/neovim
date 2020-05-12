" A series of tests that can run in one Vim invocation.
" This makes testing go faster, since Vim doesn't need to restart.

" These tests use utf8 'encoding'.  Setting 'encoding' is already done in
" runtest.vim.

source test_charsearch_utf8.vim
source test_expr_utf8.vim
source test_listlbr_utf8.vim
source test_matchadd_conceal_utf8.vim
source test_mksession_utf8.vim
source test_regexp_utf8.vim
source test_source_utf8.vim
source test_startup_utf8.vim
source test_utf8.vim
source test_utf8_comparisons.vim
