-include local.mk

CMAKE_FLAGS := -DCMAKE_BUILD_TYPE=Debug

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

# For use where we want to make sure only a single job is run.  This also avoids
# any warnings from the sub-make.
SINGLE_MAKE = export MAKEFLAGS= ; $(MAKE)

all: nvim

nvim: build/.ran-cmake deps
	+$(BUILD_CMD) -C build

cmake:
	touch CMakeLists.txt
	$(MAKE) build/.ran-cmake

build/.ran-cmake: | deps
	mkdir -p build
	cd build && cmake -G '$(BUILD_TYPE)' $(CMAKE_FLAGS) $(CMAKE_EXTRA_FLAGS) ..
	touch $@

deps: | .deps/build/third-party/.ran-cmake
	+$(BUILD_CMD) -C .deps/build/third-party

.deps/build/third-party/.ran-cmake:
	mkdir -p .deps/build/third-party
	cd .deps/build/third-party && \
		cmake -G '$(BUILD_TYPE)' $(DEPS_CMAKE_FLAGS) ../../../third-party
	touch $@

test: | nvim
	+$(SINGLE_MAKE) -C src/testdir

unittest: | nvim
	+$(BUILD_CMD) -C build unittest

clean:
	+test -d build && $(BUILD_CMD) -C build clean || true
	$(MAKE) -C src/testdir clean

distclean: clean
	rm -rf .deps build

install: | nvim
	+$(BUILD_CMD) -C build install

.PHONY: test unittest clean distclean nvim cmake deps install
