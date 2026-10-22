# NornaKit

[English](README.md) · [简体中文](README.zh-CN.md)

[![CI](https://github.com/dufu1991/nornakit/actions/workflows/ci.yml/badge.svg)](https://github.com/dufu1991/nornakit/actions/workflows/ci.yml)

**Native diagrams, clearly.**

[https://nornakit.com](https://nornakit.com)

**NornaKit** is a native Mermaid diagram rendering library for macOS and Windows. The macOS implementation uses Swift and CoreGraphics; Windows uses C#, .NET 10, DirectWrite and Win2D. Parsing, text measurement, layout, rendering, and export run locally, without a browser, JavaScript runtime, or network service.

- **NornaKit** provides parsing, layout, native drawing, and export. It is the primary focus of this project.
- **Norna Studio** is the optional native workbench: SwiftUI on macOS, WinUI 3 on Windows. Integrating either library does not require installing the app.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="website/dist/assets/hero-en-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="website/dist/assets/hero-en-light.png">
  <img alt="A diagram rendered natively by NornaKit" src="website/dist/assets/hero-en-light.png">
</picture>

## Use NornaKit on macOS

Requires **macOS 14 or later** and **Swift 6**, with no external package dependencies.

Add this repository as a Swift Package dependency and link the **NornaKit** product. Until a library version tag is published, use `main` or pin a specific commit:

```swift
.package(url: "https://github.com/dufu1991/nornakit.git", branch: "main")
```

```swift
import NornaKit

let diagram = try await NativeDiagramRenderer().render(
    "flowchart LR\n A[Source] --> B[Native diagram]",
    options: DiagramLayoutOptions(maxWidth: 640)
)
let svg = diagram.themedSVG(.appleLight)
```

`diagram.scene` contains the native geometry. `CoreGraphicsDiagramPainter` draws into an AppKit graphics context, and `DiagramExporter` handles image and PDF output. More examples and extensions are documented in the [Chinese usage guide](Docs/GUIDE.md).

## Features

### Windows integration

The Windows solution is in [`Windows/`](Windows/README.md). It includes the independent `NornaKit.Core` and `NornaKit.Windows` libraries and the WinUI 3 workbench. It targets Windows 11 build 22000 or later on x64 and ARM64, with Windows SDK 26100 for builds.

```csharp
using NornaKit;
using NornaKit.Windows;

var renderer = WindowsDiagramRenderer.Create();
var diagram = await renderer.RenderAsync(
    "flowchart LR\n A[Source] --> B[Native diagram]",
    new DiagramLayoutOptions(MaxWidth: 640), cancellationToken);
var svg = SvgExporter.Export(diagram.Scene, WindowsPalette.Resolve());
```

Use project references until NuGet packages are published. The Kit runs without a visible window; `DiagramPreview` provides the optional WinUI control. See the [Windows guide](Docs/WINDOWS.md) for integration, export, platform differences and packaging. Windows downloads remain unavailable until an actual Windows release is published.

### Shared capabilities

- 33 diagram families, including flowcharts, sequence, class, state, ER, Gantt, mind maps, and data charts.
- Mermaid parsing, native text measurement, adaptive layouts, and source error locations.
- Native scene geometry for drawing in host apps, with English and Simplified Chinese example sources.
- System light, dark, and increased contrast appearances, with configurable diagram colors.
- Inline SF Symbols and native rich text extensions.
- PNG, JPEG, TIFF, SVG, and PDF export.

Syntax support varies by diagram family. See the [support matrix, in Chinese](Docs/SUPPORT.md) for supported constructs and current limits. NornaKit does not claim complete Mermaid compatibility.

## Rendering examples

A selection of common diagrams rendered by NornaKit. Previews follow your light or dark appearance; open an image to view it at full size.

<table>
  <tr>
    <td align="center" valign="top" width="50%">
      <strong>Flowchart</strong><br>
      <a href="website/dist/assets/flowchart-en-light.png">
        <picture>
          <source media="(prefers-color-scheme: dark)" srcset="website/dist/assets/flowchart-en-dark.png">
          <img alt="Flowchart" src="website/dist/assets/flowchart-en-light.png" width="100%">
        </picture>
      </a><br>
      <a href="website/dist/assets/flowchart-en.mmd">Mermaid source</a>
    </td>
    <td align="center" valign="top" width="50%">
      <strong>Sequence diagram</strong><br>
      <a href="website/dist/assets/sequence-en-light.png">
        <picture>
          <source media="(prefers-color-scheme: dark)" srcset="website/dist/assets/sequence-en-dark.png">
          <img alt="Sequence diagram" src="website/dist/assets/sequence-en-light.png" width="100%">
        </picture>
      </a><br>
      <a href="website/dist/assets/sequence-en.mmd">Mermaid source</a>
    </td>
  </tr>
  <tr>
    <td align="center" valign="top" width="50%">
      <strong>Class diagram</strong><br>
      <a href="website/dist/assets/class-en-light.png">
        <picture>
          <source media="(prefers-color-scheme: dark)" srcset="website/dist/assets/class-en-dark.png">
          <img alt="Class diagram" src="website/dist/assets/class-en-light.png" width="100%">
        </picture>
      </a><br>
      <a href="website/dist/assets/class-en.mmd">Mermaid source</a>
    </td>
    <td align="center" valign="top" width="50%">
      <strong>Architecture diagram</strong><br>
      <a href="website/dist/assets/architecture-en-light.png">
        <picture>
          <source media="(prefers-color-scheme: dark)" srcset="website/dist/assets/architecture-en-dark.png">
          <img alt="Architecture diagram" src="website/dist/assets/architecture-en-light.png" width="100%">
        </picture>
      </a><br>
      <a href="website/dist/assets/architecture-en.mmd">Mermaid source</a>
    </td>
  </tr>
  <tr>
    <td align="center" valign="top" width="50%">
      <strong>Gantt chart</strong><br>
      <a href="website/dist/assets/gantt-en-light.png">
        <picture>
          <source media="(prefers-color-scheme: dark)" srcset="website/dist/assets/gantt-en-dark.png">
          <img alt="Gantt chart" src="website/dist/assets/gantt-en-light.png" width="100%">
        </picture>
      </a><br>
      <a href="website/dist/assets/gantt-en.mmd">Mermaid source</a>
    </td>
    <td align="center" valign="top" width="50%">
      <strong>Mind map</strong><br>
      <a href="website/dist/assets/mindmap-en-light.png">
        <picture>
          <source media="(prefers-color-scheme: dark)" srcset="website/dist/assets/mindmap-en-dark.png">
          <img alt="Mind map" src="website/dist/assets/mindmap-en-light.png" width="100%">
        </picture>
      </a><br>
      <a href="website/dist/assets/mindmap-en.mmd">Mermaid source</a>
    </td>
  </tr>
</table>

[Browse all examples](https://nornakit.com/#examples)

## Development and validation

```sh
git clone https://github.com/dufu1991/nornakit.git
cd nornakit
swift build --target NornaKit
swift test
```

Library sources live in `Sources/NornaKit/`, with tests in `Tests/NornaKitTests/` and regression fixtures in `Baselines/`. See the [development guide, in Chinese](Docs/DEVELOPMENT.md) for conventions and commands.

## Companion tool: Norna Studio

Norna Studio uses the same NornaKit APIs to demonstrate library capabilities, reproduce and debug rendering issues, and render Mermaid source into images, SVG, or PDF for occasional use. It provides source editing, live previews, canvas pan and zoom, and English and Simplified Chinese interfaces.

### Download and run

Requires **macOS 14 or later**. Supports **Apple Silicon Macs**.

[Download DMG](https://github.com/dufu1991/nornakit/releases/latest/download/Norna-Studio-macOS-arm64.dmg) · [Download ZIP](https://github.com/dufu1991/nornakit/releases/latest/download/Norna-Studio-macOS-arm64.zip) · [All releases](https://github.com/dufu1991/nornakit/releases)

Packages become available after the first successful Studio release workflow. Open the DMG and drag **Norna Studio** into **Applications**, or extract the ZIP and move the app there. Each release includes SHA-256 checksums and a `release.json` manifest.

Release notes identify the signing status. Until Apple credentials are configured, packages are **ad-hoc signed and not notarized**; macOS Gatekeeper may block them. Developer ID signing and notarization can be enabled in repository settings. See the [release guide](Docs/RELEASING.md).

### Install with Homebrew

The companion app is also distributed through the personal [dufu1991/tap](https://github.com/dufu1991/homebrew-tap) Cask repository:

```sh
brew install --cask dufu1991/tap/norna-studio
```

To update:

```sh
brew update
brew upgrade --cask dufu1991/tap/norna-studio
```

These commands become available once the Norna Studio Cask is published to the tap. Homebrew installs the same app published on GitHub Releases, with the same signing status. NornaKit itself is integrated through Swift Package Manager.

### Run from source

The complete app requires **Xcode 27.1 or later**. Open the project and run the `NornaStudio` scheme:

```sh
open NornaKit.xcodeproj
```

You can also launch the companion tool through Swift Package Manager:

```sh
swift run NornaStudio
```

The Xcode app uses the native layered icon. The package executable uses its bundled static icon. See the [usage guide, in Chinese](Docs/GUIDE.md) for workbench and debugging instructions.

### Package the companion tool

```sh
python3 -m unittest discover -s Tests/ReleaseTests -p 'test_*.py'
bash Scripts/Release/package.sh
```

Apple Silicon DMG and ZIP packages are written to `build/release/`. Packaging does not launch the app or publish a release.

## CI and releases

| Event | Result |
| --- | --- |
| Push to `main` or PR targeting `main` | Tests, Apple Silicon Release build, and website resource checks |
| Change `Configuration/Studio-Version.xcconfig` on `main` | After checks pass, package and publish `studio-vX.Y.Z` |
| Manual workflow on `main`, with `release` enabled | Publish the current Studio version, or recover a failed draft |
| Studio Release succeeds, with `HOMEBREW_TAP_TOKEN` configured | Immediately update the Cask in `dufu1991/homebrew-tap` |
| Hourly or manual run in the tap repository | Verify the latest Studio Release and synchronize its Cask, without a personal token |
| Push a library tag such as `vX.Y.Z` | Does not publish the Studio app |

**NornaKit is the primary library product; Studio is versioned independently.** Change `MARKETING_VERSION` and increment `CURRENT_PROJECT_VERSION` in the Studio version file to release the app. This also applies to the initial push containing that file. Ordinary commits do not create a new Release; published Studio versions are immutable. See [release setup and recovery](Docs/RELEASING.md).

## Repository layout

```text
Sources/NornaKit/       Models, parsing, layouts, rendering, export, and examples
Sources/NornaStudio/    Native app, editor, canvas, export UI, and localization
Tests/                 Swift tests and release automation tests
Baselines/             Versioned reference sources, SVGs, and regression snapshots
Configuration/         App metadata, entitlements, and Studio version
Scripts/               Development tools and release packaging
Branding/              Brand source assets and usage rules
Docs/                  Usage, support, development, and release documentation
website/               Static website, published assets, and generation tools
.github/workflows/     CI and automatic Studio releases
```

`Package.swift` defines the package. `project.yml` defines the XcodeGen project; `NornaKit.xcodeproj` is committed for direct use. After changing the project definition or adding, removing, or moving source files, run `xcodegen generate`. Editing the Studio version file does not require regeneration.

Build output and local design archives are excluded from Git. App and website sources share this repository. See the [development guide, in Chinese](Docs/DEVELOPMENT.md), [website guide, in Chinese](website/README.md), and [brand guide, in Chinese](Branding/README.md).

## Attribution

NornaKit adapts selected measurement formulas, rendering conventions, and reference examples from Pele. See [third-party notices](THIRD_PARTY_NOTICES.md) and the licenses in the library resources. NornaKit's original code is distributed under the [MIT License](LICENSE).
