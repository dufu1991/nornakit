# NornaKit for Windows

Native C# libraries for all 33 diagram families, plus a WinUI 3 workbench on .NET 10. Windows 11 build 22000 or later is required, on x64 or ARM64. The Kit works independently of the workbench and does not require a visible window for parsing, layout or export.

- `NornaKit.Core`: pure .NET models, parsing, adaptive layout, diagnostics, rich text syntax, scene geometry, shared examples and SVG.
- `NornaKit.Windows`: DirectWrite text, Win2D drawing, native icons, Windows themes, a preview control and PNG, JPEG, TIFF, SVG and searchable PDF export.
- `NornaStudio`: native editing, live preview, examples, themes, file operations and export.

Use project references until the independent NuGet packages are published. Windows downloads stay disabled until release assets actually exist.

```csharp
var renderer = NornaKit.Windows.WindowsDiagramRenderer.Create();
var artifact = await renderer.RenderAsync("flowchart LR\n A --> B");
```

Build with .NET SDK 10.0.402 and Windows SDK 26100. Dependency versions and transitive packages are fixed by central package management and checked in lock files. Run from this directory:

```powershell
dotnet restore NornaKit.slnx -p:Platform=x64 --locked-mode
dotnet run --project tests/NornaKit.Core.Tests -c Release --no-restore
dotnet publish src/NornaStudio -c Release --no-restore -p:Platform=x64 -o artifacts/studio
```

Use `-p:Platform=ARM64` for ARM64. CI runs on both native architectures, checks the shared 600 source/status baselines, draws the 79 bilingual samples, verifies all five export formats and PDF text, then builds and launches the workbench. Installation and portable checks use the self contained output. A clean Windows 11 machine and physical DPI/accessibility/device recovery checks remain part of pre-release acceptance.

The 79 bilingual samples are embedded directly from `Sources/NornaKit/Resources/examples.json`; Swift and C# share stable IDs, content, order, starters and comparisons. Official source/status resources are shared too.

See the [Windows guide](../Docs/WINDOWS.md) for integration, exported font restrictions, icons, native controls, workbench shortcuts, build commands, installer validation and independent manual release workflows. See the [support matrix](../Docs/SUPPORT.md) for the implemented grammar and limits.
