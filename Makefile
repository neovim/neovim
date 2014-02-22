CMAKE_FLAGS := -DCMAKE_BUILD_TYPE=Debug

build/bin/vim: deps
	cd build && make

test: build/bin/vim
	cd src/testdir && make

deps: .deps/usr/lib/libuv.a

.deps/usr/lib/libuv.a:
	sh -e scripts/get-libuv.sh

cmake: clean
	mkdir build
	cd build && cmake $(CMAKE_FLAGS) ../

clean:
	rm -rf build
	for file in lua mbyte mzscheme small tiny; do \
		rm -f src/testdir/$$file.vim; \
	done

.PHONY: test deps cmake

.DEFAULT: build/bin/vim
