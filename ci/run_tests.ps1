Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$env:CONFIGURATION -match '^(?<compiler>\w+)_(?<bits>32|64)(?:-(?<option>\w+))?$'
$bits = $Matches.bits
$cmakeBuildType = $(if ($env:CMAKE_BUILD_TYPE -ne $null) {$env:CMAKE_BUILD_TYPE} else {'RelWithDebInfo'});
$nvimCmakeVars = @{
  CMAKE_BUILD_TYPE = $cmakeBuildType;
  BUSTED_OUTPUT_TYPE = 'nvim';
  DEPS_PREFIX=$(if ($env:DEPS_PREFIX -ne $null) {$env:DEPS_PREFIX} else {".deps/usr"});
}
if ($env:DEPS_BUILD_DIR -eq $null) {
  $env:DEPS_BUILD_DIR = ".deps";
}

$uploadToCodecov = 0
$bits = 64

function convertToCmakeArgs($vars) {
  return $vars.GetEnumerator() | ForEach-Object { "-D$($_.Key)=$($_.Value)" }
}

function exitIfFailed() {
  if ($LastExitCode -ne 0) {
    exit $LastExitCode
  }
}

.\build\bin\nvim --version ; exitIfFailed

# Ensure that the "win32" feature is set.
.\build\bin\nvim -u NONE --headless -c 'exe !has(\"win32\").\"cq\"' ; exitIfFailed

if ($env:USE_LUACOV -eq 1) {
    $nvimCmakeVars['USE_GCOV'] = 'ON'
    $uploadToCodecov = $true
    $env:GCOV = "C:\msys64\mingw$bits\bin\gcov"

    # Setup/build Lua coverage.
    $env:BUSTED_ARGS = "--coverage"
  & $env:DEPS_PREFIX\luarocks\luarocks.bat install cluacov
}

function ensureClients() {
  python -m ensurepip
  python -m pip install pynvim ; exitIfFailed
# Sanity check
  python  -c "import pynvim; print(str(pynvim))" ; exitIfFailed

  gem.cmd install --pre neovim
  Get-Command -CommandType Application neovim-ruby-host.bat

  node --version
  npm.cmd --version

  npm.cmd install -g neovim
  Get-Command -CommandType Application neovim-node-host.cmd
  npm.cmd link neovim
}

# Functional tests
# The $LastExitCode from MSBuild can't be trusted
$failed = $false

# Run only this test file:
# $env:TEST_FILE = "test\functional\foo.lua"
cmake --build build --config $cmakeBuildType --target functionaltest -- $env:CMAKE_GENERATORA_RGS 2>&1 |
  ForEach-Object { $failed = $failed -or
    $_ -match 'functional tests failed with error'; $_ }

if ($uploadToCodecov -eq 1) {
  & $env:DEPS_PREFIX\bin\luacov.bat
  bash -l "./ci/common/submit_coverage.sh" functionaltest
}
if ($failed) {
  exit $LastExitCode
}

# Old tests
# Add MSYS to path, required for e.g. `find` used in test scripts.
# But would break functionaltests, where its `more` would be used then.
$OldPath = $env:PATH

if (Get-Command -Name "ming32-make" -ErrorAction SilentlyContinue) {
  $env:PATH = "C:\msys64\usr\bin;C:\msys64\mingw$bits\bin;$env:PATH"
}

& mingw32-make -C ".\src\nvim\testdir" VERBOSE=1 ; exitIfFailed

$env:PATH = $OldPath

if ($uploadToCodecov) {
  bash -l "./ci/common/submit_coverage.sh"  oldtest
}

