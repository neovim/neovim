-include local.mk

CMAKE_FLAGS := -DCMAKE_BUILD_TYPE=Debug -DCMAKE_PREFIX_PATH=third-party/dist -DLibUV_USE_STATIC=YES

# Extra CMake flags which extend the default set
CMAKE_EXTRA_FLAGS :=

build: ../build/bin/nvim

../build/bin/nvim: deps cmake
	${MAKE} -C ../build

test: ../build/bin/nvim
	${MAKE} -C ../src/testdir

deps: libuv

libuv: ../third-party/dist/lib/libuv.a

../third-party/dist/lib/libuv.a:
	sh -e compile-libuv.sh

cmake: clean deps
	mkdir -p ../build
	cd ../build && cmake $(CMAKE_FLAGS) $(CMAKE_EXTRA_FLAGS) ../

clean:
	rm -rf ../build
	${MAKE} -C ../src/testdir clean

install: ../build/bin/nvim
	${MAKE} -C build install

.PHONY: test deps cmake install build

.DEFAULT: build
