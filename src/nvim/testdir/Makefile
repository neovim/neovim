#
# Makefile to run all tests for Vim
#

export SHELL := sh

VIMPROG := ../../../build/bin/nvim
SCRIPTSOURCE := ../../../runtime

SCRIPTS := \
           test8.out              \
           test12.out             \
           test13.out             \
           test14.out             \
           test17.out             \
           test24.out             \
           test30.out             \
           test32.out             \
           test37.out             \
           test40.out             \
           test42.out             \
           test47.out             \
           test48.out             \
           test49.out             \
           test52.out             \
           test53.out             \
           test64.out             \
           test69.out             \
           test73.out             \
           test79.out             \
           test_marks.out         \

# Tests using runtest.vim.vim.
# Keep test_alot*.res as the last one, sort the others.
NEW_TESTS = \
	    test_cursor_func.res \
	    test_hardcopy.res \
	    test_help_tagjump.res \
	    test_langmap.res \
	    test_menu.res \
	    test_syntax.res \
	    test_timers.res \
	    test_unlet.res \
	    test_viml.res \
	    test_alot.res

SCRIPTS_GUI := test16.out


ifdef VALGRIND_GDB
	VGDB := --vgdb=yes     \
	        --vgdb-error=0
endif

ifdef USE_VALGRIND
	VALGRIND_TOOL := --tool=memcheck     \
	                 --leak-check=yes    \
	                 --track-origins=yes
#        VALGRIND_TOOL := exp-sgcheck
	TOOL := valgrind -q                                     \
	                 -q                                     \
	                 $(VALGRIND_TOOL)                       \
	                 --suppressions=../../.valgrind.supp \
	                 --error-exitcode=123                   \
	                 --log-file=valgrind.\%p.$*             \
	                 $(VGDB)                                \
	                 --trace-children=yes
else
	ifdef USE_GDB
		TOOL = gdb --args
	endif
endif

ifdef TESTNUM
	SCRIPTS := test$(TESTNUM).out
endif

nongui: nolog $(SCRIPTS) newtests report

gui:    nolog $(SCRIPTS) $(SCRIPTS_GUI) newtests report

.gdbinit:
	echo 'set $$_exitcode = -1\nrun\nif $$_exitcode != -1\n  quit\nend' > .gdbinit

report:
	@echo
	@echo 'Test results:'
	@/bin/sh -c "if test -f test.log; then \
	                 cat test.log;         \
	                 echo TEST FAILURE;    \
	                 exit 1;               \
	             else                      \
	                 echo ALL DONE;        \
	             fi"

test1.out: $(VIMPROG)

$(SCRIPTS) $(SCRIPTS_GUI): $(VIMPROG) test1.out

RM_ON_RUN   := test.out X* viminfo
RM_ON_START := test.ok
RUN_VIM     := VIMRUNTIME=$(SCRIPTSOURCE); export VIMRUNTIME; $(TOOL) $(VIMPROG) -u unix.vim -U NONE -i viminfo --noplugin -s dotest.in

clean:
	-rm -rf *.out          \
	        *.failed       \
	        *.res          \
	        *.rej          \
	        *.orig         \
	        test.log       \
	        messages       \
	        $(RM_ON_RUN)   \
	        $(RM_ON_START) \
	        valgrind.*     \
	        .*.swp         \
	        .*.swo         \
	        del

test1.out: .gdbinit test1.in
	-rm -rf $*.failed $(RM_ON_RUN) $(RM_ON_START) wrongtermsize
	$(RUN_VIM) $*.in
	@/bin/sh -c "if test -e wrongtermsize; then                                 \
	                 echo;                                                      \
	                 echo test1 FAILED - terminal size must be 80x24 or larger; \
	                 echo; exit 1;                                              \
	             elif diff test.out $*.ok; then                                 \
	                 mv -f test.out $*.out;                                     \
	             else                                                           \
	                 echo;                                                      \
	                 echo test1 FAILED - Something basic is wrong;              \
	                 echo;                                                      \
	                 exit 1;                                                    \
	             fi"
	-rm -rf X* viminfo

%.out: %.in .gdbinit
	-rm -rf $*.failed test.ok $(RM_ON_RUN)
	cp $*.ok test.ok
	# Sleep a moment to avoid that the xterm title is messed up.
	# 200 msec is sufficient, but only modern sleep supports a fraction of
	# a second, fall back to a second if it fails.
	@-/bin/sh -c "sleep .2 > /dev/null 2>&1 || sleep 1"
	$(RUN_VIM) $*.in

	# Check if the test.out file matches test.ok.
	@/bin/sh -c "if test -f test.out; then                \
	                 if diff -u test.out $*.ok; then         \
	                     mv -f test.out $*.out;           \
	                 else                                 \
	                     echo $* FAILED >> test.log;      \
	                     mv -f test.out $*.failed;        \
	                 fi;                                  \
	             else                                     \
	                 echo $* NO OUTPUT >>test.log;        \
	             fi"
	@/bin/sh -c "if test -f valgrind; then                \
	                 mv -f valgrind valgrind.$*;          \
	             fi"
	-rm -rf X* test.ok viminfo

test49.out: test49.vim

nolog:
	-rm -f test.log messages


# New style of tests uses Vim script with assert calls.  These are easier
# to write and a lot easier to read and debug.
# Limitation: Only works with the +eval feature.
RUN_VIMTEST = VIMRUNTIME=$(SCRIPTSOURCE); export VIMRUNTIME; $(VALGRIND) $(VIMPROG) -u unix.vim -U NONE --noplugin

newtests: newtestssilent
	@/bin/sh -c "if test -f messages && grep -q 'FAILED' messages; then \
	                 cat messages && cat test.log;                      \
	             fi"

newtestssilent: $(NEW_TESTS)

%.res: %.vim .gdbinit
	$(RUN_VIMTEST) -u NONE -S runtest.vim $*.vim
