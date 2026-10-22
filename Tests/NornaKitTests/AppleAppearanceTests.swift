import AppKit
import XCTest
@testable import NornaKit

final class AppleAppearanceTests: XCTestCase {
    private let appearances: [DiagramTheme] = [.appleLight, .appleDark, .appleLightHighContrast, .appleDarkHighContrast]

    @MainActor
    func testEveryDiagramTypeHasAnAvailableNativeSymbolAndStarter() async throws {
        let renderer = NativeDiagramRenderer()
        for kind in DiagramKind.allCases {
            XCTAssertEqual(kind.starter.kind, kind)
            XCTAssertNotNil(NSImage(systemSymbolName: kind.symbol, accessibilityDescription: kind.title), kind.rawValue)
            let artifact = try await renderer.render(kind.starter.source)
            XCTAssertEqual(artifact.scene.kind, kind)
        }
        XCTAssertEqual(Set(DiagramKind.allCases.map(\.category)), Set(DiagramCategory.allCases))
    }

    func testResolvedSystemPalettesKeepLabelsLegible() throws {
        for theme in appearances {
            let colors = theme.colors
            for background in [colors.background, colors.surface, colors.surfaceAlt] {
                XCTAssertGreaterThanOrEqual(try contrast(colors.foreground, background), 4.5, theme.rawValue)
                XCTAssertGreaterThanOrEqual(try contrast(colors.border, background), 3, theme.rawValue)
                XCTAssertGreaterThanOrEqual(try contrast(colors.line, background), 3, theme.rawValue)
            }
            XCTAssertEqual(colors.series.count, 8)
            for index in -8..<16 {
                let fill = try XCTUnwrap(SceneColor.series(index).hex(theme))
                let label = try XCTUnwrap(SceneColor.onSeries(index).hex(theme))
                XCTAssertGreaterThanOrEqual(try contrast(fill, label), 4.5, "\(theme.rawValue): \(index)")
            }
        }
        XCTAssertNotEqual(DiagramTheme.appleLight.colors.background, DiagramTheme.appleDark.colors.background)
        XCTAssertNotEqual(DiagramTheme.appleLight.colors.series, DiagramTheme.appleDark.colors.series)
        let before = DiagramTheme.appleDark.colors.background
        DiagramTheme.invalidateSystemColors()
        XCTAssertEqual(before, DiagramTheme.appleDark.colors.background)
    }

    func testColorStylesPreserveNeutralAppearanceAndReadableThemedLabels() throws {
        for theme in DiagramTheme.allCases {
            let base = theme.colors, neutral = theme.colors(for: .neutral), themed = theme.colors(for: .themed)
            XCTAssertEqual(neutral.surface, base.surface)
            XCTAssertEqual(neutral.line, base.line)
            XCTAssertEqual(neutral.border, base.border)
            XCTAssertEqual(themed.background, base.background)
            XCTAssertEqual(themed.foreground, base.foreground)
            XCTAssertNotEqual(themed.surface, base.surface)
            XCTAssertEqual(themed.series, base.series)
            for style in [DiagramColorStyle.neutral, .themed] {
                XCTAssertEqual(SceneColor.literal("#123456").hex(theme, colorStyle: style), "#123456")
                for index in -8..<16 {
                    XCTAssertEqual(SceneColor.series(index).hex(theme, colorStyle: style), SceneColor.series(index).hex(theme))
                    XCTAssertEqual(SceneColor.onSeries(index).hex(theme, colorStyle: style), SceneColor.onSeries(index).hex(theme))
                }
            }
        }
        for theme in appearances {
            let colors = theme.colors(for: .themed)
            for background in [colors.background, colors.surface, colors.surfaceAlt] {
                XCTAssertGreaterThanOrEqual(try contrast(colors.foreground, background), 4.5, theme.rawValue)
                XCTAssertGreaterThanOrEqual(try contrast(colors.line, background), 3, theme.rawValue)
                XCTAssertGreaterThanOrEqual(try contrast(colors.border, background), 3, theme.rawValue)
            }
            if [.appleLightHighContrast, .appleDarkHighContrast].contains(theme) {
                XCTAssertGreaterThanOrEqual(try contrast(colors.border, colors.surface), 3, theme.rawValue)
            }
        }
        let before = DiagramTheme.appleDark.colors(for: .themed).surface
        DiagramTheme.invalidateSystemColors()
        XCTAssertEqual(before, DiagramTheme.appleDark.colors(for: .themed).surface)
    }

