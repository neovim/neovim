MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
MAKEFILE_DIR  := $(dir $(MAKEFILE_PATH))

filter-false = $(strip $(filter-out 0 off OFF false FALSE,$1))
filter-true = $(strip $(filter-out 1 on ON true TRUE,$1))

# See contrib/local.mk.example
-include local.mk

all: nvim

CMAKE ?= $(shell (command -v cmake3 || echo cmake))
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
	  cached_prefix=$(shell $(CMAKE) -L -N build | 2>/dev/null grep 'CMAKE_INSTALL_PREFIX' | cut -d '=' -f2); \
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
	$(BUILD_TOOL) -C build

libnvim: build/.ran-cmake deps
	$(BUILD_TOOL) -C build libnvim

cmake:
	touch CMakeLists.txt
	$(MAKE) build/.ran-cmake

build/.ran-cmake: | deps
	$(CMAKE) -B build -G '$(CMAKE_GENERATOR)' $(CMAKE_FLAGS) $(CMAKE_EXTRA_FLAGS) $(MAKEFILE_DIR)
	touch $@

deps: | build/.ran-deps-cmake
ifeq ($(call filter-true,$(USE_BUNDLED)),)
	$(BUILD_TOOL) -C $(DEPS_BUILD_DIR)
endif

ifeq ($(call filter-true,$(USE_BUNDLED)),)
$(DEPS_BUILD_DIR):
	mkdir -p "$@"
build/.ran-deps-cmake:: $(DEPS_BUILD_DIR)
	$(CMAKE) -S $(MAKEFILE_DIR)/cmake.deps -B $(DEPS_BUILD_DIR) -G '$(CMAKE_GENERATOR)' \
		$(BUNDLED_CMAKE_FLAG) $(BUNDLED_LUA_CMAKE_FLAG) $(DEPS_CMAKE_FLAGS)
endif
build/.ran-deps-cmake::
	mkdir -p build
	touch $@

# TODO: cmake 3.2+ add_custom_target() has a USES_TERMINAL flag.
oldtest: | nvim
	$(SINGLE_MAKE) -C test/old/testdir clean
ifeq ($(strip $(TEST_FILE)),)
	$(SINGLE_MAKE) -C test/old/testdir NVIM_PRG=$(NVIM_PRG) $(MAKEOVERRIDES)
else
	@# Handle TEST_FILE=test_foo{,.res,.vim}.
	$(SINGLE_MAKE) -C test/old/testdir NVIM_PRG=$(NVIM_PRG) SCRIPTS= $(MAKEOVERRIDES) $(patsubst %.vim,%,$(patsubst %.res,%,$(TEST_FILE)))
endif
# Build oldtest by specifying the relative .vim filename.
.PHONY: phony_force
test/old/testdir/%.vim: phony_force nvim
	$(SINGLE_MAKE) -C test/old/testdir NVIM_PRG=$(NVIM_PRG) SCRIPTS= $(MAKEOVERRIDES) $(patsubst test/old/testdir/%.vim,%,$@)

functionaltest-lua: | nvim
	$(BUILD_TOOL) -C build functionaltest

FORMAT=formatc formatlua format
LINT=lintlua lintsh lintc clang-analyzer lintcommit lintdoc lint
TEST=functionaltest unittest
generated-sources benchmark $(FORMAT) $(LINT) $(TEST) doc: | build/.ran-cmake
	$(CMAKE) --build build --target $@

test: $(TEST)

iwyu: build/.ran-cmake
	$(CMAKE) --preset iwyu
	$(CMAKE) --build build > build/iwyu.log
	iwyu-fix-includes --only_re="src/nvim" --ignore_re="(src/nvim/eval/encode.c\
	|src/nvim/auto/\
	|src/nvim/os/lang.c\
	|src/nvim/map.c\
	)" --nosafe_headers < build/iwyu.log
	$(CMAKE) -B build -U ENABLE_IWYU
	$(CMAKE) --build build

clean:
	test -d build && $(BUILD_TOOL) -C build clean || true
	$(MAKE) -C test/old/testdir clean
	$(MAKE) -C runtime/indent clean

distclean:
	rm -rf $(DEPS_BUILD_DIR) build
	$(MAKE) clean

install: checkprefix nvim
	$(BUILD_TOOL) -C build install

appimage:
	bash scripts/genappimage.sh

# Build an appimage with embedded update information.
#   appimage-nightly: for nightly builds
#   appimage-latest: for a release
appimage-%:
	bash scripts/genappimage.sh $*

.PHONY: test clean distclean nvim libnvim cmake deps install appimage checkprefix benchmark $(FORMAT) $(LINT) $(TEST)
