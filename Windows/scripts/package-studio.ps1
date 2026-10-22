param(
    [Parameter(Mandatory)][ValidateSet('x64', 'ARM64')][string]$Platform,
    [string]$PublishDirectory,
    [string]$OutputDirectory = 'artifacts/packages',
    [string]$Compiler = $env:NORNA_ISCC
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path $PSScriptRoot -Parent
$repository = Split-Path $root -Parent
[xml]$properties = Get-Content (Join-Path $root 'StudioVersion.props') -Raw
$version = [string]$properties.Project.PropertyGroup.Version
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw 'StudioVersion.props must contain a stable semantic version.' }
$architecture = $Platform.ToLowerInvariant()
if (-not $PublishDirectory) {
    $PublishDirectory = Join-Path $root "artifacts/studio-$architecture"
    & dotnet restore (Join-Path $root 'src/NornaStudio') "-p:Platform=$Platform" --locked-mode
    if ($LASTEXITCODE -ne 0) { throw 'Studio dependency restore failed.' }
    & dotnet publish (Join-Path $root 'src/NornaStudio') --no-restore -c Release "-p:Platform=$Platform" -o $PublishDirectory
    if ($LASTEXITCODE -ne 0) { throw 'Studio publication failed.' }
}
$PublishDirectory = (Resolve-Path $PublishDirectory).Path
foreach ($file in @('NornaStudio.exe', 'coreclr.dll', 'Microsoft.UI.Xaml.dll')) {
    if (-not (Test-Path (Join-Path $PublishDirectory $file))) { throw "Self contained publication is missing $file." }
}
New-Item $OutputDirectory -ItemType Directory -Force | Out-Null
$OutputDirectory = (Resolve-Path $OutputDirectory).Path
$commit = & git -C $repository rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Cannot determine the source commit.' }
Copy-Item (Join-Path $repository 'LICENSE') (Join-Path $PublishDirectory 'LICENSE.txt')
$manifest = @{ product = 'Norna Studio'; version = $version; architecture = $architecture; commit = $commit; minimumWindowsBuild = 22000; runtimeDeployment = 'self-contained'; builtAt = [DateTime]::UtcNow.ToString('O') }
$manifest | ConvertTo-Json | Set-Content (Join-Path $PublishDirectory 'build-info.json') -Encoding utf8
$base = "NornaStudio-windows-$architecture-$version"
$zip = Join-Path $OutputDirectory "$base-portable.zip"
Compress-Archive -Path (Join-Path $PublishDirectory '*') -DestinationPath $zip -Force
if (-not $Compiler) { $Compiler = (Get-Command ISCC.exe -ErrorAction Stop).Source }
& $Compiler "/DStudioVersion=$version" "/DArchitecture=$architecture" "/DSourceDirectory=$PublishDirectory" "/DOutputDirectory=$OutputDirectory" (Join-Path $root 'installer/studio.iss')
if ($LASTEXITCODE -ne 0) { throw 'Inno Setup compilation failed.' }
Get-ChildItem $OutputDirectory -File | Where-Object { $_.Name -like "$base*.exe" -or $_.Name -like "$base*.zip" } | ForEach-Object {
    $hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $($_.Name)" | Set-Content ($_.FullName + '.sha256') -Encoding ascii
}
$manifest | ConvertTo-Json | Set-Content (Join-Path $OutputDirectory "$base-build-info.json") -Encoding utf8
