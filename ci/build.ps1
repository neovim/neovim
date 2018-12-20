$ErrorActionPreference = 'stop'
Set-PSDebug -Strict -Trace 1

$env:CONFIGURATION -match '^(?<compiler>\w+)_(?<bits>32|64)(?:-(?<option>\w+))?$'
$compiler = $Matches.compiler
$compileOption = $Matches.option
$bits = $Matches.bits
$cmakeBuildType = 'RelWithDebInfo'
$depsCmakeVars = @{
  CMAKE_BUILD_TYPE = $cmakeBuildType;
}
$nvimCmakeVars = @{
  CMAKE_BUILD_TYPE = $cmakeBuildType;
  BUSTED_OUTPUT_TYPE = 'nvim';
}
$uploadToCodeCov = $false

# For pull requests, skip some build configurations to save time.
if ($env:APPVEYOR_PULL_REQUEST_HEAD_COMMIT -and $env:CONFIGURATION -match '^(MSVC_64|MINGW_32|MINGW_64-gcov)$') {
  exit 0
}

function exitIfFailed() {
  if ($LastExitCode -ne 0) {
    Set-PSDebug -Off
    exit $LastExitCode
  }
}

if ($compiler -eq 'MINGW') {
  if ($bits -eq 32) {
    $arch = 'i686'
  }
  elseif ($bits -eq 64) {
    $arch = 'x86_64'
  }
  if ($compileOption -eq 'gcov') {
    $nvimCmakeVars['USE_GCOV'] = 'ON'
    $uploadToCodecov = $true
  }
  # These are native MinGW builds, but they use the toolchain inside
  # MSYS2, this allows using all the dependencies and tools available
  # in MSYS2, but we cannot build inside the MSYS2 shell.
  $cmakeGenerator = 'Ninja'
  $cmakeGeneratorArgs = '-v'
  $mingwPackages = @('ninja', 'cmake', 'perl', 'diffutils', 'unibilium').ForEach({
    "mingw-w64-$arch-$_"
  })

  # Add MinGW to the PATH
  $env:PATH = "C:\msys64\mingw$bits\bin;$env:PATH"

  # Avoid pacman "warning" which causes non-zero return code. https://github.com/open62541/open62541/issues/2068
  & C:\msys64\usr\bin\mkdir -p /var/cache/pacman/pkg

  # Build third-party dependencies
  C:\msys64\usr\bin\bash -lc "pacman --verbose --noconfirm -Su" ; exitIfFailed
  C:\msys64\usr\bin\bash -lc "pacman --verbose --noconfirm --needed -S $mingwPackages" ; exitIfFailed
}
elseif ($compiler -eq 'MSVC') {
  $cmakeGeneratorArgs = '/verbosity:normal'
  if ($bits -eq 32) {
    $cmakeGenerator = 'Visual Studio 15 2017'
  }
  elseif ($bits -eq 64) {
    $cmakeGenerator = 'Visual Studio 15 2017 Win64'
  }
}

# Setup python (use AppVeyor system python)
C:\Python27\python.exe -m pip install pynvim ; exitIfFailed
C:\Python35\python.exe -m pip install pynvim ; exitIfFailed
# Disambiguate python3
move c:\Python35\python.exe c:\Python35\python3.exe
$env:PATH = "C:\Python35;C:\Python27;$env:PATH"
# Sanity check
python  -c "import pynvim; print(str(pynvim))" ; exitIfFailed
python3 -c "import pynvim; print(str(pynvim))" ; exitIfFailed

$env:PATH = "C:\Ruby24\bin;$env:PATH"
gem.cmd install neovim
Get-Command -CommandType Application neovim-ruby-host.bat

npm.cmd install -g neovim
Get-Command -CommandType Application neovim-node-host.cmd
npm.cmd link neovim

function convertToCmakeArgs($vars) {
  return $vars.GetEnumerator() | foreach { "-D$($_.Key)=$($_.Value)" }
}

if (-Not (Test-Path -PathType container .deps)) {
  mkdir .deps
}
cd .deps
cmake -G $cmakeGenerator $(convertToCmakeArgs($depsCmakeVars)) ..\third-party\ ; exitIfFailed
cmake --build . --config $cmakeBuildType -- $cmakeGeneratorArgs ; exitIfFailed
cd ..

# Build Neovim
mkdir build
cd build
cmake -G $cmakeGenerator $(convertToCmakeArgs($nvimCmakeVars)) .. ; exitIfFailed
cmake --build . --config $cmakeBuildType -- $cmakeGeneratorArgs ; exitIfFailed
bin\nvim --version ; exitIfFailed

# Functional tests
# The $LastExitCode from MSBuild can't be trusted
$failed = $false
# Temporarily turn off tracing to reduce log file output
Set-PSDebug -Off
cmake --build . --config $cmakeBuildType --target functionaltest -- $cmakeGeneratorArgs 2>&1 |
  foreach { $failed = $failed -or
    $_ -match 'functional tests failed with error'; $_ }
if ($failed) {
  exit $LastExitCode
}
Set-PSDebug -Strict -Trace 1


if ($uploadToCodecov) {
  C:\msys64\usr\bin\bash -lc "cd /c/projects/neovim; bash <(curl -s https://codecov.io/bash) -c -F functionaltest || echo 'codecov upload failed.'"
}

# Old tests
$env:PATH = "C:\msys64\usr\bin;$env:PATH"
& "C:\msys64\mingw$bits\bin\mingw32-make.exe" -C $(Convert-Path ..\src\nvim\testdir) VERBOSE=1

if ($uploadToCodecov) {
  C:\msys64\usr\bin\bash -lc "cd /c/projects/neovim; bash <(curl -s https://codecov.io/bash) -c -F oldtest || echo 'codecov upload failed.'"
}

# Build artifacts
cpack -G ZIP -C RelWithDebInfo
if ($env:APPVEYOR_REPO_TAG_NAME -ne $null) {
  cpack -G NSIS -C RelWithDebInfo
}
