[CmdletBinding(DefaultParameterSetName = "Build")]
param(
  [Parameter(ParameterSetName="Build")][switch]$Build,
  [Parameter(ParameterSetName="BuildDeps")][switch]$BuildDeps,
  [Parameter(ParameterSetName="EnsureTestDeps")][switch]$EnsureTestDeps,
  [Parameter(ParameterSetName="Package")][switch]$Package,
  [Parameter(ParameterSetName="Test")][switch]$Test,
  [Parameter(ParameterSetName="TestOld")][switch]$TestOld
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$projectDir = [System.IO.Path]::GetFullPath("$(Get-Location)")
$buildDir = Join-Path -Path $projectDir -ChildPath "build"

# $env:CMAKE_BUILD_TYPE is ignored by cmake when not using ninja
$cmakeBuildType = $(if ($null -ne $env:CMAKE_BUILD_TYPE) {$env:CMAKE_BUILD_TYPE} else {'RelWithDebInfo'});
$depsCmakeVars = @{
  CMAKE_BUILD_TYPE=$cmakeBuildType;
}
$nvimCmakeVars = @{
  CMAKE_BUILD_TYPE=$cmakeBuildType;
  BUSTED_OUTPUT_TYPE = 'nvim';
  DEPS_PREFIX=$(if ($null -ne $env:DEPS_PREFIX) {$env:DEPS_PREFIX} else {".deps/usr"});
}
if ($null -eq $env:DEPS_BUILD_DIR) {
  $env:DEPS_BUILD_DIR = Join-Path -Path $projectDir -ChildPath ".deps"
}
$uploadToCodeCov = $false

function exitIfFailed() {
  if ($LastExitCode -ne 0) {
    exit $LastExitCode
  }
}

function convertToCmakeArgs($vars) {
  return $vars.GetEnumerator() | ForEach-Object { "-D$($_.Key)=$($_.Value)" }
}

$installationPath = vswhere.exe -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ($installationPath -and (Test-Path "$installationPath\Common7\Tools\vsdevcmd.bat")) {
  & "${env:COMSPEC}" /s /c "`"$installationPath\Common7\Tools\vsdevcmd.bat`" -arch=x64 -no_logo && set" | ForEach-Object {
    $name, $value = $_ -split '=', 2
    Set-Content env:\"$name" $value
  }
}

function BuildDeps {

  if (Test-Path -PathType container $env:DEPS_BUILD_DIR) {
    $cachedBuildTypeStr = $(Get-Content $env:DEPS_BUILD_DIR\CMakeCache.txt | Select-String -Pattern "CMAKE_BUILD_TYPE.*=($cmakeBuildType)")
    if (-not $cachedBuildTypeStr) {
      Write-Warning " unable to validate build type from cache dir ${env:DEPS_BUILD_DIR}"
    }
  }

  # we currently can't use ninja for cmake.deps, see #19405
  $depsCmakeGenerator = "Visual Studio 16 2019"
  $depsCmakeGeneratorPlf = "x64"
  cmake -S "$projectDir\cmake.deps" -B $env:DEPS_BUILD_DIR -G $depsCmakeGenerator -A $depsCmakeGeneratorPlf $(convertToCmakeArgs($depsCmakeVars)); exitIfFailed

  $depsCmakeNativeToolOptions= @('/verbosity:normal', '/m')
  cmake --build $env:DEPS_BUILD_DIR --config $cmakeBuildType -- $depsCmakeNativeToolOptions; exitIfFailed
}

function Build {
  cmake -S $projectDir -B $buildDir $(convertToCmakeArgs($nvimCmakeVars)) -G Ninja; exitIfFailed
  cmake --build $buildDir --config $cmakeBuildType; exitIfFailed
}

function EnsureTestDeps {
  & $buildDir\bin\nvim.exe "--version"; exitIfFailed

  # Ensure that the "win32" feature is set.
  & $buildDir\bin\nvim -u NONE --headless -c 'exe !has(\"win32\").\"cq\"' ; exitIfFailed

  python -m pip install pynvim
  # Sanity check
  python -c "import pynvim; print(str(pynvim))"; exitIfFailed

  gem.cmd install --pre neovim
  Get-Command -CommandType Application neovim-ruby-host.bat; exitIfFailed

  node --version
  npm.cmd --version

  npm.cmd install -g neovim; exitIfFailed
  Get-Command -CommandType Application neovim-node-host.cmd; exitIfFailed
  npm.cmd link neovim

  if ($env:USE_LUACOV -eq 1) {
    & $env:DEPS_PREFIX\luarocks\luarocks.bat install cluacov
  }
}

function Test {
  # Functional tests
  # The $LastExitCode from MSBuild can't be trusted
  $failed = $false

  # Run only this test file:
  # $env:TEST_FILE = "test\functional\foo.lua"
  cmake --build $buildDir --target functionaltest 2>&1 |
    ForEach-Object { $failed = $failed -or
      $_ -match 'functional tests failed with error'; $_ }

  if ($failed) {
    exit $LastExitCode
  }

  if (-not $uploadToCodecov) {
    return
  }
  if ($env:USE_LUACOV -eq 1) {
    & $env:DEPS_PREFIX\bin\luacov.bat
  }
  bash -l /c/projects/neovim/ci/common/submit_coverage.sh functionaltest
}

function TestOld {
  # Old tests
  # Add MSYS to path, required for e.g. `find` used in test scripts.
  # But would break functionaltests, where its `more` would be used then.
  $OldPath = $env:PATH
  $env:PATH = "C:\msys64\usr\bin;$env:PATH"
  & "C:\msys64\mingw64\bin\mingw32-make.exe" -C $(Convert-Path $projectDir\src\nvim\testdir) VERBOSE=1; exitIfFailed
  $env:PATH = $OldPath

  if ($uploadToCodecov) {
    bash -l /c/projects/neovim/ci/common/submit_coverage.sh oldtest
  }
}


function Package {
  cmake -S $projectDir -B $buildDir $(convertToCmakeArgs($nvimCmakeVars)) -G Ninja; exitIfFailed
  cmake --build $buildDir --target package; exitIfFailed
}

if ($PSCmdlet.ParameterSetName) {
  & (Get-ChildItem "Function:$($PSCmdlet.ParameterSetName)")
  exit
}
