param([Parameter(Mandatory)][ValidateSet('x64', 'ARM64')][string]$Platform)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$architecture = $Platform.ToLowerInvariant()
$root = Split-Path $PSScriptRoot -Parent
$packages = Join-Path $root 'artifacts/packages'
$verification = Join-Path $root "artifacts/install-smoke/$architecture"
$installer = @(Get-ChildItem $packages -Filter "NornaStudio-windows-$architecture-*-setup.exe")
$portable = @(Get-ChildItem $packages -Filter "NornaStudio-windows-$architecture-*-portable.zip")
if ($installer.Count -ne 1 -or $portable.Count -ne 1) { throw 'Expected exactly one installer and portable archive.' }
$acceptance = Join-Path $env:LOCALAPPDATA "NornaKit/Acceptance/$([Guid]::NewGuid())"
New-Item $acceptance -ItemType Directory -Force | Out-Null
$install = Join-Path $acceptance 'Installed Studio'
$process = Start-Process $installer[0].FullName -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/DIR=`"$install`"" -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "Installer failed with $($process.ExitCode)." }
$run = {
    param([string]$Executable, [string]$Output)
    $env:NORNA_STUDIO_SMOKE = $Output
    $env:DOTNET_ROOT = Join-Path $acceptance 'no-global-dotnet'
    $env:DOTNET_MULTILEVEL_LOOKUP = '0'
    $app = Start-Process $Executable -PassThru
    if (-not $app.WaitForExit(90000)) { $app.Kill(); throw 'Installed or portable Studio startup timed out.' }
    if ($app.ExitCode -ne 0 -or -not (Test-Path (Join-Path $Output 'studio.json'))) { throw 'Installed or portable Studio did not pass startup verification.' }
}
& $run (Join-Path $install 'NornaStudio.exe') (Join-Path $verification 'installed')
$uninstaller = @(Get-ChildItem $install -Filter 'unins*.exe')
if ($uninstaller.Count -ne 1) { throw 'The current user installation has no unique uninstaller.' }
$process = Start-Process $uninstaller[0].FullName -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART' -Wait -PassThru
if ($process.ExitCode -ne 0 -or (Test-Path (Join-Path $install 'NornaStudio.exe'))) { throw 'Studio uninstallation failed.' }
$portableDirectory = Join-Path $acceptance 'Portable Studio'
Expand-Archive $portable[0].FullName $portableDirectory
& $run (Join-Path $portableDirectory 'NornaStudio.exe') (Join-Path $verification 'portable')
Remove-Item $acceptance -Recurse -Force
Remove-Item Env:NORNA_STUDIO_SMOKE
Write-Host "Verified $architecture current user installation, removal and portable startup."
