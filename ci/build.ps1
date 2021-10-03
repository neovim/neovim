param([switch]$NoTests)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$env:CONFIGURATION -match '^(?<compiler>\w+)_(?<bits>32|64)(?:-(?<option>\w+))?$'
$compiler = $Matches.compiler
$compileOption = if ($Matches -contains 'option') {$Matches.option} else {''}
$bits = $Matches.bits
$cmakeBuildType = $(if ($env:CMAKE_BUILD_TYPE -ne $null) {$env:CMAKE_BUILD_TYPE} else {'RelWithDebInfo'});
$buildDir = [System.IO.Path]::GetFullPath("$(pwd)")
$depsCmakeVars = @{
  CMAKE_BUILD_TYPE = $cmakeBuildType;
}
$nvimCmakeVars = @{
  CMAKE_BUILD_TYPE = $cmakeBuildType;
  BUSTED_OUTPUT_TYPE = 'nvim';
  DEPS_PREFIX=$(if ($env:DEPS_PREFIX -ne $null) {$env:DEPS_PREFIX} else {".deps/usr"});
}
if ($env:DEPS_BUILD_DIR -eq $null) {
  $env:DEPS_BUILD_DIR = ".deps";
}
$uploadToCodeCov = $false

function exitIfFailed() {
  if ($LastExitCode -ne 0) {
    exit $LastExitCode
  }
}

if (-not $NoTests) {
  node --version
  npm.cmd --version
}

if (-Not (Test-Path -PathType container $env:DEPS_BUILD_DIR)) {
  write-host "cache dir not found: $($env:DEPS_BUILD_DIR)"
  mkdir $env:DEPS_BUILD_DIR
} else {
  write-host "cache dir $($env:DEPS_BUILD_DIR) size: $(Get-ChildItem $env:DEPS_BUILD_DIR -recurse | Measure-Object -property length -sum | Select -expand sum)"
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
    $env:GCOV = "C:\msys64\mingw$bits\bin\gcov"

    # Setup/build Lua coverage.
    $env:USE_LUACOV = 1
    $env:BUSTED_ARGS = "--coverage"
  }
  # These are native MinGW builds, but they use the toolchain inside
  # MSYS2, this allows using all the dependencies and tools available
  # in MSYS2, but we cannot build inside the MSYS2 shell.
  $cmakeGenerator = 'Ninja'
  $cmakeGeneratorArgs = '-v'
  $mingwPackages = @('ninja', 'cmake', 'diffutils').ForEach({
    "mingw-w64-$arch-$_"
  })

  # Add MinGW to the PATH
  $env:PATH = "C:\msys64\mingw$bits\bin;$env:PATH"

  # Avoid pacman "warning" which causes non-zero return code. https://github.com/open62541/open62541/issues/2068
  & C:\msys64\usr\bin\mkdir -p /var/cache/pacman/pkg

  # Build third-party dependencies
  C:\msys64\usr\bin\bash -lc "pacman --verbose --noconfirm -Syu" ; exitIfFailed
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

if (-not $NoTests) {
  # Setup python (use AppVeyor system python)

  # Disambiguate python3, if needed
  if (-not (Test-Path -Path C:\hostedtoolcache\windows\Python\3.5.4\x64\python3.exe) ) {
    move C:\hostedtoolcache\windows\Python\3.5.4\x64\python.exe C:\hostedtoolcache\windows\Python\3.5.4\x64\python3.exe
  }
  $env:PATH = "C:\hostedtoolcache\windows\Python\2.7.18\x64;C:\hostedtoolcache\windows\Python\3.5.4\x64;$env:PATH"

  python -m pip install pynvim ; exitIfFailed
  python3 -m pip install pynvim ; exitIfFailed
  # Sanity check
  python  -c "import pynvim; print(str(pynvim))" ; exitIfFailed
  python3 -c "import pynvim; print(str(pynvim))" ; exitIfFailed

  gem.cmd install --pre neovim
  Get-Command -CommandType Application neovim-ruby-host.bat

  npm.cmd install -g neovim
  Get-Command -CommandType Application neovim-node-host.cmd
  npm.cmd link neovim
}

if ($compiler -eq 'MSVC') {
  # Required for LuaRocks (https://github.com/luarocks/luarocks/issues/1039#issuecomment-507296940).
  $env:VCINSTALLDIR = "C:/Program Files (x86)/Microsoft Visual Studio/2017/Community/VC/Tools/MSVC/14.16.27023/"
}

function convertToCmakeArgs($vars) {
  return $vars.GetEnumerator() | foreach { "-D$($_.Key)=$($_.Value)" }
}

cd $env:DEPS_BUILD_DIR
cmake -G $cmakeGenerator $(convertToCmakeArgs($depsCmakeVars)) "$buildDir/third-party/" ; exitIfFailed
cmake --build . --config $cmakeBuildType -- $cmakeGeneratorArgs ; exitIfFailed
cd $buildDir

# Build Neovim
mkdir build
cd build
cmake -G $cmakeGenerator $(convertToCmakeArgs($nvimCmakeVars)) .. ; exitIfFailed
cmake --build . --config $cmakeBuildType -- $cmakeGeneratorArgs ; exitIfFailed
.\bin\nvim --version ; exitIfFailed

# Ensure that the "win32" feature is set.
.\bin\nvim -u NONE --headless -c 'exe !has(\"win32\").\"cq\"' ; exitIfFailed

if ($env:USE_LUACOV -eq 1) {
  & $env:DEPS_PREFIX\luarocks\luarocks.bat install cluacov
}

if (-not $NoTests) {
  # Functional tests
  # The $LastExitCode from MSBuild can't be trusted
  $failed = $false

  # Run only this test file:
  # $env:TEST_FILE = "test\functional\foo.lua"
  cmake --build . --config $cmakeBuildType --target functionaltest -- $cmakeGeneratorArgs 2>&1 |
    foreach { $failed = $failed -or
      $_ -match 'functional tests failed with error'; $_ }

  if ($uploadToCodecov) {
    if ($env:USE_LUACOV -eq 1) {
      & $env:DEPS_PREFIX\bin\luacov.bat
    }
    bash -l /c/projects/neovim/ci/common/submit_coverage.sh functionaltest
  }
  if ($failed) {
    exit $LastExitCode
  }

  # Old tests
  # Add MSYS to path, required for e.g. `find` used in test scripts.
  # But would break functionaltests, where its `more` would be used then.
  $OldPath = $env:PATH
  $env:PATH = "C:\msys64\usr\bin;$env:PATH"
  & "C:\msys64\mingw$bits\bin\mingw32-make.exe" -C $(Convert-Path ..\src\nvim\testdir) VERBOSE=1 ; exitIfFailed
  $env:PATH = $OldPath

  if ($uploadToCodecov) {
    bash -l /c/projects/neovim/ci/common/submit_coverage.sh oldtest
  }
}

# Build artifacts
cpack -G ZIP -C RelWithDebInfo
if ($env:APPVEYOR_REPO_TAG_NAME -ne $null) {
  cpack -G NSIS -C RelWithDebInfo
}
