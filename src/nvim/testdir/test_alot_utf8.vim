" A series of tests that can run in one Vim invocation.
" This makes testing go faster, since Vim doesn't need to restart.

" These tests use utf8 'encoding'.  Setting 'encoding' is already done in
" runtest.vim.  Checking for the multi_byte feature is in the individual
" files, so that they can be run by themselves.

source test_expr_utf8.vim
source test_matchadd_conceal_utf8.vim
source test_regexp_utf8.vim
source test_source_utf8.vim
source test_utf8.vim
