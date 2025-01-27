# vim: noet ts=8
# Makefile to run all tests for Vim
#

ifeq ($(OS),Windows_NT)
  NVIM_PRG ?= ../../../build/bin/nvim.exe
else
  NVIM_PRG ?= ../../../build/bin/nvim
endif
ROOT := ../../..

export SHELL := sh
export NVIM_PRG := $(NVIM_PRG)
export TMPDIR := $(abspath X-test-tmpdir)

ifeq ($(OS),Windows_NT)
  FIXFF = fixff
else
  FIXFF =
endif

# Tests using runtest.vim.
NEW_TESTS_ALOT := test_alot_utf8 test_alot test_alot_latin
NEW_TESTS_IN_ALOT := $(shell sed -n '/^source/ s/^source //; s/\.vim$$//p' $(addsuffix .vim,$(NEW_TESTS_ALOT)))
# Ignored tests.
# test_largefile: uses too much resources to run on CI.
NEW_TESTS_IGNORE := \
  test_largefile \

NEW_TESTS := $(sort $(basename $(notdir $(wildcard test_*.vim))))
NEW_TESTS_RES := $(addsuffix .res,$(filter-out $(NEW_TESTS_ALOT) $(NEW_TESTS_IN_ALOT) $(NEW_TESTS_IGNORE),$(NEW_TESTS)) $(NEW_TESTS_ALOT))


ifdef VALGRIND_GDB
	VGDB := --vgdb=yes     \
	        --vgdb-error=0
endif

ifdef USE_VALGRIND
	VALGRIND_TOOL := --tool=memcheck     \
	                 --leak-check=yes    \
	                 --track-origins=yes
#        VALGRIND_TOOL := exp-sgcheck
	TOOL := valgrind -q                                         \
	                 -q                                         \
	                 $(VALGRIND_TOOL)                           \
	                 --suppressions=../../../src/.valgrind.supp \
	                 --error-exitcode=123                       \
	                 --log-file=valgrind-\%p.$*                 \
	                 $(VGDB)                                    \
	                 --trace-children=yes
else
	ifdef USE_GDB
		TOOL = gdb --args
	endif
endif

default: nongui

nongui: nolog $(FIXFF) newtests report

.gdbinit:
	@echo "[OLDTEST-PREP] Setting up .gdbinit"
	@echo 'set $$_exitcode = -1\nrun\nif $$_exitcode != -1\n  quit\nend' > .gdbinit

report:
	$(NVIM_PRG) -u NONE $(NO_INITS) -S summarize.vim messages
	@echo
	@echo 'Test results:'
	@cat test_result.log
	@/bin/sh -c "if test -f test.log; \
		then echo TEST FAILURE; exit 1; \
		else echo ALL DONE; \
		fi"
	@rm -f starttime

test1.out: $(NVIM_PRG)

NO_PLUGINS = --noplugin --headless
# In vim, if the -u command line option is specified, compatible is turned on
# and viminfo is not read. Unlike vim, neovim reads viminfo and requires the
# -i command line option.
NO_INITS = -U NONE -i NONE $(NO_PLUGINS)

# TODO: find a way to avoid changing the distributed files.
fixff:
	-$(NVIM_PRG) $(NO_INITS) -u unix.vim "+argdo set ff=dos|upd" +q \
	  *.in *.ok
	-$(NVIM_PRG) $(NO_INITS) -u unix.vim "+argdo set ff=dos|upd" +q \
	  dotest.in

# File to delete when testing starts
CLEANUP_FILES = test.log messages starttime

# Execute an individual new style test, e.g.:
# 	make test_largefile
$(NEW_TESTS):
	rm -f $@.res $(CLEANUP_FILES)
	@MAKEFLAGS=--no-print-directory $(MAKE) -f Makefile $@.res
	@cat messages
	@if test -f test.log; then \
		exit 1; \
	fi

RM_ON_RUN   := test.out X* viminfo
RM_ON_START := test.ok
RUN_VIM     := $(TOOL) $(NVIM_PRG) -u unix.vim -U NONE -i viminfo --headless --noplugin -s dotest.in

# Delete files that may interfere with running tests.  This includes some files
# that may result from working on the tests, not only from running them.
CLEAN_FILES := *.out \
  *.failed          \
  *.res             \
  *.rej             \
  *.orig            \
  *.tlog            \
  opt_test.vim      \
  test_result.log   \
  $(CLEANUP_FILES)  \
  $(RM_ON_RUN)      \
  $(RM_ON_START)    \
  valgrind.*        \
  .*.swp            \
  .*.swo            \
  .gdbinit          \
  $(TMPDIR)         \
  del               \
  $(ROOT)/runtime/doc/.*.swp
clean:
	$(RM) -rf $(CLEAN_FILES)

test1.out: .gdbinit test1.in
	@echo "[OLDTEST-PREP] Running test1"
	@rm -rf $*.failed $(RM_ON_RUN) $(RM_ON_START) wrongtermsize
	@mkdir -p $(TMPDIR)
	@/bin/sh runnvim.sh $(ROOT) $(NVIM_PRG) $* $(RUN_VIM) $*.in
	@rm -f wrongtermsize
	@rm -rf X* viminfo

nolog:
	@echo "[OLDTEST-PREP] Removing test.log and messages"
	@rm -f test_result.log $(CLEANUP_FILES)


# New style of tests uses Vim script with assert calls.  These are easier
# to write and a lot easier to read and debug.
# Limitation: Only works with the +eval feature.
RUN_VIMTEST = $(TOOL) $(NVIM_PRG) -u unix.vim

newtests: newtestssilent
	@/bin/sh -c "if test -f messages && grep -q 'FAILED' messages; then \
	                 cat messages && cat test.log;                      \
	             fi"

newtestssilent: $(NEW_TESTS_RES)

GEN_OPT_DEPS = gen_opt_test.vim ../../../src/nvim/options.lua ../../../runtime/doc/options.txt

opt_test.vim: $(GEN_OPT_DEPS)
	$(NVIM_PRG) -e -s -u NONE $(NO_INITS) -S $(GEN_OPT_DEPS)
	@if test -f test.log; then \
		cat test.log; \
		exit 1; \
	fi

# Explicit dependencies.
test_options_all.res: opt_test.vim

%.res: %.vim .gdbinit
	@echo "[OLDTEST] Running" $*
	@rm -rf $*.failed test.ok $(RM_ON_RUN)
	@mkdir -p $(TMPDIR)
	@/bin/sh runnvim.sh $(ROOT) $(NVIM_PRG) $* $(RUN_VIMTEST) $(NO_INITS) -u NONE --cmd "set shortmess-=F" -S runtest.vim $*.vim
