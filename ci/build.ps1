$ErrorActionPreference = 'stop'
Set-PSDebug -Strict -Trace 1

$isPullRequest = ($env:APPVEYOR_PULL_REQUEST_HEAD_COMMIT -ne $null)
$env:CONFIGURATION -match '^(?<compiler>\w+)_(?<bits>32|64)(?:-(?<option>\w+))?$'
$compiler = $Matches.compiler
$compileOption = $Matches.option
$bits = $Matches.bits
$cmakeBuildType = $(if ($env:CMAKE_BUILD_TYPE -ne $null) {$env:CMAKE_BUILD_TYPE} else {'RelWithDebInfo'});
$buildDir = [System.IO.Path]::GetFullPath("$(pwd)")
$depsCmakeVars = @{
  CMAKE_BUILD_TYPE = $cmakeBuildType;
}
$nvimCmakeVars = @{
  CMAKE_BUILD_TYPE = $cmakeBuildType;
  BUSTED_OUTPUT_TYPE = 'nvim';
  DEPS_BUILD_DIR=$(if ($env:DEPS_BUILD_DIR -ne $null) {$env:DEPS_BUILD_DIR} else {".deps"});
  DEPS_PREFIX=$(if ($env:DEPS_PREFIX -ne $null) {$env:DEPS_PREFIX} else {".deps/usr"});
}
$uploadToCodeCov = $false

function exitIfFailed() {
  if ($LastExitCode -ne 0) {
    Set-PSDebug -Off
    exit $LastExitCode
  }
}

if (-Not (Test-Path -PathType container $nvimCmakeVars["DEPS_BUILD_DIR"])) {
  write-host "cache dir not found: $($nvimCmakeVars['DEPS_BUILD_DIR'])"
  mkdir $nvimCmakeVars["DEPS_BUILD_DIR"]
} else {
  write-host "cache dir $($nvimCmakeVars['DEPS_BUILD_DIR']) size: $(Get-ChildItem $nvimCmakeVars['DEPS_BUILD_DIR'] -recurse | Measure-Object -property length -sum | Select -expand sum)"
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
  }
  # These are native MinGW builds, but they use the toolchain inside
  # MSYS2, this allows using all the dependencies and tools available
  # in MSYS2, but we cannot build inside the MSYS2 shell.
  $cmakeGenerator = 'Ninja'
  $cmakeGeneratorArgs = '-v'
  $mingwPackages = @('ninja', 'cmake', 'perl', 'diffutils').ForEach({
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

cd $nvimCmakeVars["DEPS_BUILD_DIR"]
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

# Functional tests
# The $LastExitCode from MSBuild can't be trusted
$failed = $false
# Temporarily turn off tracing to reduce log file output
Set-PSDebug -Off
cmake --build . --config $cmakeBuildType --target functionaltest -- $cmakeGeneratorArgs 2>&1 |
  foreach { $failed = $failed -or
    $_ -match 'functional tests failed with error'; $_ }
if ($failed) {
  if ($uploadToCodecov) {
    bash -l /c/projects/neovim/ci/common/submit_coverage.sh functionaltest
  }
  exit $LastExitCode
}
Set-PSDebug -Strict -Trace 1


if ($uploadToCodecov) {
  bash -l /c/projects/neovim/ci/common/submit_coverage.sh functionaltest
}

# Old tests
# Add MSYS to path, required for e.g. `find` used in test scripts.
# But would break functionaltests, where its `more` would be used then.
$env:PATH = "C:\msys64\usr\bin;$env:PATH"
& "C:\msys64\mingw$bits\bin\mingw32-make.exe" -C $(Convert-Path ..\src\nvim\testdir) VERBOSE=1

if ($uploadToCodecov) {
  bash -l /c/projects/neovim/ci/common/submit_coverage.sh oldtest
}

# Build artifacts
cpack -G ZIP -C RelWithDebInfo
if ($env:APPVEYOR_REPO_TAG_NAME -ne $null) {
  cpack -G NSIS -C RelWithDebInfo
}
