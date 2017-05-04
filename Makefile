filter-false = $(strip $(filter-out 0 off OFF false FALSE,$1))
filter-true = $(strip $(filter-out 1 on ON true TRUE,$1))

# See contrib/local.mk.example
-include local.mk

CMAKE_PRG ?= $(shell (command -v cmake3 || echo cmake))
CMAKE_BUILD_TYPE ?= Debug

CMAKE_FLAGS := -DCMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE)
DOC_DOWNLOAD_URL_BASE := https://raw.githubusercontent.com/neovim/doc/gh-pages
CLINT_ERRORS_FILE_PATH := /reports/clint/errors.json

BUILD_TYPE ?= $(shell (type ninja > /dev/null 2>&1 && echo "Ninja") || \
    echo "Unix Makefiles")

ifeq (,$(BUILD_TOOL))
  ifeq (Ninja,$(BUILD_TYPE))
    ifneq ($(shell $(CMAKE_PRG) --help 2>/dev/null | grep Ninja),)
      BUILD_TOOL := ninja
    else
      # User's version of CMake doesn't support Ninja
      BUILD_TOOL = $(MAKE)
      BUILD_TYPE := Unix Makefiles
    endif
  else
    BUILD_TOOL = $(MAKE)
  endif
endif

ifneq ($(VERBOSE),)
  # Only need to handle Ninja here.  Make will inherit the VERBOSE variable.
  ifeq ($(BUILD_TYPE),Ninja)
    VERBOSE_FLAG := -v
  endif
endif

BUILD_CMD = $(BUILD_TOOL) $(VERBOSE_FLAG)

# Extra CMake flags which extend the default set
CMAKE_EXTRA_FLAGS ?=
DEPS_CMAKE_FLAGS ?=
USE_BUNDLED_DEPS ?=

ifneq (,$(USE_BUNDLED_DEPS))
  BUNDLED_CMAKE_FLAG := -DUSE_BUNDLED=$(USE_BUNDLED_DEPS)
endif

ifneq (,$(findstring functionaltest-lua,$(MAKECMDGOALS)))
  BUNDLED_LUA_CMAKE_FLAG := -DUSE_BUNDLED_LUA=ON
  $(shell [ -x .deps/usr/bin/lua ] || rm build/.ran-*)
endif

# For use where we want to make sure only a single job is run.  This does issue 
# a warning, but we need to keep SCRIPTS argument.
SINGLE_MAKE = export MAKEFLAGS= ; $(MAKE)

all: nvim

nvim: build/.ran-cmake deps
	+$(BUILD_CMD) -C build

libnvim: build/.ran-cmake deps
	+$(BUILD_CMD) -C build libnvim

cmake:
	touch CMakeLists.txt
	$(MAKE) build/.ran-cmake

build/.ran-cmake: | deps
	cd build && $(CMAKE_PRG) -G '$(BUILD_TYPE)' $(CMAKE_FLAGS) $(CMAKE_EXTRA_FLAGS) ..
	touch $@

deps: | build/.ran-third-party-cmake
ifeq ($(call filter-true,$(USE_BUNDLED_DEPS)),)
	+$(BUILD_CMD) -C .deps
endif

build/.ran-third-party-cmake:
ifeq ($(call filter-true,$(USE_BUNDLED_DEPS)),)
	mkdir -p .deps
	cd .deps && \
		$(CMAKE_PRG) -G '$(BUILD_TYPE)' $(BUNDLED_CMAKE_FLAG) $(BUNDLED_LUA_CMAKE_FLAG) \
		$(DEPS_CMAKE_FLAGS) ../third-party
endif
	mkdir -p build
	touch $@


# TODO: cmake 3.2+ add_custom_target() has a USES_TERMINAL flag.
oldtest: | nvim helptags
	+$(SINGLE_MAKE) -C src/nvim/testdir clean
ifeq ($(strip $(TEST_FILE)),)
	+$(SINGLE_MAKE) -C src/nvim/testdir NVIM_PRG="$(realpath build/bin/nvim)" $(MAKEOVERRIDES)
else
	+$(SINGLE_MAKE) -C src/nvim/testdir NVIM_PRG="$(realpath build/bin/nvim)" NEW_TESTS=$(TEST_FILE) SCRIPTS= $(MAKEOVERRIDES)
endif

helptags: | nvim
	+$(BUILD_CMD) -C build helptags

functionaltest: | nvim
	+$(BUILD_CMD) -C build functionaltest

functionaltest-lua: | nvim
	+$(BUILD_CMD) -C build functionaltest-lua

testlint: | build/.ran-cmake deps
	$(BUILD_CMD) -C build testlint

unittest: | nvim
	+$(BUILD_CMD) -C build unittest

benchmark: | nvim
	+$(BUILD_CMD) -C build benchmark

test: functionaltest unittest

clean:
	+test -d build && $(BUILD_CMD) -C build clean || true
	$(MAKE) -C src/nvim/testdir clean
	$(MAKE) -C runtime/doc clean

distclean: clean
	rm -rf .deps build

install: | nvim
	+$(BUILD_CMD) -C build install

clint: build/.ran-cmake
	+$(BUILD_CMD) -C build clint

clint-full: build/.ran-cmake
	+$(BUILD_CMD) -C build clint-full

check-single-includes: build/.ran-cmake
	+$(BUILD_CMD) -C build check-single-includes

appimage:
	sh scripts/genappimage.sh

lint: check-single-includes clint testlint

.PHONY: test testlint functionaltest unittest lint clint clean distclean nvim libnvim cmake deps install appimage
