# vim: noet ts=8
# Makefile to run all tests for Vim
#

ifeq ($(OS),Windows_NT)
  NVIM_PRG ?= ../../../build/bin/nvim.exe
else
  NVIM_PRG ?= ../../../build/bin/nvim
endif
ROOT := $(abspath ../../..)
BUILD_DIR := $(abspath $(dir $(NVIM_PRG))/..)
NVIM_PRG_ABS := $(abspath $(NVIM_PRG))
CTDIR := $(BUILD_DIR)/oldtests
CTLOG := $(CTDIR)/test.log

export SHELL := sh

SCRIPTS_DEFAULT = \
           test14.out             \
           test24.out             \
           test37.out             \
           test40.out             \
           test42.out             \
           test48.out             \
           test52.out             \
           test64.out             \

ifneq ($(OS),Windows_NT)
  SCRIPTS_DEFAULTS := $(SCRIPTS_DEFAULT) \
           test17.out             \
           test49.out             \

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
	    test_close_count.res \
	    test_cmdline.res \
	    test_command_count.res \
	    test_cscope.res \
	    test_curswant.res \
	    test_digraph.res \
	    test_edit.res \
	    test_erasebackword.res \
	    test_exists.res \
	    test_diffmode.res \
	    test_farsi.res \
	    test_file_size.res \
	    test_filter_map.res \
	    test_find_complete.res \
	    test_fixeol.res \
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
	    test_ins_complete.res \
	    test_lambda.res \
	    test_langmap.res \
	    test_let.res \
	    test_lineending.res \
	    test_listdict.res \
	    test_listchars.res \
	    test_makeencoding.res \
	    test_marks.res \
	    test_match.res \
	    test_matchadd_conceal.res \
	    test_mksession.res \
	    test_nested_function.res \
	    test_normal.res \
	    test_number.res \
	    test_options.res \
	    test_profile.res \
	    test_put.res \
	    test_quickfix.res \
	    test_recover.res \
	    test_retab.res \
	    test_scrollbind.res \
	    test_search.res \
	    test_signs.res \
	    test_smartindent.res \
	    test_spell.res \
	    test_stat.res \
	    test_startup.res \
	    test_substitute.res \
	    test_syntax.res \
	    test_system.res \
	    test_tab.res \
	    test_tabpage.res \
	    test_textobjects.res \
	    test_timers.res \
	    test_undo.res \
	    test_usercommands.res \
	    test_vimscript.res \
	    test_visual.res \
	    test_winbuf_close.res \
	    test_window_id.res \
	    test_writefile.res \
	    test_alot_latin.res \
	    test_alot_utf8.res \
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
	                 --log-file=valgrind-\%p.$*             \
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

nongui: $(SCRIPTS) newtests
	$(MAKE) report

gui: $(SCRIPTS) $(SCRIPTS_GUI) newtests
	$(MAKE) report

.gdbinit:
	@echo "[OLDTEST-PREP] Setting up .gdbinit"
	@echo 'set $$_exitcode = -1\nrun\nif $$_exitcode != -1\n  quit\nend' > .gdbinit

report:
	@echo
	@echo 'Test results:'
	@/bin/sh runnvim.sh --report $(ROOT) $(BUILD_DIR)

test1.out: nolog $(NVIM_PRG)

$(SCRIPTS) $(SCRIPTS_GUI): test1.out

$(NEW_TESTS): test1.out

RM_ON_START := test.ok
RUN_VIM     := $(TOOL) $(NVIM_PRG_ABS) -u unix.vim -U NONE -i viminfo --headless --noplugin -s dotest.in

clean:
	-rm -rf $(CTDIR)

test1.out: .gdbinit test1.in
	@echo "[OLDTEST-PREP] Running test1"
	@/bin/sh runnvim.sh $(ROOT) $(BUILD_DIR) $(NVIM_PRG_ABS) $* \
	  $(RUN_VIM) $*.in
	@! test -e wrongtermsize

%.out: %.in .gdbinit
	@echo "[OLDESTTEST] Running" $*
	@/bin/sh runnvim.sh \
	  --oldesttest $(ROOT) $(BUILD_DIR) $(NVIM_PRG_ABS) $* \
	  $(RUN_VIM) $*.in

test49.out: test49.vim

nolog:
	@echo "[OLDTEST-PREP] Removing test.log"
	@rm -f $(CTLOG)


# New style of tests uses Vim script with assert calls.  These are easier
# to write and a lot easier to read and debug.
# Limitation: Only works with the +eval feature.
RUN_VIMTEST = $(TOOL) $(NVIM_PRG_ABS) -u unix.vim -U NONE --headless --noplugin

newtests: $(NEW_TESTS)

%.res: %.vim .gdbinit
	@echo "[OLDTEST] Running" $*
	@/bin/sh runnvim.sh $(ROOT) $(BUILD_DIR) $(NVIM_PRG_ABS) $* \
	  $(RUN_VIMTEST) -u NONE -S runtest.vim $*.vim
