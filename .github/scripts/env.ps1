# This script enables Developer Command Prompt
# See https://github.com/microsoft/vswhere/wiki/Start-Developer-Command-Prompt#using-powershell
if ($env:BUILD_ARCH -eq "arm64") {
  $arch = "arm64"
  $installationPath = vswhere.exe -latest -requires Microsoft.VisualStudio.Component.VC.Tools.arm64 -property installationPath
} else {
  $arch = "x64"
  $installationPath = vswhere.exe -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
}

if ($installationPath) {
  & "${env:COMSPEC}" /s /c "`"$installationPath\Common7\Tools\vsdevcmd.bat`" -arch=$arch -no_logo && set" |
    ForEach-Object {
      $name, $value = $_ -split '=', 2
      "$name=$value" >> $env:GITHUB_ENV
    }
}
