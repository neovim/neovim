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
BUILD_DIR ?= build
NVIM_PRG := $(MAKEFILE_DIR)/$(BUILD_DIR)/bin/nvim

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
	@if [ -f $(BUILD_DIR)/.ran-cmake ]; then \
	  cached_prefix=$(shell $(CMAKE_PRG) -L -N $(BUILD_DIR) | 2>/dev/null grep 'CMAKE_INSTALL_PREFIX' | cut -d '=' -f2); \
	  if ! [ "$(CMAKE_INSTALL_PREFIX)" = "$$cached_prefix" ]; then \
	    printf "Re-running CMake: CMAKE_INSTALL_PREFIX '$(CMAKE_INSTALL_PREFIX)' does not match cached value '%s'.\n" "$$cached_prefix"; \
	    $(RM) $(BUILD_DIR)/.ran-cmake; \
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
    ifneq ($(shell $(CMAKE_PRG) --help 2>/dev/null | grep Ninja),)
      BUILD_TOOL := ninja
    else
      # User's version of CMake doesn't support Ninja
      BUILD_TOOL = $(MAKE)
    endif
  else
    BUILD_TOOL = $(MAKE)
  endif
endif


# Only need to handle Ninja here.  Make will inherit the VERBOSE variable, and the -j and -n flags.
ifeq ($(CMAKE_GENERATOR),Ninja)
  ifneq ($(VERBOSE),)
    BUILD_TOOL += -v
  endif
  BUILD_TOOL += $(shell printf '%s' '$(MAKEFLAGS)' | grep -o -- '-j[0-9]\+')
  ifeq (n,$(findstring n,$(firstword -$(MAKEFLAGS))))
    BUILD_TOOL += -n
  endif
endif

DEPS_CMAKE_FLAGS ?=
# Back-compat: USE_BUNDLED_DEPS was the old name.
USE_BUNDLED ?= $(USE_BUNDLED_DEPS)

ifneq (,$(USE_BUNDLED))
  BUNDLED_CMAKE_FLAG := -DUSE_BUNDLED=$(USE_BUNDLED)
endif

ifneq (,$(findstring functionaltest-lua,$(MAKECMDGOALS)))
  BUNDLED_LUA_CMAKE_FLAG := -DUSE_BUNDLED_LUA=ON
  $(shell [ -x $(DEPS_BUILD_DIR)/usr/bin/lua ] || rm $(BUILD_DIR)/.ran-*)
endif

# For use where we want to make sure only a single job is run.  This does issue 
# a warning, but we need to keep SCRIPTS argument.
SINGLE_MAKE = export MAKEFLAGS= ; $(MAKE)

nvim: $(BUILD_DIR)/.ran-cmake deps
	+$(BUILD_TOOL) -C $(BUILD_DIR)

libnvim: $(BUILD_DIR)/.ran-cmake deps
	+$(BUILD_TOOL) -C $(BUILD_DIR) libnvim

cmake:
	touch CMakeLists.txt
	$(MAKE) $(BUILD_DIR)/.ran-cmake

build/.ran-cmake: | deps
	cd $(BUILD_DIR) && $(CMAKE_PRG) -G '$(CMAKE_GENERATOR)' $(CMAKE_FLAGS) $(CMAKE_EXTRA_FLAGS) $(MAKEFILE_DIR)
	touch $@

deps: | $(BUILD_DIR)/.ran-third-party-cmake
ifeq ($(call filter-true,$(USE_BUNDLED)),)
	+$(BUILD_TOOL) -C $(DEPS_BUILD_DIR)
endif

ifeq ($(call filter-true,$(USE_BUNDLED)),)
$(DEPS_BUILD_DIR):
	mkdir -p "$@"
build/.ran-third-party-cmake:: $(DEPS_BUILD_DIR)
	cd $(DEPS_BUILD_DIR) && \
		$(CMAKE_PRG) -G '$(CMAKE_GENERATOR)' $(BUNDLED_CMAKE_FLAG) $(BUNDLED_LUA_CMAKE_FLAG) \
		$(DEPS_CMAKE_FLAGS) $(MAKEFILE_DIR)/third-party
endif
build/.ran-third-party-cmake::
	mkdir -p $(BUILD_DIR)
	touch $@

# TODO: cmake 3.2+ add_custom_target() has a USES_TERMINAL flag.
oldtest: | nvim $(BUILD_DIR)/runtime/doc/tags
	+$(SINGLE_MAKE) -C src/nvim/testdir clean
