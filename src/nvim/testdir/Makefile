#
# Makefile to run all tests for Vim
#

export SHELL := sh

VIMPROG := ../../../build/bin/nvim
SCRIPTSOURCE := ../../../runtime

SCRIPTS := test_eval.out                                               \
                                   test8.out               test10.out  \
           test11.out  test12.out  test13.out  test14.out              \
                       test17.out                                      \
                                               test24.out              \
                                                           test30.out  \
                       test32.out              test34.out              \
           test36.out  test37.out              test39.out  test40.out  \
                       test42.out                          test45.out  \
                       test47.out  test48.out  test49.out              \
                       test52.out  test53.out              test55.out  \
                                               test64.out              \
                                   test68.out  test69.out              \
                                   test73.out                          \
                                               test79.out              \
                                   test83.out                          \
                                   test88.out                          \
           test_listlbr.out                                            \
           test_breakindent.out                                        \
           test_charsearch.out                                         \
           test_close_count.out                                        \
           test_command_count.out                                      \

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
	                 --suppressions=../../../.valgrind.supp \
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

nongui: nolog $(SCRIPTS) report

gui:    nolog $(SCRIPTS) $(SCRIPTS_GUI) report

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
RM_ON_START := tiny.vim small.vim mbyte.vim test.ok
RUN_VIM     := VIMRUNTIME=$(SCRIPTSOURCE); export VIMRUNTIME; $(TOOL) $(VIMPROG) -u unix.vim -U NONE -i viminfo --noplugin -s dotest.in

clean:
	-rm -rf *.out          \
	        *.failed       \
	        *.rej          \
	        *.orig         \
	        test.log       \
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
	                 if diff test.out $*.ok; then         \
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
	-rm -f test.log
