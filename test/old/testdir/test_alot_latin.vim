" A series of tests that can run in one Vim invocation.
" This makes testing go faster, since Vim doesn't need to restart.

" These tests use latin1 'encoding'.  Setting 'encoding' is in the individual
" files, so that they can be run by themselves.

source test_regexp_latin.vim
