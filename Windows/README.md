# NornaKit for Windows

The Windows implementation is in the native technology validation stage. It is not yet a complete Mermaid renderer or a released Norna Studio application. The existing Swift library and macOS application remain the released implementation.

## Requirements

- .NET SDK 10.0.402, selected by `global.json`.
- Windows 11, build 22000 or later, on x64 or ARM64.
- Windows SDK 26100 and Visual Studio Windows application development tools for full native builds.

Package versions are managed in `Directory.Packages.props`, with checked in NuGet lock files. The Windows layer uses Windows App SDK 2.5.1, Win2D 1.4.0 and PDFsharp 6.2.3. A direct reference to System.Security.Cryptography.Pkcs 10.0.13 replaces the vulnerable transitive version requested by PDFsharp.

## Projects

| Project | Current responsibility |
| --- | --- |
| `NornaKit.Core` | Platform independent geometry, scene and text contracts, native inline markup, SVG serialization, export validation and font collection extraction |
| `NornaKit.Windows` | DirectWrite text layout, native glyph geometry, Windows colors and icons, Win2D scene painting and PNG, JPEG, TIFF, SVG and PDF export |
| `NornaKit.Core.Tests` | Executable assertions for geometry, markup, XML escaping, export limits and font collection integrity |
| `NornaKit.Windows.SmokeTests` | Windowless native rendering and export verification on each Windows architecture |

`IDiagramRenderer` defines the asynchronous rendering contract. A Mermaid parser and layout implementation is intentionally not advertised by this validation build. The full migration must wait for the native technology gate to pass.

## Validate

Run these commands from `Windows` on Windows:

```powershell
dotnet restore NornaKit.slnx -p:Platform=x64 --locked-mode
dotnet run --project tests/NornaKit.Core.Tests --configuration Release --no-restore
dotnet publish tests/NornaKit.Windows.SmokeTests --configuration Release --no-restore -p:Platform=x64 -o artifacts/smoke
./artifacts/smoke/NornaKit.Windows.SmokeTests.exe artifacts/native-smoke
python -m pip install Pillow==11.3.0 pypdf==6.1.1
python scripts/verify-native-smoke.py artifacts/native-smoke
```

For ARM64, replace `-p:Platform=x64` with `-p:Platform=ARM64`. The executable and Windows App SDK dependencies are published together with the .NET runtime. No visible window is created by the harness.

The Core assertions can also run on macOS or Linux. Full native builds and execution require Windows. A C# compilation check on another OS, with resource generation disabled, does not establish native runtime compatibility.

## Native content and PDF

The Core parser recognizes balanced `[b]`, `[i]`, `[code]`, `[u]`, `[s]` and `[color=#RRGGBB]` tags. Unbalanced markup remains literal. It preserves the original source of `:win:name:` and `:sf:name:` icon tokens.

Windows icons use Segoe Fluent Icons. Common SF Symbols names have explicit semantic mappings. Unknown names remain literal source text. Windows icons are monochrome; configured palettes use their first color. No SF Symbols artwork or font files are redistributed.

DirectWrite selects actual system font faces and produces positioned glyph runs. Their geometry is retained for native drawing. PDF export embeds those same local font faces, extracts individual faces from TrueType collections, preserves glyph advances and offsets, and emits Unicode maps and `ActualText` for selection and search. The exporter does not install or replace a process wide PDFsharp font resolver.

The current PDF writer supports TrueType outlines and checks font embedding restrictions. Unsupported outline formats or embedding restrictions produce an explicit `export-font` error. Normal label text is never silently replaced by an image or by outlines in the PDF.

## Technology gate

Both architecture jobs must build and run successfully, then independently verify image sizes and transparency, SVG XML, native icons, embedded PDF fonts and extraction of Chinese and English text. `layout.json` records native font and glyph diagnostics even if the harness stops before export. Rendered artifacts are uploaded by the Windows workflow.

After this gate, the remaining implementation is the 33 diagram families and layout parity, shared example catalog, WinUI 3 workbench, installers, NuGet publication and product documentation. Windows download links must remain disabled until release artifacts actually exist.