ifeq ($(strip $(TEST_FILE)),)
	+$(SINGLE_MAKE) -C src/nvim/testdir NVIM_PRG=$(NVIM_PRG) $(MAKEOVERRIDES)
else
	@# Handle TEST_FILE=test_foo{,.res,.vim}.
	+$(SINGLE_MAKE) -C src/nvim/testdir NVIM_PRG=$(NVIM_PRG) SCRIPTS= $(MAKEOVERRIDES) $(patsubst %.vim,%,$(patsubst %.res,%,$(TEST_FILE)))
endif
# $(BUILD_DIR) oldtest by specifying the relative .vim filename.
.PHONY: phony_force
src/nvim/testdir/%.vim: phony_force
	+$(SINGLE_MAKE) -C src/nvim/testdir NVIM_PRG=$(NVIM_PRG) SCRIPTS= $(MAKEOVERRIDES) $(patsubst src/nvim/testdir/%.vim,%,$@)

$(BUILD_DIR)/runtime/doc/tags helptags: | nvim
	+$(BUILD_TOOL) -C $(BUILD_DIR) runtime/doc/tags

# Builds help HTML _and_ checks for invalid help tags.
helphtml: | nvim $(BUILD_DIR)/runtime/doc/tags
	+$(BUILD_TOOL) -C $(BUILD_DIR) doc_html

functionaltest: | nvim
	+$(BUILD_TOOL) -C $(BUILD_DIR) functionaltest

functionaltest-lua: | nvim
	+$(BUILD_TOOL) -C $(BUILD_DIR) functionaltest-lua

lualint: | $(BUILD_DIR)/.ran-cmake deps
	$(BUILD_TOOL) -C $(BUILD_DIR) lualint

shlint:
	@shellcheck --version | head -n 2
	shellcheck scripts/vim-patch.sh

_opt_shlint:
	@command -v shellcheck && { $(MAKE) shlint; exit $$?; } \
		|| echo "SKIP: shlint (shellcheck not found)"

pylint:
	flake8 contrib/ scripts/ src/ test/

# Run pylint only if flake8 is installed.
_opt_pylint:
	@command -v flake8 && { $(MAKE) pylint; exit $$?; } \
		|| echo "SKIP: pylint (flake8 not found)"

unittest: | nvim
	+$(BUILD_TOOL) -C $(BUILD_DIR) unittest

benchmark: | nvim
	+$(BUILD_TOOL) -C $(BUILD_DIR) benchmark

test: functionaltest unittest

clean:
	+test -d $(BUILD_DIR) && $(BUILD_TOOL) -C $(BUILD_DIR) clean || true
	$(MAKE) -C src/nvim/testdir clean
	$(MAKE) -C runtime/doc clean
	$(MAKE) -C runtime/indent clean

distclean:
	rm -rf $(DEPS_BUILD_DIR) $(BUILD_DIR)
	$(MAKE) clean

install: checkprefix nvim
	+$(BUILD_TOOL) -C $(BUILD_DIR) install

clint: $(BUILD_DIR)/.ran-cmake
	+$(BUILD_TOOL) -C $(BUILD_DIR) clint

clint-full: $(BUILD_DIR)/.ran-cmake
	+$(BUILD_TOOL) -C $(BUILD_DIR) clint-full

check-single-includes: $(BUILD_DIR)/.ran-cmake
	+$(BUILD_TOOL) -C $(BUILD_DIR) check-single-includes

generated-sources: $(BUILD_DIR)/.ran-cmake
	+$(BUILD_TOOL) -C $(BUILD_DIR) generated-sources

appimage:
	bash scripts/genappimage.sh

# Build an appimage with embedded update information.
#   appimage-nightly: for nightly builds
#   appimage-latest: for a release
appimage-%:
	bash scripts/genappimage.sh $*

lint: check-single-includes clint lualint _opt_pylint _opt_shlint

# Generic pattern rules, allowing for `make build/bin/nvim` etc.
# Does not work with "Unix Makefiles".
ifeq ($(CMAKE_GENERATOR),Ninja)
$(BUILD_DIR)/%: phony_force
	$(BUILD_TOOL) -C $(BUILD_DIR) $(patsubst $(BUILD_DIR)/%,%,$@)

$(DEPS_BUILD_DIR)/%: phony_force
	$(BUILD_TOOL) -C $(DEPS_BUILD_DIR) $(patsubst $(DEPS_BUILD_DIR)/%,%,$@)
endif

.PHONY: test lualint pylint shlint functionaltest unittest lint clint clean distclean nvim libnvim cmake deps install appimage checkprefix
