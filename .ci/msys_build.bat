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
mingw32-make VERBOSE=1 || goto :error
bin\nvim --version || goto :error
cd ..

goto :EOF
:error
exit /b %errorlevel%
