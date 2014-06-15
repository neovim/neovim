filter-false = $(strip $(filter-out 0 off OFF false FALSE,$1))
filter-true = $(strip $(filter-out 1 on ON true TRUE,$1))

-include local.mk

CMAKE_BUILD_TYPE ?= Debug

CMAKE_FLAGS := -DCMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE)

BUILD_TYPE ?= $(shell (type ninja > /dev/null 2>&1 && echo "Ninja") || \
    echo "Unix Makefiles")

ifeq (,$(BUILD_TOOL))
  ifeq (Ninja,$(BUILD_TYPE))
    ifneq ($(shell cmake --help 2>/dev/null | grep Ninja),)
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

# For use where we want to make sure only a single job is run.  This does issue 
# a warning, but we need to keep SCRIPTS argument.
SINGLE_MAKE = export MAKEFLAGS= ; $(MAKE)

all: nvim

nvim: build/.ran-cmake deps
	+$(BUILD_CMD) -C build

cmake:
	touch CMakeLists.txt
	$(MAKE) build/.ran-cmake

build/.ran-cmake: | deps
	cd build && cmake -G '$(BUILD_TYPE)' $(CMAKE_FLAGS) $(CMAKE_EXTRA_FLAGS) ..
	touch $@

deps: | build/.ran-third-party-cmake
ifeq ($(call filter-true,$(USE_BUNDLED_DEPS)),)
	+$(BUILD_CMD) -C .deps/build/third-party
endif

build/.ran-third-party-cmake:
ifeq ($(call filter-true,$(USE_BUNDLED_DEPS)),)
	mkdir -p .deps/build/third-party
	cd .deps/build/third-party && \
		cmake -G '$(BUILD_TYPE)' $(BUNDLED_CMAKE_FLAG) \
		$(DEPS_CMAKE_FLAGS) ../../../third-party
endif
	mkdir -p build
	touch $@

test: | nvim
	+$(SINGLE_MAKE) -C src/nvim/testdir $(MAKEOVERRIDES)

unittest: | nvim
	+$(BUILD_CMD) -C build unittest

clean:
	+test -d build && $(BUILD_CMD) -C build clean || true
	$(MAKE) -C src/nvim/testdir clean

distclean: clean
	rm -rf .deps build

install: | nvim
	+$(BUILD_CMD) -C build install

.PHONY: test unittest clean distclean nvim cmake deps install
