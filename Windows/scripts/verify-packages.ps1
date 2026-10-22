param(
    [Parameter(Mandatory)][ValidateSet('x64', 'ARM64')][string]$Platform,
    [string]$PackageDirectory = 'artifacts/nuget',
    [string]$Version = '0.1.0'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($Version -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$') { throw 'Invalid package version.' }
$packageSource = (Resolve-Path $PackageDirectory).Path
$root = Split-Path $PSScriptRoot -Parent
$consumer = Join-Path $root "artifacts/package-consumer-$($Platform.ToLowerInvariant())"
New-Item $consumer -ItemType Directory -Force | Out-Null
$config = @'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="local" value="@PACKAGES@" />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
  </packageSources>
  <packageSourceMapping>
    <packageSource key="local"><package pattern="NornaKit.*" /></packageSource>
    <packageSource key="nuget.org"><package pattern="*" /></packageSource>
  </packageSourceMapping>
</configuration>
'@
$config.Replace('@PACKAGES@', [System.Security.SecurityElement]::Escape($packageSource)) | Set-Content (Join-Path $consumer 'NuGet.Config') -Encoding utf8
$project = @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0-windows10.0.26100.0</TargetFramework>
    <SupportedOSPlatformVersion>10.0.22000.0</SupportedOSPlatformVersion>
    <OutputType>Exe</OutputType>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <ManagePackageVersionsCentrally>false</ManagePackageVersionsCentrally>
    <RestorePackagesWithLockFile>false</RestorePackagesWithLockFile>
    <RuntimeIdentifier>win-@ARCH@</RuntimeIdentifier>
    <WindowsPackageType>None</WindowsPackageType>
    <SelfContained>true</SelfContained>
    <WindowsAppSDKSelfContained>true</WindowsAppSDKSelfContained>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="NornaKit.Windows" Version="[@VERSION@]" />
  </ItemGroup>
</Project>
'@
$project.Replace('@ARCH@', $Platform.ToLowerInvariant()).Replace('@VERSION@', $Version) | Set-Content (Join-Path $consumer 'Consumer.csproj') -Encoding utf8
@'
using Microsoft.Graphics.Canvas;
using NornaKit;
using NornaKit.Windows;

WinRT.ComWrappersSupport.InitializeComWrappers();
var diagram = await WindowsDiagramRenderer.Create().RenderAsync("flowchart LR\n A[NuGet 中文] --> B[Native]");
if (diagram.Type != "flowchart" || diagram.Scene.Nodes.Length != 2) throw new InvalidOperationException("The packaged renderer lost diagram semantics.");
var palette = WindowsPalette.Resolve(CanvasAppearance.Light);
var svg = SvgExporter.Export(diagram.Scene, palette);
if (!svg.Contains("NuGet", StringComparison.Ordinal)) throw new InvalidOperationException("The packaged SVG exporter lost source text.");
using var device = new CanvasDevice(forceSoftwareRenderer: true);
var png = await new DiagramExporter(device).ExportAsync(diagram.Scene, palette);
if (png.Length < 8 || !png.AsSpan(0, 8).SequenceEqual(new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 })) throw new InvalidOperationException("The packaged native exporter did not produce PNG.");
Console.WriteLine($"Verified independent NuGet consumer: {diagram.Type}, {diagram.Width} x {diagram.Height}, {png.Length} PNG bytes.");
'@ | Set-Content (Join-Path $consumer 'Program.cs') -Encoding utf8
& dotnet restore (Join-Path $consumer 'Consumer.csproj') "-p:Platform=$Platform" --configfile (Join-Path $consumer 'NuGet.Config')
if ($LASTEXITCODE -ne 0) { throw 'Independent NuGet consumer restore failed.' }
& dotnet publish (Join-Path $consumer 'Consumer.csproj') --no-restore -c Release "-p:Platform=$Platform" -o (Join-Path $consumer 'publish')
if ($LASTEXITCODE -ne 0) { throw 'Independent NuGet consumer build failed.' }
& (Join-Path $consumer 'publish/Consumer.exe')
if ($LASTEXITCODE -ne 0) { throw 'Independent NuGet consumer execution failed.' }
