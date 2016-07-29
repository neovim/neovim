:: These are native MinGW builds, but they use the toolchain inside
:: MSYS2, this allows using all the dependencies and tools available
:: in MSYS2, but we cannot build inside the MSYS2 shell.
echo on
if "%TARGET%" == "MINGW_32" (
	set ARCH=i686
	set BITS=32
) else (
	set ARCH=x86_64
	set BITS=64
)
:: We cannot have sh.exe in the PATH (MinGW)
set PATH=%PATH:C:\Program Files\Git\usr\bin;=%
set PATH=C:\msys64\mingw%BITS%\bin;C:\Windows\System32;C:\Windows;%PATH%

C:\msys64\usr\bin\bash -lc "pacman --verbose --noconfirm -Su" || goto :error
C:\msys64\usr\bin\bash -lc "pacman --verbose --noconfirm --needed -S mingw-w64-%ARCH%-cmake mingw-w64-%ARCH%-perl mingw-w64-%ARCH%-python2 mingw-w64-%ARCH%-diffutils" || goto :error

mkdir .deps
cd .deps
cmake -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release ..\third-party\ || goto :error
mingw32-make VERBOSE=1 || goto :error
cd ..

goto :EOF
:error
exit /b %errorlevel%
