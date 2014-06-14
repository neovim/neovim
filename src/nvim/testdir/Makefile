#
# Makefile to run all tests for Vim
#

export SHELL := sh

VIMPROG := ../../../build/bin/nvim

SCRIPTS := test_autoformat_join.out                                    \
           test_eval.out                                               \
                       test2.out   test3.out   test4.out   test5.out   \
           test6.out   test7.out   test8.out   test9.out   test10.out  \
           test11.out  test12.out  test13.out  test14.out  test15.out  \
                       test17.out  test18.out  test19.out  test20.out  \
           test21.out  test22.out  test23.out  test24.out  test25.out  \
           test26.out  test27.out  test28.out  test29.out  test30.out  \
           test31.out  test32.out  test33.out  test34.out  test35.out  \
           test36.out  test37.out  test38.out  test39.out  test40.out  \
           test41.out  test42.out  test43.out  test44.out  test45.out  \
           test46.out  test47.out  test48.out  test49.out              \
           test51.out  test52.out  test53.out  test54.out  test55.out  \
           test56.out  test57.out  test58.out  test59.out  test60.out  \
           test61.out  test62.out  test63.out  test64.out  test65.out  \
           test66.out  test67.out  test68.out  test69.out  test70.out  \
           test71.out  test72.out  test73.out  test74.out  test75.out  \
           test76.out  test77.out  test78.out  test79.out  test80.out  \
           test81.out  test82.out  test83.out  test84.out  test85.out  \
           test86.out  test87.out  test88.out  test89.out  test90.out  \
           test91.out  test92.out  test93.out  test94.out  test95.out  \
           test96.out  test97.out  test98.out  test99.out  test100.out \
           test101.out test102.out test103.out test104.out test105.out \
           test106.out

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
	TOOL := valgrind -q                                  \
	                 -q                                  \
	                 $(VALGRIND_TOOL)                    \
	                 --suppressions=../../.valgrind.supp \
	                 --error-exitcode=123                \
	                 --log-file=valgrind.\%p.$*          \
	                 $(VGDB)                             \
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
RM_ON_START := tiny.vim small.vim mbyte.vim mzscheme.vim lua.vim test.ok
RUN_VIM     := $(TOOL) $(VIMPROG) -u unix.vim -U NONE --noplugin -s dotest.in

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
	        .*.swo

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

	# For flaky tests retry one time.
	@/bin/sh -c "if test -f test.out -a $* = test61; then \
	                 if diff test.out $*.ok; then         \
	                     echo flaky test ok first time;   \
	                 else rm -rf $*.failed $(RM_ON_RUN);  \
	                     $(RUN_VIM) $*.in;                \
	                 fi;                                  \
	             fi"

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

test60.out: test60.vim

nolog:
	-rm -f test.log
