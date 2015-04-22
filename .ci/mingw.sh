. "$CI_SCRIPTS/common.sh"

# FIXME: When Travis gets a recent version of Mingw-w64 use this
#sudo apt-get install binutils-mingw-w64-i686 gcc-mingw-w64-i686 g++-mingw-w64-i686 mingw-w64-dev mingw-w64-tools
#sudo apt-get install wine
sudo apt-get install libc6-dev-i386

# mingw-w64 build from http://sourceforge.net/projects/mingw-w64/files/Toolchains%20targetting%20Win32/Personal%20Builds/rubenvb/gcc-4.8-release/
wget "http://downloads.sourceforge.net/project/mingw-w64/Toolchains%20targetting%20Win32/Personal%20Builds/rubenvb/gcc-4.8-release/i686-w64-mingw32-gcc-4.8.0-linux64_rubenvb.tar.xz" -O mingw.tar.xz
sudo tar -axf mingw.tar.xz -C /opt
export PATH=$PATH:/opt/mingw32/bin

# Build third-party
mkdir .deps
cd .deps
cmake -DCMAKE_TOOLCHAIN_FILE=../cmake/mingw32-w64-cross-travis.toolchain.cmake ../third-party/
cmake --build .
cd ..

# Build Neovim
mkdir build
cd build
cmake -DCMAKE_TOOLCHAIN_FILE=../cmake/mingw32-w64-cross-travis.toolchain.cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_C_FLAGS="-DMIN_LOG_LEVEL=0 -pg" ..
cmake --build .
