echo off

if not defined VS150COMNTOOLS (
  echo error: missing VS150COMNTOOLS environment variable.
  echo        Run this script from the 'Developer Command Prompt'.
  exit /b 1
)

echo on

set CMAKE=%VS150COMNTOOLS%\..\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe

mkdir .deps
cd .deps
"%CMAKE%" -G "Visual Studio 15 2017" "-DCMAKE_BUILD_TYPE=RelWithDebInfo" ..\third-party\
"%CMAKE%" --build . --config RelWithDebInfo -- "/verbosity:normal"
cd ..

