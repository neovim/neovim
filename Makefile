CMAKE_FLAGS := -DCMAKE_BUILD_TYPE=Debug

BUILD_TYPE := $(shell (type ninja > /dev/null 2>&1 && echo "Ninja") || \
    echo "Unix Makefiles")

ifeq (Ninja,$(BUILD_TYPE))
    ifneq ($(shell cmake --help 2>/dev/null | grep Ninja),)
        HAS_CNINJA := $(shell type cninja 2>/dev/null)
        ifeq ($(HAS_CNINJA),)
            BUILD_TOOL := ninja
        else
            BUILD_TOOL := cninja
        endif
    else
        # User's version of CMake doesn't support Ninja
        BUILD_TOOL := make
        BUILD_TYPE := Unix Makefiles
    endif
else
    BUILD_TOOL := make
endif

build/src/vim: deps
	cd build && $(BUILD_TOOL)

test: build/src/vim
	cd src/testdir && make

deps: .deps/usr/lib/libuv.a

.deps/usr/lib/libuv.a:
	sh -e scripts/get-libuv.sh

cmake: clean
	mkdir build
	cd build && cmake -G "$(BUILD_TYPE)" $(CMAKE_FLAGS) ../

clean:
	rm -rf build
	for file in lua mbyte mzscheme small tiny; do \
		rm -f src/testdir/$$file.vim; \
	done

.PHONY: test deps cmake

.DEFAULT: build/src/vim
