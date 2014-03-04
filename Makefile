-include local.mk

CMAKE_FLAGS := -DCMAKE_BUILD_TYPE=Debug -DCMAKE_PREFIX_PATH=.deps/usr -DLibUV_USE_STATIC=YES

# Extra CMake flags which extend the default set
CMAKE_EXTRA_FLAGS :=

# For use where we want to make sure only a single job is run.  This also avoids
# any warnings from the sub-make.
SINGLE_MAKE = export MAKEFLAGS= ; $(MAKE)

USE_BUNDLED_DEPS := true

OBJ_NVIM = build/bin/nvim
OBJ_LIBUV = .deps/usr/lib/libuv.a
OBJ_LIBLUAJIT = .deps/usr/lib/libluajit-5.1.a
OBJ_BUSTED = .deps/usr/bin/busted

.DEFAULT: $(OBJ_NVIM)
$(OBJ_NVIM): cmake
	$(MAKE) -C build

# run legacy tests
.PHONY: test
test: $(OBJ_NVIM)
	$(SINGLE_MAKE) -C src/testdir

.PHONY: unittest
unittest: $(OBJ_NVIM) test-deps
	sh -e scripts/unittest.sh

.PHONY: build-deps
build-deps: $(OBJ_LIBUV)

$(OBJ_LIBUV):
	sh -e scripts/compile-libuv.sh

.PHONY: test-deps
test-deps: $(OBJ_LIBLUAJIT) $(OBJ_BUSTED)

$(OBJ_LIBLUAJIT):
	sh -e scripts/compile-lua.sh

$(OBJ_BUSTED):
	sh -e scripts/setup-test-tools.sh

.PHONY: cmake
cmake: $(CMAKE_DEPS)
	mkdir -p build
	cd build && cmake $(CMAKE_FLAGS) $(CMAKE_EXTRA_FLAGS) ../

ifeq ($(USE_BUNDLED_DEPS), true)
cmake: build-deps
endif

.PHONY: clean
clean:
	rm -rf build .deps
	$(MAKE) -C src/testdir clean

.PHONY: install
install: $(OBJ_NVIM)
	$(MAKE) -C build install
