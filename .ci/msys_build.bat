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

mkdir build
cd build
cmake -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release .. || goto :error
:: FIXME(equalsraf): for now just build nvim and copy DLLs.
:: We can't generate the helptags just yet (#810 fixes this)
mingw32-make nvim_dll_deps VERBOSE=1 || goto :error
bin\nvim --version || goto :error
cd ..

goto :EOF
:error
exit /b %errorlevel%
