MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
MAKEFILE_DIR  := $(dir $(MAKEFILE_PATH))

filter-false = $(strip $(filter-out 0 off OFF false FALSE,$1))
filter-true = $(strip $(filter-out 1 on ON true TRUE,$1))

# See contrib/local.mk.example
-include local.mk

all: nvim

CMAKE_PRG ?= $(shell (command -v cmake3 || echo cmake))
CMAKE_BUILD_TYPE ?= Debug
CMAKE_FLAGS := -DCMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE)
# Extra CMake flags which extend the default set
CMAKE_EXTRA_FLAGS ?=
NVIM_PRG := $(MAKEFILE_DIR)/build/bin/nvim

# CMAKE_INSTALL_PREFIX
#   - May be passed directly or as part of CMAKE_EXTRA_FLAGS.
#   - `checkprefix` target checks that it matches the CMake-cached value. #9615
ifneq (,$(CMAKE_INSTALL_PREFIX)$(CMAKE_EXTRA_FLAGS))
CMAKE_INSTALL_PREFIX := $(shell echo $(CMAKE_EXTRA_FLAGS) | 2>/dev/null \
    grep -o 'CMAKE_INSTALL_PREFIX=[^ ]\+' | cut -d '=' -f2)
endif
ifneq (,$(CMAKE_INSTALL_PREFIX))
override CMAKE_EXTRA_FLAGS += -DCMAKE_INSTALL_PREFIX=$(CMAKE_INSTALL_PREFIX)

checkprefix:
	@if [ -f build/.ran-cmake ]; then \
	  cached_prefix=$(shell $(CMAKE_PRG) -L -N build | 2>/dev/null grep 'CMAKE_INSTALL_PREFIX' | cut -d '=' -f2); \
	  if ! [ "$(CMAKE_INSTALL_PREFIX)" = "$$cached_prefix" ]; then \
	    printf "Re-running CMake: CMAKE_INSTALL_PREFIX '$(CMAKE_INSTALL_PREFIX)' does not match cached value '%s'.\n" "$$cached_prefix"; \
	    $(RM) build/.ran-cmake; \
	  fi \
	fi
else
checkprefix: ;
endif

CMAKE_GENERATOR ?= $(shell (command -v ninja > /dev/null 2>&1 && echo "Ninja") || \
    echo "Unix Makefiles")
DEPS_BUILD_DIR ?= .deps
ifneq (1,$(words [$(DEPS_BUILD_DIR)]))
  $(error DEPS_BUILD_DIR must not contain whitespace)
endif

ifeq (,$(BUILD_TOOL))
  ifeq (Ninja,$(CMAKE_GENERATOR))
    BUILD_TOOL = ninja
  else
    BUILD_TOOL = $(MAKE)
  endif
endif

# Only need to handle Ninja here.  Make will inherit the VERBOSE variable, and the -j, -l, and -n flags.
ifeq ($(CMAKE_GENERATOR),Ninja)
  ifneq ($(VERBOSE),)
    BUILD_TOOL += -v
  endif
  BUILD_TOOL += $(shell printf '%s' '$(MAKEFLAGS)' | grep -o -- ' *-[jl][0-9]\+ *')
  ifeq (n,$(findstring n,$(firstword -$(MAKEFLAGS))))
    BUILD_TOOL += -n
  endif
endif

DEPS_CMAKE_FLAGS ?=
USE_BUNDLED ?=

ifneq (,$(USE_BUNDLED))
  BUNDLED_CMAKE_FLAG := -DUSE_BUNDLED=$(USE_BUNDLED)
endif

ifneq (,$(findstring functionaltest-lua,$(MAKECMDGOALS)))
  BUNDLED_LUA_CMAKE_FLAG := -DUSE_BUNDLED_LUA=ON
  $(shell [ -x $(DEPS_BUILD_DIR)/usr/bin/lua ] || rm build/.ran-*)
endif

# For use where we want to make sure only a single job is run.  This does issue 
# a warning, but we need to keep SCRIPTS argument.
SINGLE_MAKE = export MAKEFLAGS= ; $(MAKE)

