:: These are native MinGW builds, but they use the toolchain inside
:: MSYS2, this allows using all the dependencies and tools available
:: in MSYS2, but we cannot build inside the MSYS2 shell.
echo on
if "%CONFIGURATION%" == "MINGW_32" (
	set ARCH=i686
	set BITS=32
) else (
	set ARCH=x86_64
	set BITS=64
)
:: We cannot have sh.exe in the PATH (MinGW)
set PATH=%PATH:C:\Program Files\Git\usr\bin;=%
set PATH=C:\msys64\mingw%BITS%\bin;C:\Windows\System32;C:\Windows;%PATH%
:: The default cpack in the PATH is not CMake
set PATH=C:\Program Files (x86)\CMake\bin\cpack.exe;%PATH%

:: Build third-party dependencies
C:\msys64\usr\bin\bash -lc "pacman --verbose --noconfirm -Su" || goto :error
C:\msys64\usr\bin\bash -lc "pacman --verbose --noconfirm --needed -S mingw-w64-%ARCH%-cmake mingw-w64-%ARCH%-perl mingw-w64-%ARCH%-diffutils gperf" || goto :error

:: Use Appveyor's python
set PATH=C:\Python27;C:\Python27\Scripts;%PATH%
set PATH=C:\Python35;C:\Python35\Scripts;%PATH%
copy c:\Python35\python.exe c:\Python35\python3.exe
pip2 install neovim || goto error
pip3 install neovim || goto error

mkdir .deps
cd .deps
cmake -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release ..\third-party\ || goto :error
mingw32-make VERBOSE=1 || goto :error
cd ..

:: Build Neovim
mkdir build
cd build
cmake -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release -DBUSTED_OUTPUT_TYPE=gtest -DGPERF_PRG="C:\msys64\usr\bin\gperf.exe" .. || goto :error
mingw32-make VERBOSE=1 || goto :error
bin\nvim --version || goto :error

:: Functional tests
mingw32-make functionaltest VERBOSE=1 || goto :error

:: Build artifacts
cpack -G ZIP -C Release
if defined APPVEYOR_REPO_TAG_NAME cpack -G NSIS -C Release

goto :EOF
:error
exit /b %errorlevel%
