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
	test37.out             \
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
NEW_TESTS_ALOT := test_alot_utf8 test_alot
NEW_TESTS_IN_ALOT := $(shell sed '/^source/ s/^source //;s/\.vim$$//' test_alot*.vim)
# Ignored tests.
# test_alot_latin: Nvim does not allow setting encoding.
# test_arglist: ported to Lua, but kept for easier merging.
# test_autochdir: ported to Lua, but kept for easier merging.
# test_eval_func: used as include in old-style test (test_eval.in).
# test_listlbr: Nvim does not allow setting encoding.
# test_largefile: uses too much resources to run on CI.
NEW_TESTS_IGNORE := $(NEW_TESTS_IN_ALOT) $(NEW_TESTS_ALOT) \
  test_alot_latin \
  test_arglist \
  test_autochdir \
  test_eval_func \
  test_listlbr \
  test_largefile \

NEW_TESTS = $(addsuffix .res,$(sort $(filter-out $(NEW_TESTS_IGNORE),$(basename $(notdir $(wildcard test_*.vim))))) $(NEW_TESTS_ALOT))

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

# Explicit dependencies.
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