nvim: build/.ran-cmake deps
	+$(BUILD_TOOL) -C build

libnvim: build/.ran-cmake deps
	+$(BUILD_TOOL) -C build libnvim

cmake:
	touch CMakeLists.txt
	$(MAKE) build/.ran-cmake

build/.ran-cmake: | deps
	cd build && $(CMAKE_PRG) -G '$(CMAKE_GENERATOR)' $(CMAKE_FLAGS) $(CMAKE_EXTRA_FLAGS) $(MAKEFILE_DIR)
	touch $@

deps: | build/.ran-deps-cmake
ifeq ($(call filter-true,$(USE_BUNDLED)),)
	+$(BUILD_TOOL) -C $(DEPS_BUILD_DIR)
endif

ifeq ($(call filter-true,$(USE_BUNDLED)),)
$(DEPS_BUILD_DIR):
	mkdir -p "$@"
build/.ran-deps-cmake:: $(DEPS_BUILD_DIR)
	cd $(DEPS_BUILD_DIR) && \
		$(CMAKE_PRG) -G '$(CMAKE_GENERATOR)' $(BUNDLED_CMAKE_FLAG) $(BUNDLED_LUA_CMAKE_FLAG) \
		$(DEPS_CMAKE_FLAGS) $(MAKEFILE_DIR)/cmake.deps
endif
build/.ran-deps-cmake::
	mkdir -p build
	touch $@

# TODO: cmake 3.2+ add_custom_target() has a USES_TERMINAL flag.
oldtest: | nvim build/runtime/doc/tags
	+$(SINGLE_MAKE) -C test/old/testdir clean
ifeq ($(strip $(TEST_FILE)),)
	+$(SINGLE_MAKE) -C test/old/testdir NVIM_PRG=$(NVIM_PRG) $(MAKEOVERRIDES)
else
	@# Handle TEST_FILE=test_foo{,.res,.vim}.
	+$(SINGLE_MAKE) -C test/old/testdir NVIM_PRG=$(NVIM_PRG) SCRIPTS= $(MAKEOVERRIDES) $(patsubst %.vim,%,$(patsubst %.res,%,$(TEST_FILE)))
endif
# Build oldtest by specifying the relative .vim filename.
.PHONY: phony_force
test/old/testdir/%.vim: phony_force nvim
	+$(SINGLE_MAKE) -C test/old/testdir NVIM_PRG=$(NVIM_PRG) SCRIPTS= $(MAKEOVERRIDES) $(patsubst test/old/testdir/%.vim,%,$@)

functionaltest-lua: | nvim
	$(BUILD_TOOL) -C build functionaltest

FORMAT=formatc formatlua format
LINT=lintlua lintsh lintc clang-analyzer lintcommit lint
TEST=functionaltest unittest
generated-sources benchmark $(FORMAT) $(LINT) $(TEST) doc: | build/.ran-cmake
	$(CMAKE_PRG) --build build --target $@

test: $(TEST)

