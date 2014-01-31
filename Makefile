CMAKE_FLAGS := -DCMAKE_BUILD_TYPE=Debug

test: build/src/vim
	cd src/testdir && make

build/src/vim:
	cd build && make

cmake:
	rm -rf build
	mkdir build
	cd build && cmake $(CMAKE_FLAGS) ../

.PHONY: test cmake
