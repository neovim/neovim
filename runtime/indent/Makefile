# Portable Makefile for running indent tests.

VIM = vim

# Run the tests that didn't run yet or failed previously.
# If a test succeeds a testdir/*.out file will be written.
# If a test fails a testdir/*.fail file will be written.
test:
	$(VIM) --not-a-term -u testdir/runtest.vim


clean:
	$(VIM) --not-a-term -u testdir/cleantest.vim
