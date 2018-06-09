$ErrorActionPreference = 'stop'
Set-PSDebug -Strict -Trace 1

$uploadToCodecov = $false
if ($env:CONFIGURATION) {
  $env:CONFIGURATION -match '^(?<compiler>\w+)_(?<bits>32|64)(?:-(?<option>\w+))?$'
  $compiler = $Matches.compiler
  $compileOption = $Matches.option
  $bits = $Matches.bits
} else {
  $compiler = 'MSVC'
  $compileOption = ''
  $bits = if ($env:PROCESSOR_ARCHITECTURE -eq 'x86') {32} else {64}
}

$cmakeBuildType = 'RelWithDebInfo'
$depsCmakeVars = @{
  CMAKE_BUILD_TYPE = $cmakeBuildType;
}
$nvimCmakeVars = @{
  CMAKE_BUILD_TYPE = $cmakeBuildType;
  BUSTED_OUTPUT_TYPE = 'nvim';
}

# For pull requests, skip some build configurations to save time.
# if ($env:APPVEYOR_PULL_REQUEST_HEAD_COMMIT -and $env:CONFIGURATION -match '^(MSVC_64|MINGW_32)$') {
#   exit 0
# }

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
  $cmakeGenerator = 'MinGW Makefiles'

  if ($cmakeGenerator -eq 'Ninja') {
    $cmakeGeneratorArgs = @('-v')
  }
  elseif ($cmakeGenerator -eq 'MinGW Makefiles') {
    $env:CC = 'cc'
    $cmakeGeneratorArgs = @('VERBOSE=1')
    @{
      CMAKE_SH = 'CMAKE_SH-NOTFOUND'
      CMAKE_MAKE_PROGRAM = "C:/msys64/mingw$bits/bin/mingw32-make.exe"
    }.GetEnumerator() | ForEach-Object {
      $nvimCmakeVars[$_.Key] = $_.Value
      $depsCmakeVars[$_.Key] = $_.Value
      $cmakeGeneratorArgs += $_.Key + '=' + $_.Value
    }
  }

  # Build third-party dependencies
  $mingwPackages = @('gcc', 'make', 'cmake', 'perl', 'diffutils', 'unibilium').ForEach({
    @('mingw', 'w64', $arch, $_) -join '-'
  })
  C:\msys64\usr\bin\bash -lc "pacman --verbose --noconfirm -Su" ; exitIfFailed
  C:\msys64\usr\bin\bash -lc "pacman --verbose --noconfirm --needed -S $mingwPackages"; exitIfFailed
}
elseif ($compiler -eq 'MSVC') {
  $cmakeGeneratorArgs = '/verbosity:normal'
  $cmakeGenerator = 'Visual Studio 15 2017'
  if ($bits -eq 64) {
    $cmakeGenerator += ' Win64'
  }
}

# Setup python (use AppVeyor system python)
if (Test-Path -PathType Container C:\Python27) {
  $env:PATH = "C:\Python27;$env:PATH"
}
if (Test-Path -PathType Container C:\Python35) {
  # Disambiguate python3
  if (Test-Path C:\Python35\python.exe) {
    Move-Item C:\Python35\python.exe C:\Python35\python3.exe
  }
  $env:PATH = "C:\Python35;$env:PATH"
}
Get-Command -CommandType Application python.exe
python.exe  -m pip install neovim ; exitIfFailed
python.exe  -c "import neovim; print(str(neovim))" ; exitIfFailed
Get-Command -CommandType Application python3.exe
python3.exe -m pip install neovim ; exitIfFailed
python3.exe -c "import neovim; print(str(neovim))" ; exitIfFailed

if (Test-Path -PathType Container C:\Ruby24\bin) {
  $env:PATH = "C:\Ruby24\bin;$env:PATH"
}
Get-Command -CommandType Application gem.cmd
gem.cmd install neovim; exitIfFailed
Get-Command -CommandType Application neovim-ruby-host.bat

Get-Command -CommandType Application npm.cmd
npm.cmd install -g neovim; exitIfFailed
Get-Command -CommandType Application neovim-node-host.cmd
npm.cmd link neovim

function convertToCmakeArgs($vars) {
  return $vars.GetEnumerator() | foreach { "-D$($_.Key)=$($_.Value)" }
}

if ($compiler -eq 'MINGW') {
  $env:PATH = "C:\msys64\mingw$bits\bin;$env:PATH"
}

if (-Not (Test-Path -PathType Container .deps)) {
  mkdir .deps
}
cd .deps
cmake -G $cmakeGenerator $(convertToCmakeArgs($depsCmakeVars)) ..\third-party\ ; exitIfFailed
cmake --build . --config $cmakeBuildType -- $cmakeGeneratorArgs ; exitIfFailed
cd ..

# Build Neovim
if (-Not (Test-Path -PathType Container build)) {
  mkdir build
}
cd build
cmake -G $cmakeGenerator $(convertToCmakeArgs($nvimCmakeVars)) .. ; exitIfFailed
cmake --build . --config $cmakeBuildType -- $cmakeGeneratorArgs ; exitIfFailed
bin\nvim --version ; exitIfFailed

# Functional tests
# The $LastExitCode from MSBuild can't be trusted
# Temporarily turn off tracing to reduce log file output
Set-PSDebug -Off
$failed = $false
cmake --build . --config $cmakeBuildType --target functionaltest -- $cmakeGeneratorArgs 2>&1 |
  foreach { $failed = $failed -or
    $_ -match 'Running functional tests failed with error'; $_ }
if ($failed) {
  exit $LastExitCode
}
Set-PSDebug -Strict -Trace 1


if (Test-Path -PathType Container C:\msys64\usr\bin) {
  if ($uploadToCodecov) {
    C:\msys64\usr\bin\bash -lc "cd /c/projects/neovim; bash <(curl -s https://codecov.io/bash) -c -F functionaltest || echo 'codecov upload failed.'"
  }

  # Old tests
  if (Test-Path "C:\msys64\mingw$bits\bin\mingw32-make.exe") {
    $env:PATH = "C:\msys64\usr\bin;$env:PATH"
    & "C:\msys64\mingw$bits\bin\mingw32-make.exe" -C $(Convert-Path ..\src\nvim\testdir) VERBOSE=1
  }

  if ($uploadToCodecov) {
    C:\msys64\usr\bin\bash -lc "cd /c/projects/neovim; bash <(curl -s https://codecov.io/bash) -c -F oldtest || echo 'codecov upload failed.'"
  }
}

# Build artifacts
cpack -G ZIP -C RelWithDebInfo
if ($env:APPVEYOR_REPO_TAG_NAME -ne $null) {
  cpack -G NSIS -C RelWithDebInfo
}
Set-PSDebug -Off
