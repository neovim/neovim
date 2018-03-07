echo on
if "%CONFIGURATION%" == "MINGW_32" (
  set ARCH=i686
  set BITS=32
) else if "%CONFIGURATION:~0,8%" == "MINGW_64" (
  set ARCH=x86_64
  set BITS=64
  if "%CONFIGURATION%" == "MINGW_64-gcov" (
    set USE_GCOV="-DUSE_GCOV=ON"
  )
) else if "%CONFIGURATION%" == "MSVC_32" (
  set CMAKE_GENERATOR="Visual Studio 15 2017"
) else if "%CONFIGURATION%" == "MSVC_64" (
  set CMAKE_GENERATOR="Visual Studio 15 2017 Win64"
)

if "%CONFIGURATION:~0,5%" == "MINGW" (
  :: These are native MinGW builds, but they use the toolchain inside
  :: MSYS2, this allows using all the dependencies and tools available
  :: in MSYS2, but we cannot build inside the MSYS2 shell.
  set CMAKE_GENERATOR="MinGW Makefiles"
  set CMAKE_GENERATOR_ARGS=VERBOSE=1
  :: Add MinGW to the PATH and remove the Git directory because it
  :: has a conflicting sh.exe
  set "PATH=C:\msys64\mingw%BITS%\bin;C:\Windows\System32;C:\Windows;%PATH:C:\Program Files\Git\usr\bin;=%"
  :: Build third-party dependencies
  C:\msys64\usr\bin\bash -lc "pacman --verbose --noconfirm -Su" || goto :error
  C:\msys64\usr\bin\bash -lc "pacman --verbose --noconfirm --needed -S mingw-w64-%ARCH%-cmake mingw-w64-%ARCH%-perl mingw-w64-%ARCH%-diffutils mingw-w64-%ARCH%-unibilium gperf" || goto :error
) else if "%CONFIGURATION:~0,4%" == "MSVC" (
  set CMAKE_GENERATOR_ARGS=/verbosity:normal
)

:: Setup python (use AppVeyor system python)
C:\Python27\python.exe -m pip install neovim || goto :error
C:\Python35\python.exe -m pip install neovim || goto :error
:: Disambiguate python3
move c:\Python35\python.exe c:\Python35\python3.exe
set PATH=C:\Python35;C:\Python27;%PATH%
:: Sanity check
python  -c "import neovim; print(str(neovim))" || goto :error
python3 -c "import neovim; print(str(neovim))" || goto :error

set PATH=C:\Ruby24\bin;%PATH%
cmd /c gem.cmd install neovim || goto :error
where.exe neovim-ruby-host.bat || goto :error

cmd /c npm.cmd install -g neovim || goto :error
where.exe neovim-node-host.cmd || goto :error

mkdir .deps
cd .deps
cmake -G %CMAKE_GENERATOR% -DCMAKE_BUILD_TYPE=RelWithDebInfo ..\third-party\ || goto :error
cmake --build . -- %CMAKE_GENERATOR_ARGS% || goto :error
cd ..

:: Build Neovim
mkdir build
cd build
cmake -G %CMAKE_GENERATOR% -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUSTED_OUTPUT_TYPE=nvim %USE_GCOV% -DGPERF_PRG="C:\msys64\usr\bin\gperf.exe" .. || goto :error
cmake --build . --config RelWithDebInfo -- %CMAKE_GENERATOR_ARGS% || goto :error
bin\nvim --version || goto :error

:: Functional tests
cmake --build . --config RelWithDebInfo --target functionaltest -- %CMAKE_GENERATOR_ARGS% || goto :error

if defined USE_GCOV (
  C:\msys64\usr\bin\bash -lc "cd /c/projects/neovim; bash <(curl -s https://codecov.io/bash) -c -F functionaltest || echo 'codecov upload failed.'"
)

:: Old tests
setlocal
set PATH=%PATH%;C:\msys64\usr\bin
cmake --build "%~dp0\..\src\nvim\testdir" -- %CMAKE_GENERATOR_ARGS%
endlocal

if defined USE_GCOV (
  C:\msys64\usr\bin\bash -lc "cd /c/projects/neovim; bash <(curl -s https://codecov.io/bash) -c -F oldtest || echo 'codecov upload failed.'"
)

:: The default cpack in the PATH is not CMake
set PATH=C:\Program Files (x86)\CMake\bin\cpack.exe;%PATH%
:: Build artifacts
cpack -G ZIP -C RelWithDebInfo
if defined APPVEYOR_REPO_TAG_NAME cpack -G NSIS -C RelWithDebInfo

goto :EOF
:error
exit /b %errorlevel%