# The ignored header files should be synced with the `check_includes_ignore`
# array in src/clint.py
iwyu: build/.ran-cmake
	cmake --preset iwyu
	cmake --build build > build/iwyu.log
	iwyu-fix-includes --only_re="src/nvim" --ignore_re="(src/nvim/eval/encode.c|src/nvim/auto/\
	|src/nvim/api/autocmd.h\
	|src/nvim/api/buffer.h\
	|src/nvim/api/command.h\
	|src/nvim/api/extmark.h\
	|src/nvim/api/options.h\
	|src/nvim/api/private/defs.h\
	|src/nvim/api/private/dispatch.h\
	|src/nvim/api/private/helpers.h\
	|src/nvim/api/private/validate.h\
	|src/nvim/api/ui.h\
	|src/nvim/api/vim.h\
	|src/nvim/api/vimscript.h\
	|src/nvim/api/win_config.h\
	|src/nvim/api/window.h\
	|src/nvim/arglist.h\
	|src/nvim/ascii.h\
	|src/nvim/assert.h\
	|src/nvim/autocmd.h\
	|src/nvim/autocmd_defs.h\
	|src/nvim/base64.h\
	|src/nvim/buffer.h\
	|src/nvim/buffer_defs.h\
	|src/nvim/buffer_updates.h\
	|src/nvim/bufwrite.h\
	|src/nvim/change.h\
	|src/nvim/channel.h\
	|src/nvim/charset.h\
	|src/nvim/cmdexpand.h\
	|src/nvim/cmdexpand_defs.h\
	|src/nvim/cmdhist.h\
	|src/nvim/context.h\
	|src/nvim/cursor.h\
	|src/nvim/cursor_shape.h\
	|src/nvim/debugger.h\
	|src/nvim/decoration.h\
	|src/nvim/decoration_defs.h\
	|src/nvim/decoration_provider.h\
	|src/nvim/diff.h\
	|src/nvim/digraph.h\
	|src/nvim/drawline.h\
	|src/nvim/drawscreen.h\
	|src/nvim/edit.h\
	|src/nvim/eval.h\
	|src/nvim/eval/buffer.h\
	|src/nvim/eval/decode.h\
	|src/nvim/eval/encode.h\
	|src/nvim/eval/executor.h\
	|src/nvim/eval/funcs.h\
	|src/nvim/eval/gc.h\
	|src/nvim/eval/typval.h\
	|src/nvim/eval/typval_defs.h\
	|src/nvim/eval/typval_encode.h\
	|src/nvim/eval/userfunc.h\
	|src/nvim/eval/vars.h\
	|src/nvim/eval/window.h\
	|src/nvim/event/libuv_process.h\
	|src/nvim/event/loop.h\
	|src/nvim/event/multiqueue.h\
	|src/nvim/event/process.h\
	|src/nvim/event/rstream.h\
	|src/nvim/event/signal.h\
	|src/nvim/event/socket.h\
	|src/nvim/event/stream.h\
	|src/nvim/event/time.h\
	|src/nvim/event/wstream.h\
	|src/nvim/ex_cmds.h\
	|src/nvim/ex_cmds2.h\
	|src/nvim/ex_cmds_defs.h\
	|src/nvim/ex_docmd.h\
	|src/nvim/ex_eval.h\
	|src/nvim/ex_eval_defs.h\
	|src/nvim/ex_getln.h\
	|src/nvim/ex_session.h\
	|src/nvim/extmark.h\
	|src/nvim/extmark_defs.h\
	|src/nvim/file_search.h\
	|src/nvim/fileio.h\
	|src/nvim/fold.h\
	|src/nvim/fold_defs.h\
	|src/nvim/garray.h\
	|src/nvim/getchar.h\
	|src/nvim/globals.h\
	|src/nvim/grid.h\
	|src/nvim/grid_defs.h\
	|src/nvim/hashtab.h\
	|src/nvim/help.h\
	|src/nvim/highlight.h\
	|src/nvim/highlight_defs.h\
	|src/nvim/highlight_group.h\
	|src/nvim/iconv.h\
	|src/nvim/indent.h\
	|src/nvim/indent_c.h\
	|src/nvim/input.h\
	|src/nvim/insexpand.h\
	|src/nvim/keycodes.h\
	|src/nvim/linematch.h\
	|src/nvim/log.h\
	|src/nvim/lua/base64.h\
	|src/nvim/lua/executor.h\
	|src/nvim/lua/secure.h\
	|src/nvim/lua/spell.h\
	|src/nvim/lua/stdlib.h\
	|src/nvim/lua/treesitter.h\
	|src/nvim/lua/xdiff.h\
	|src/nvim/macros.h\
	|src/nvim/main.h\
	|src/nvim/map.h\
	|src/nvim/mapping.h\
	|src/nvim/mapping_defs.h\
	|src/nvim/mark.h\
	|src/nvim/mark_defs.h\
	|src/nvim/marktree.h\
	|src/nvim/match.h\
	|src/nvim/mbyte.h\
	|src/nvim/mbyte_defs.h\
	|src/nvim/memfile.h\
	|src/nvim/memfile_defs.h\
	|src/nvim/memline.h\
	|src/nvim/memory.h\
	|src/nvim/menu.h\
	|src/nvim/message.h\
	|src/nvim/mouse.h\
	|src/nvim/move.h\
	|src/nvim/msgpack_rpc/channel.h\
	|src/nvim/msgpack_rpc/channel_defs.h\
	|src/nvim/msgpack_rpc/helpers.h\
	|src/nvim/msgpack_rpc/server.h\
	|src/nvim/msgpack_rpc/unpacker.h\
	|src/nvim/normal.h\
	|src/nvim/nvim/extmark.h\
	|src/nvim/ops.h\
	|src/nvim/option.h\
	|src/nvim/option_defs.h\
	|src/nvim/option_vars.h\
	|src/nvim/optionstr.h\
	|src/nvim/os/dl.h\
	|src/nvim/os/fileio.h\
	|src/nvim/os/fs.h\
	|src/nvim/os/input.h\
	|src/nvim/os/lang.h\
	|src/nvim/os/os.h\
	|src/nvim/os/pty_conpty_win.h\
	|src/nvim/os/pty_process_unix.h\
	|src/nvim/os/pty_process_win.h\
	|src/nvim/os/shell.h\
	|src/nvim/os/time.h\
	|src/nvim/os/tty.h\
	|src/nvim/path.h\
	|src/nvim/plines.h\
	|src/nvim/popupmenu.h\
	|src/nvim/profile.h\
	|src/nvim/quickfix.h\
	|src/nvim/regexp.h\
	|src/nvim/regexp_defs.h\
	|src/nvim/runtime.h\
	|src/nvim/search.h\
	|src/nvim/sha256.h\
	|src/nvim/shada.h\
	|src/nvim/sign.h\
	|src/nvim/sign_defs.h\
	|src/nvim/spell.h\
	|src/nvim/spell_defs.h\
	|src/nvim/spellfile.h\
	|src/nvim/state.h\
	|src/nvim/statusline.h\
	|src/nvim/statusline_defs.h\
	|src/nvim/strings.h\
	|src/nvim/syntax.h\
	|src/nvim/tag.h\
	|src/nvim/terminal.h\
	|src/nvim/testing.h\
	|src/nvim/textformat.h\
	|src/nvim/textobject.h\
	|src/nvim/tui/input.h\
	|src/nvim/tui/tui.h\
	|src/nvim/ugrid.h\
	|src/nvim/ui.h\
	|src/nvim/ui_client.h\
	|src/nvim/ui_compositor.h\
	|src/nvim/undo.h\
	|src/nvim/undo_defs.h\
	|src/nvim/usercmd.h\
	|src/nvim/version.h\
	|src/nvim/vim.h\
	|src/nvim/viml/parser/expressions.h\
	|src/nvim/viml/parser/parser.h\
	|src/nvim/window.h\
	)" --nosafe_headers < build/iwyu.log
	cmake -B build -U ENABLE_IWYU
	cmake --build build

clean:
	+test -d build && $(BUILD_TOOL) -C build clean || true
	$(MAKE) -C test/old/testdir clean
	$(MAKE) -C runtime/indent clean

distclean:
	rm -rf $(DEPS_BUILD_DIR) build
	$(MAKE) clean

install: checkprefix nvim
	+$(BUILD_TOOL) -C build install

appimage:
	bash scripts/genappimage.sh

# Build an appimage with embedded update information.
#   appimage-nightly: for nightly builds
#   appimage-latest: for a release
appimage-%:
	bash scripts/genappimage.sh $*

# Generic pattern rules, allowing for `make build/bin/nvim` etc.
# Does not work with "Unix Makefiles".
ifeq ($(CMAKE_GENERATOR),Ninja)
build/%: phony_force
	$(BUILD_TOOL) -C build $(patsubst build/%,%,$@)

$(DEPS_BUILD_DIR)/%: phony_force
	$(BUILD_TOOL) -C $(DEPS_BUILD_DIR) $(patsubst $(DEPS_BUILD_DIR)/%,%,$@)
endif

.PHONY: test clean distclean nvim libnvim cmake deps install appimage checkprefix benchmark $(FORMAT) $(LINT) $(TEST)
