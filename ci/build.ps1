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

function exitIfFailed() {
  if ($LastExitCode -ne 0) {
    exit $LastExitCode
  }
}

$installationPath = vswhere.exe -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ($installationPath -and (Test-Path "$installationPath\Common7\Tools\vsdevcmd.bat")) {
  & "${env:COMSPEC}" /s /c "`"$installationPath\Common7\Tools\vsdevcmd.bat`" -arch=x64 -no_logo && set" | ForEach-Object {
    $name, $value = $_ -split '=', 2
    Set-Content env:\"$name" $value
  }
}

function BuildDeps {
  cmake -S "$projectDir\cmake.deps" -B $env:DEPS_BUILD_DIR -G Ninja -DCMAKE_BUILD_TYPE='RelWithDebInfo'; exitIfFailed
  cmake --build $env:DEPS_BUILD_DIR; exitIfFailed
}

function Build {
  cmake -S $projectDir -B $buildDir -G Ninja -DCMAKE_BUILD_TYPE='RelWithDebInfo' -DDEPS_PREFIX="$env:DEPS_PREFIX"; exitIfFailed
  cmake --build $buildDir; exitIfFailed
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
}

function TestOld {
  # Old tests
  # Add MSYS to path, required for e.g. `find` used in test scripts.
  # But would break functionaltests, where its `more` would be used then.
  $OldPath = $env:PATH
  $env:PATH = "C:\msys64\usr\bin;$env:PATH"
  & "C:\msys64\mingw64\bin\mingw32-make.exe" -C $(Convert-Path $projectDir\src\nvim\testdir) VERBOSE=1; exitIfFailed
  $env:PATH = $OldPath
}

function Package {
  cmake -S $projectDir -B $buildDir -G Ninja -DCMAKE_BUILD_TYPE='RelWithDebInfo' -DDEPS_PREFIX="$env:DEPS_PREFIX"; exitIfFailed
  cmake --build $buildDir --target package; exitIfFailed
}

if ($PSCmdlet.ParameterSetName) {
  & (Get-ChildItem "Function:$($PSCmdlet.ParameterSetName)")
  exit
}
