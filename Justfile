# Build neovim
nvim: deps
        cmake -B build -G Ninja
        cmake --build build

# Build dependencies
deps:
        cmake -S cmake.deps -B .deps -G Ninja
        cmake --build .deps

# Run functionaltest
functionaltest: nvim
	cmake --build build --target functionaltest
