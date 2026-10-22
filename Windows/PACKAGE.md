# NornaKit

Native diagram rendering for .NET 10. Norna Studio is an optional companion application; integrating either library does not require the workbench.

- **NornaKit.Core** provides models, parsers, layout, diagnostics, immutable scene geometry, rich text syntax, SVG and the shared bilingual example catalog for all 33 supported diagram families. Supply an `ITextLayoutProvider` to use the engine independently of Windows.
- **NornaKit.Windows** adds DirectWrite text layout, Win2D drawing, Windows themes and icons, a WinUI 3 preview control, and PNG, JPEG, TIFF, SVG and searchable PDF export. Windows 11 build 22000 or later is required, on x64 or ARM64.

```csharp
using NornaKit;
using NornaKit.Windows;

var renderer = WindowsDiagramRenderer.Create();
var diagram = await renderer.RenderAsync("flowchart LR\n A[Source] --> B[Native]");
var svg = SvgExporter.Export(diagram.Scene, WindowsPalette.Resolve());
```

Windows hosts target `net10.0-windows10.0.26100.0` with `SupportedOSPlatformVersion` set to `10.0.22000.0`. Parsing, layout and offscreen export do not require a visible window. Console hosts must initialize WinRT and deploy the Windows App SDK runtime, as shown in the repository's native smoke test project.

See the [Windows integration guide](https://github.com/dufu1991/nornakit/blob/main/Docs/WINDOWS.md), [supported grammar](https://github.com/dufu1991/nornakit/blob/main/Docs/SUPPORT.md) and [source repository](https://github.com/dufu1991/nornakit). NornaKit implements a documented subset of Mermaid syntax. PDF export embeds the actual system TrueType fonts and reports fonts that cannot be embedded.