    func testCustomColorParsingAndContrastAcrossAllSystemAppearances() throws {
        XCTAssertEqual(DiagramAccentColor(hex: " FFaA00 ")?.hex, "#ffaa00")
        for invalid in ["#fff", "#12345678", "+fffff", "#zz1234", "#１２３４５６", "#12 345"] {
            XCTAssertNil(DiagramAccentColor(hex: invalid))
        }
        for theme in appearances {
            for hex in ["#ffffff", "#000000", "#ffff00", "#ff0000", "#00ff00", "#0000ff", "#123456"] {
                let accent = try XCTUnwrap(DiagramAccentColor(hex: hex))
                let colors = theme.colors(for: .custom, customAccent: accent)
                for background in [colors.background, colors.surface, colors.surfaceAlt] {
                    XCTAssertGreaterThanOrEqual(try contrast(colors.foreground, background), 4.5, "\(theme): \(hex)")
                    XCTAssertGreaterThanOrEqual(try contrast(colors.line, background), 4.5, "\(theme): \(hex)")
                }
                XCTAssertEqual(colors.series, theme.colors.series)
                XCTAssertEqual(SceneColor.literal("#123456").hex(theme, colorStyle: .custom, customAccent: accent), "#123456")
            }
        }
    }

    func testNeutralKeepsThemedFillLevelsInGrayscale() throws {
        let luminance: (String) -> Double = { hex in
            let value = UInt32(hex.dropFirst(), radix: 16)!
            let linear: (UInt32) -> Double = {
                let channel = Double($0 & 255) / 255
                return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(value >> 16) + 0.7152 * linear(value >> 8) + 0.0722 * linear(value)
        }
        for theme in appearances {
            let neutral = theme.colors(for: .neutral), themed = theme.colors(for: .themed)
            for (gray, original) in [(neutral.surface, themed.surface), (neutral.surfaceAlt, themed.surfaceAlt)] {
                let value = try XCTUnwrap(UInt32(gray.dropFirst(), radix: 16))
                XCTAssertEqual((value >> 16) & 255, (value >> 8) & 255)
                XCTAssertEqual((value >> 8) & 255, value & 255)
                XCTAssertEqual(luminance(gray), luminance(original), accuracy: 0.005)
                XCTAssertNotEqual(gray, neutral.background)
            }
            XCTAssertEqual(neutral.series, themed.series)
            let before = neutral.surface
            DiagramTheme.invalidateSystemColors()
            XCTAssertEqual(theme.colors.surface, before)
        }
    }

    @MainActor
    func testNativeAndSVGUseTheSameStyleForBothDrawingRepresentations() throws {
        let node = SceneNode(id: "node", label: "", shape: .rectangle, frame: CGRect(x: 8, y: 8, width: 72, height: 80), lines: [])
        let primitive = ScenePrimitive(geometry: .rectangle(CGRect(x: 100, y: 8, width: 72, height: 80), 8), style: VectorStyle(fill: .surface))
        let scene = DiagramScene(size: CGSize(width: 180, height: 96), nodes: [node], edges: [], primitives: [primitive])
        for theme in appearances {
            for style in [DiagramColorStyle.neutral, .themed] {
                let colors = theme.colors(for: style)
                let bitmap = try rasterize(scene, theme: theme, colorStyle: style, scale: 1)
                let expected = CoreGraphicsDiagramPainter.color(colors.surface)
                for x in [40, 132] {
                    let actual = try XCTUnwrap(bitmap.colorAt(x: x, y: 40)?.usingColorSpace(.sRGB))
                    XCTAssertEqual(actual.redComponent, expected.redComponent, accuracy: 0.015)
                    XCTAssertEqual(actual.greenComponent, expected.greenComponent, accuracy: 0.015)
                    XCTAssertEqual(actual.blueComponent, expected.blueComponent, accuracy: 0.015)
                }
                let svg = SVGExporter.export(scene, theme: theme, colorStyle: style)
                // Some neutral appearances use the same color for the canvas and nodes.
                XCTAssertGreaterThanOrEqual(svg.components(separatedBy: "fill=\"\(colors.surface)\"").count - 1, 2)
            }
        }
    }

    func testEveryExampleExportsInBothStylesWithIdenticalPathsAndLabelPositions() async throws {
        let renderer = NativeDiagramRenderer()
        let geometry = #"(?:\s(?:d|x|y|cx|cy|rx|ry|width|height|viewBox|font-size|text-anchor)=\"[^\"]*\")"#
        let pattern = try NSRegularExpression(pattern: geometry)
        let attributes: (String) -> [String] = { svg in
            let text = svg as NSString
            return pattern.matches(in: svg, range: NSRange(location: 0, length: text.length)).map { text.substring(with: $0.range) }
        }
        for example in DiagramExample.all {
            let artifact = try await renderer.render(example.source, options: .init(maxWidth: 640))
            for theme in appearances {
                let neutral = artifact.themedSVG(theme), themed = artifact.themedSVG(theme, colorStyle: .themed)
                XCTAssertEqual(neutral, artifact.themedSVG(theme, colorStyle: .neutral))
                XCTAssertTrue(XMLParser(data: Data(themed.utf8)).parse(), example.id)
                XCTAssertEqual(attributes(neutral), attributes(themed), example.id)
            }
        }
    }

    @MainActor
    func testAllTypesDrawInEverySystemAppearanceAndExportMatchingColors() async throws {
        let renderer = NativeDiagramRenderer()
        for kind in DiagramKind.allCases {
            let artifact = try await renderer.render(kind.starter.source, options: .init(maxWidth: 640))
            let scene = artifact.scene
            for theme in appearances {
              for style in [DiagramColorStyle.neutral, .themed] {
                let svg = artifact.themedSVG(theme, colorStyle: style)
                XCTAssertTrue(XMLParser(data: Data(svg.utf8)).parse(), "\(kind.rawValue): \(theme.rawValue)")
                XCTAssertTrue(svg.contains("fill=\"\(theme.background)\""))
                XCTAssertEqual(scene, artifact.scene)
                let scale = min(1.5, 1600 / max(scene.size.width, scene.size.height))
                let bitmap = try rasterize(scene, theme: theme, colorStyle: style, scale: scale)
                let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                XCTAssertGreaterThan(png.count, 500, "\(kind.rawValue): \(theme.rawValue)")
                if let directory = ProcessInfo.processInfo.environment["NORNA_APPLE_FIXTURE_DIR"] {
                    let url = URL(fileURLWithPath: directory, isDirectory: true)
                    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                    let suffix = style == .neutral ? "" : "-themed"
                    try png.write(to: url.appendingPathComponent("\(kind.rawValue)\(suffix)-\(theme.rawValue).png"))
                    try svg.write(to: url.appendingPathComponent("\(kind.rawValue)\(suffix)-\(theme.rawValue).svg"), atomically: true, encoding: .utf8)
                }
              }
            }
            XCTAssertEqual(artifact.svg, artifact.themedSVG(.appleLight))
        }
        XCTAssertEqual(SceneColor.literal("#123456").hex(.appleDark), "#123456")
    }

    @MainActor
    private func rasterize(_ scene: DiagramScene, theme: DiagramTheme, colorStyle: DiagramColorStyle, scale: CGFloat) throws -> NSBitmapImageRep {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil,
            pixelsWide: Int(ceil(scene.size.width * scale)), pixelsHigh: Int(ceil(scene.size.height * scale)),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let graphics = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        graphics.cgContext.translateBy(x: 0, y: CGFloat(bitmap.pixelsHigh))
        graphics.cgContext.scaleBy(x: scale, y: -scale)
        NSGraphicsContext.current = NSGraphicsContext(cgContext: graphics.cgContext, flipped: true)
        CoreGraphicsDiagramPainter.color(theme.background).setFill()
        CGRect(origin: .zero, size: scene.size).fill()
        CoreGraphicsDiagramPainter.draw(scene, theme: theme, colorStyle: colorStyle)
        return bitmap
    }

    private func contrast(_ first: String, _ second: String) throws -> Double {
        let luminance: (String) throws -> Double = { hex in
            let value = try XCTUnwrap(UInt32(hex.dropFirst(), radix: 16))
            let linear: (UInt32) -> Double = {
                let channel = Double($0 & 255) / 255
                return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(value >> 16) + 0.7152 * linear(value >> 8) + 0.0722 * linear(value)
        }
        let a = try luminance(first), b = try luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
