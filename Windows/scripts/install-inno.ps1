$ErrorActionPreference = 'Stop'
$directory = Join-Path $env:RUNNER_TEMP 'norna-inno'
New-Item $directory -ItemType Directory -Force | Out-Null
$installer = Join-Path $directory 'innosetup-6.7.3.exe'
Invoke-WebRequest 'https://github.com/jrsoftware/issrc/releases/download/is-6_7_3/innosetup-6.7.3.exe' -OutFile $installer
$expected = '9c73c3bae7ed48d44112a0f48e66742c00090bdb5bef71d9d3c056c66e97b732'
if ((Get-FileHash $installer -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) { throw 'The official Inno Setup installer checksum changed.' }
$process = Start-Process $installer -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/DIR=$directory/compiler" -PassThru -Wait
if ($process.ExitCode -ne 0) { throw "Inno Setup installation failed: $($process.ExitCode)." }
"NORNA_ISCC=$directory/compiler/ISCC.exe" | Out-File $env:GITHUB_ENV -Encoding utf8 -Append
