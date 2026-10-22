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
Copy-Item (Join-Path $repository 'LICENSE') (Join-Path $PublishDirectory 'NornaKit-LICENSE.txt')
Copy-Item (Join-Path $repository 'THIRD_PARTY_NOTICES.md') $PublishDirectory
$assets = Get-Content (Join-Path $root 'src/NornaStudio/obj/project.assets.json') -Raw | ConvertFrom-Json
$licenseDirectory = Join-Path $PublishDirectory 'licenses'
New-Item $licenseDirectory -ItemType Directory -Force | Out-Null
$packageRoots = @($assets.packageFolders.PSObject.Properties.Name)
$copyLicense = {
    param([string]$PackageDirectory, [string]$Name)
    $destination = Join-Path $licenseDirectory $Name
    New-Item $destination -ItemType Directory -Force | Out-Null
    Get-ChildItem $PackageDirectory -File | Where-Object { $_.Name -match '^(LICENSE|COPYING|NOTICE|THIRD.PARTY)' -or $_.Extension -eq '.nuspec' } | Copy-Item -Destination $destination
    foreach ($folder in @('license', 'licenses')) {
        $source = Join-Path $PackageDirectory $folder
        if (Test-Path $source) { Copy-Item $source $destination -Recurse -Force }
    }
}
foreach ($library in $assets.libraries.PSObject.Properties) {
    if ($library.Value.type -ne 'package') { continue }
    foreach ($packageRoot in $packageRoots) {
        $package = Join-Path $packageRoot $library.Value.path
        if (Test-Path $package) { & $copyLicense $package ($library.Name -replace '/', '-'); break }
    }
}
$runtimeConfig = Get-Content (Join-Path $PublishDirectory 'NornaStudio.runtimeconfig.json') -Raw | ConvertFrom-Json
$runtime = @($runtimeConfig.runtimeOptions.includedFrameworks | Where-Object { $_.name -eq 'Microsoft.NETCore.App' })[0]
foreach ($packageRoot in $packageRoots) {
    $package = Join-Path $packageRoot "microsoft.netcore.app.runtime.win-$architecture/$($runtime.version)"
    if (Test-Path $package) { & $copyLicense $package "dotnet-$($runtime.version)-$architecture"; break }
}
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
