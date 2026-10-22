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

$previewConsumer = Join-Path $root "artifacts/package-preview-consumer-$($Platform.ToLowerInvariant())"
New-Item $previewConsumer -ItemType Directory -Force | Out-Null
$previewProject = $project.Replace('@ARCH@', $Platform.ToLowerInvariant()).Replace('@VERSION@', $Version)
$previewProject = $previewProject.Replace('<OutputType>Exe</OutputType>', '<OutputType>WinExe</OutputType><UseWinUI>true</UseWinUI><ApplicationManifest>app.manifest</ApplicationManifest>')
$previewProject | Set-Content (Join-Path $previewConsumer 'Preview.csproj') -Encoding utf8
Copy-Item (Join-Path $consumer 'NuGet.Config') $previewConsumer
(Get-Content (Join-Path $root 'src/NornaStudio/app.manifest') -Raw).Replace('NornaStudio.Windows', 'NornaKit.PackagePreview') | Set-Content (Join-Path $previewConsumer 'app.manifest') -Encoding utf8
@'
<Application x:Class="PackagePreview.App"
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
    <Application.Resources><ResourceDictionary><ResourceDictionary.MergedDictionaries>
        <XamlControlsResources xmlns="using:Microsoft.UI.Xaml.Controls" />
    </ResourceDictionary.MergedDictionaries></ResourceDictionary></Application.Resources>
</Application>
'@ | Set-Content (Join-Path $previewConsumer 'App.xaml') -Encoding utf8
@'
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using NornaKit;
using NornaKit.Windows;

namespace PackagePreview;
public sealed partial class App : Application
{
    private Window? window;
    public App()
    {
        UnhandledException += (_, args) => File.WriteAllText(Path.Combine(Environment.GetEnvironmentVariable("NORNA_PACKAGE_SMOKE")!, "failure.txt"), args.Exception.ToString());
        InitializeComponent();
    }
    protected override async void OnLaunched(LaunchActivatedEventArgs args)
    {
        var diagram = await WindowsDiagramRenderer.Create().RenderAsync("flowchart LR\n A[NuGet 中文] --> B[Preview]");
        var preview = new DiagramPreview { ForceSoftwareRenderer = true, Scene = diagram.Scene };
        preview.SceneRendered += _ =>
        {
            File.WriteAllText(Path.Combine(Environment.GetEnvironmentVariable("NORNA_PACKAGE_SMOKE")!, "preview.txt"), "passed");
            preview.Dispose(); Exit();
        };
        var panel = new Grid(); panel.RowDefinitions.Add(new() { Height = GridLength.Auto }); panel.RowDefinitions.Add(new() { Height = new(1, GridUnitType.Star) });
        var controls = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8, Margin = new(12) };
        controls.Children.Add(new Button { Content = "Native package integration" });
        controls.Children.Add(new AutoSuggestBox { PlaceholderText = "Native styles" });
        controls.Children.Add(new InfoBar { IsOpen = true, Message = "WinUI resources" });
        panel.Children.Add(controls); Grid.SetRow(preview.Element, 1); panel.Children.Add(preview.Element);
        window = new Window { Title = "NornaKit package integration", Content = panel }; window.AppWindow.Resize(new(640, 480)); window.Activate();
    }
}
'@ | Set-Content (Join-Path $previewConsumer 'App.xaml.cs') -Encoding utf8
& dotnet restore (Join-Path $previewConsumer 'Preview.csproj') "-p:Platform=$Platform" --configfile (Join-Path $previewConsumer 'NuGet.Config')
if ($LASTEXITCODE -ne 0) { throw 'Independent preview package restore failed.' }
& dotnet publish (Join-Path $previewConsumer 'Preview.csproj') --no-restore -c Release "-p:Platform=$Platform" -o (Join-Path $previewConsumer 'publish')
if ($LASTEXITCODE -ne 0) { throw 'Independent preview package build failed.' }
$env:NORNA_PACKAGE_SMOKE = $previewConsumer
$previewApp = Start-Process (Join-Path $previewConsumer 'publish/Preview.exe') -PassThru
if (-not $previewApp.WaitForExit(45000)) { $previewApp.Kill(); throw 'Independent preview package startup timed out.' }
if ($previewApp.ExitCode -ne 0 -or -not (Test-Path (Join-Path $previewConsumer 'preview.txt'))) {
    if (Test-Path (Join-Path $previewConsumer 'failure.txt')) { Get-Content (Join-Path $previewConsumer 'failure.txt') | Write-Host }
    throw 'Independent preview package did not draw a frame.'
}
Remove-Item Env:NORNA_PACKAGE_SMOKE
Write-Host "Verified $Platform independent NuGet WinUI preview frame."
