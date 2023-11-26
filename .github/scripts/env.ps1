# This script enables Developer Command Prompt
# See https://github.com/microsoft/vswhere/wiki/Start-Developer-Command-Prompt#using-powershell
$installationPath = vswhere.exe -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ($installationPath -and (Test-Path "$installationPath\Common7\Tools\vsdevcmd.bat")) {
  & "${env:COMSPEC}" /s /c "`"$installationPath\Common7\Tools\vsdevcmd.bat`" -arch=x64 -no_logo && set" | ForEach-Object {
    $name, $value = $_ -split '=', 2
    "$name=$value" >> $env:GITHUB_ENV
  }
}
