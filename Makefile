-include local.mk

CMAKE_FLAGS := -DCMAKE_BUILD_TYPE=Debug -DCMAKE_PREFIX_PATH=.deps/usr -DLibUV_USE_STATIC=YES

# Extra CMake flags which extend the default set
CMAKE_EXTRA_FLAGS :=

# For use where we want to make sure only a single job is run.  This also avoids
# any warnings from the sub-make.
SINGLE_MAKE = export MAKEFLAGS= ; $(MAKE)

build/bin/nvim: deps
	$(MAKE) -C build

test: build/bin/nvim
	$(SINGLE_MAKE) -C src/testdir

unittest: build/bin/nvim
	sh -e scripts/unittest.sh

deps: .deps/usr/lib/libuv.a .deps/usr/lib/libluajit-5.1.a .deps/usr/bin/busted

.deps/usr/lib/libuv.a:
	sh -e scripts/compile-libuv.sh

.deps/usr/lib/libluajit-5.1.a:
	sh -e scripts/compile-lua.sh

.deps/usr/bin/busted:
	sh -e scripts/setup-test-tools.sh

cmake: clean deps
	mkdir build
	cd build && cmake $(CMAKE_FLAGS) $(CMAKE_EXTRA_FLAGS) ../

clean:
	rm -rf build
	$(MAKE) -C src/testdir clean

install: build/bin/nvim
	$(MAKE) -C build install

.PHONY: test unittest deps cmake install

.DEFAULT: build/bin/nvim
