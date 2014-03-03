-include local.mk

CMAKE_FLAGS := -DCMAKE_BUILD_TYPE=Debug -DCMAKE_PREFIX_PATH=.deps/usr

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

# Extra CMake flags which extend the default set
CMAKE_EXTRA_FLAGS ?=
DEPS_CMAKE_FLAGS ?=

# For use where we want to make sure only a single job is run.  This also avoids
# any warnings from the sub-make.
SINGLE_MAKE = export MAKEFLAGS= ; $(MAKE)

all: nvim

nvim: build/.ran-cmake deps
	+$(BUILD_TOOL) -C build

cmake: | build/.ran-cmake

build/.ran-cmake: | deps
	mkdir -p build
	cd build && cmake -G '$(BUILD_TYPE)' $(CMAKE_FLAGS) $(CMAKE_EXTRA_FLAGS) ..
	touch $@

deps: | .deps/build/third-party/.ran-cmake
	+$(BUILD_TOOL) -C .deps/build/third-party

.deps/build/third-party/.ran-cmake:
	mkdir -p .deps/build/third-party
	cd .deps/build/third-party && \
		cmake -G '$(BUILD_TYPE)' $(DEPS_CMAKE_FLAGS) ../../../third-party
	touch $@

test: | nvim
	+$(SINGLE_MAKE) -C src/testdir

unittest: | nvim
	+$(BUILD_TOOL) -C build unittest

clean:
	+test -d build && $(BUILD_TOOL) -C build clean || true
	$(MAKE) -C src/testdir clean

distclean: clean
	rm -rf .deps build

install: | nvim
	+$(BUILD_TOOL) -C build install

.PHONY: test unittest clean distclean nvim cmake deps install
