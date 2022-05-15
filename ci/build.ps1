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

$cmakeGeneratorArgs = '/verbosity:normal'
$cmakeGenerator = 'Visual Studio 16 2019'

$installationPath = vswhere.exe -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ($installationPath -and (test-path "$installationPath\Common7\Tools\vsdevcmd.bat")) {
  & "${env:COMSPEC}" /s /c "`"$installationPath\Common7\Tools\vsdevcmd.bat`" -arch=x${bits} -no_logo && set" | foreach-object {
    $name, $value = $_ -split '=', 2
    set-content env:\"$name" $value
  }
}

if (-not $NoTests) {
  python -m ensurepip
  python -m pip install pynvim ; exitIfFailed
  # Sanity check
  python  -c "import pynvim; print(str(pynvim))" ; exitIfFailed

  gem.cmd install --pre neovim
  Get-Command -CommandType Application neovim-ruby-host.bat

  npm.cmd install -g neovim
  Get-Command -CommandType Application neovim-node-host.cmd
  npm.cmd link neovim
}

function convertToCmakeArgs($vars) {
  return $vars.GetEnumerator() | foreach { "-D$($_.Key)=$($_.Value)" }
}

cd $env:DEPS_BUILD_DIR
if ($bits -eq 32) {
  cmake -G $cmakeGenerator -A Win32 $(convertToCmakeArgs($depsCmakeVars)) "$buildDir/third-party/" ; exitIfFailed
} else {
  cmake -G $cmakeGenerator -A x64 $(convertToCmakeArgs($depsCmakeVars)) "$buildDir/third-party/" ; exitIfFailed
}
cmake --build . --config $cmakeBuildType -- $cmakeGeneratorArgs ; exitIfFailed
cd $buildDir

# Build Neovim
mkdir build
cd build
if ($bits -eq 32) {
  cmake -G $cmakeGenerator -A Win32 $(convertToCmakeArgs($nvimCmakeVars)) .. ; exitIfFailed
} else {
  cmake -G $cmakeGenerator -A x64 $(convertToCmakeArgs($nvimCmakeVars)) .. ; exitIfFailed
}
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

# Ensure choco's cpack is not in PATH otherwise, it conflicts with CMake's
if (Test-Path -Path $env:ChocolateyInstall\bin\cpack.exe) {
  Remove-Item -Path $env:ChocolateyInstall\bin\cpack.exe -Force
}

# Build artifacts
cpack -C $cmakeBuildType
