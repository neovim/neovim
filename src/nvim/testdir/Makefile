# vim: noet ts=8
# Makefile to run all tests for Vim
#

ifeq ($(OS),Windows_NT)
  NVIM_PRG ?= ../../../build/bin/nvim.exe
else
  NVIM_PRG ?= ../../../build/bin/nvim
endif
SCRIPTSOURCE := ../../../runtime

export SHELL := sh
export NVIM_PRG := $(NVIM_PRG)
export TMPDIR := $(abspath ../../../Xtest-tmpdir)

SCRIPTS_DEFAULT = \
           test14.out             \
           test24.out             \
           test37.out             \
           test40.out             \
           test42.out             \
           test48.out             \
           test49.out             \
           test52.out             \
           test53.out             \
           test64.out             \
           test73.out             \
           test79.out             \

ifneq ($(OS),Windows_NT)
  SCRIPTS_DEFAULTS := $(SCRIPTS_DEFAULT) \
           test17.out             \
           test32.out             \

endif

SCRIPTS ?= $(SCRIPTS_DEFAULT)

# Tests using runtest.vim.
# Keep test_alot*.res as the last one, sort the others.
NEW_TESTS ?= \
	    test_arabic.res \
	    test_autocmd.res \
	    test_bufwintabinfo.res \
	    test_changedtick.res \
	    test_charsearch.res \
	    test_cindent.res \
	    test_cmdline.res \
	    test_command_count.res \
	    test_cscope.res \
	    test_digraph.res \
	    test_diffmode.res \
	    test_farsi.res \
	    test_filter_map.res \
	    test_findfile.res \
	    test_fnameescape.res \
	    test_fold.res \
	    test_ga.res \
	    test_glob2regpat.res \
	    test_gf.res \
	    test_gn.res \
	    test_hardcopy.res \
	    test_help_tagjump.res \
	    test_hide.res \
	    test_history.res \
	    test_hlsearch.res \
	    test_increment.res \
	    test_increment_dbcs.res \
	    test_lambda.res \
	    test_langmap.res \
	    test_makeencoding.res \
	    test_marks.res \
	    test_match.res \
	    test_matchadd_conceal.res \
	    test_matchadd_conceal_utf8.res \
	    test_mksession.res \
	    test_mksession_utf8.res \
	    test_nested_function.res \
	    test_normal.res \
	    test_number.res \
	    test_options.res \
	    test_profile.res \
	    test_quickfix.res \
	    test_retab.res \
	    test_search.res \
	    test_signs.res \
	    test_smartindent.res \
	    test_spell.res \
	    test_stat.res \
	    test_startup.res \
	    test_startup_utf8.res \
	    test_substitute.res \
	    test_syntax.res \
	    test_system.res \
	    test_tabpage.res \
	    test_textobjects.res \
	    test_timers.res \
	    test_undo.res \
	    test_usercommands.res \
	    test_vimscript.res \
	    test_visual.res \
	    test_window_id.res \
	    test_writefile.res \
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

test1.out: $(NVIM_PRG)

$(SCRIPTS) $(SCRIPTS_GUI): $(NVIM_PRG) test1.out

RM_ON_RUN   := test.out X* viminfo
RM_ON_START := test.ok
RUN_VIM     := VIMRUNTIME=$(SCRIPTSOURCE); export VIMRUNTIME; $(TOOL) $(NVIM_PRG) -u unix.vim -U NONE -i viminfo --headless --noplugin -s dotest.in

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
	        .gdbinit       \
	        $(TMPDIR)      \
	        del

test1.out: .gdbinit test1.in
	-rm -rf $*.failed $(RM_ON_RUN) $(RM_ON_START) wrongtermsize
	mkdir -p $(TMPDIR)
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
	mkdir -p $(TMPDIR)
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
RUN_VIMTEST = VIMRUNTIME=$(SCRIPTSOURCE); export VIMRUNTIME; $(TOOL) $(NVIM_PRG) -u unix.vim -U NONE --headless --noplugin

newtests: newtestssilent
	@/bin/sh -c "if test -f messages && grep -q 'FAILED' messages; then \
	                 cat messages && cat test.log;                      \
	             fi"

newtestssilent: $(NEW_TESTS)

%.res: %.vim .gdbinit
	mkdir -p $(TMPDIR)
	$(RUN_VIMTEST) -u NONE -S runtest.vim $*.vim
