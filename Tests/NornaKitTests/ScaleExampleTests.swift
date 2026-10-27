import AppKit
import XCTest
@testable import NornaKit
import NornaExamples

final class ScaleExampleTests: XCTestCase {
    func testOnlyVariableLayoutsHaveSimpleAndComplexChoices() {
        let fixed: Set<DiagramKind> = [.quadrantChart, .wardley, .cynefin, .info]
        XCTAssertEqual(Set(DiagramExample.comparisons.map(\.kind)), Set(DiagramKind.allCases).subtracting(fixed))
        for kind in DiagramKind.allCases {
            XCTAssertFalse(kind.exampleLayoutNote.isEmpty)
            if fixed.contains(kind) { XCTAssertNil(kind.exampleComparison); continue }
            let comparison = kind.exampleComparison!
            XCTAssertEqual(comparison.simple.id, kind.starter.id)
            XCTAssertEqual(comparison.simple.kind, kind)
            XCTAssertEqual(DiagramKind.detect(comparison.complex.source), kind)
            XCTAssertEqual(DiagramExample.all.filter { $0.id == comparison.complex.id }.count, 1)
            XCTAssertNotEqual(comparison.simple.source, comparison.complex.source)
        }
    }

    func testThreeSetVennKeepsSetLabelsSeparateFromIntersectionLabels() async throws {
        let example = try XCTUnwrap(DiagramKind.venn.exampleComparison?.complex)
        let scene = try await NativeDiagramRenderer().render(example.source).scene
        let texts = scene.primitives.compactMap { primitive -> SceneText? in
            guard case .text(let text) = primitive.geometry else { return nil }
            return text
        }
        let sets = texts.filter { ["设计\n60", "开发\n60", "产品\n60"].contains($0.text) }
        let intersections = texts.filter { ["协作", "体验", "交付", "共同目标"].contains($0.text) }
        XCTAssertEqual(sets.count, 3)
        XCTAssertEqual(intersections.count, 4)
        for set in sets {
            for intersection in intersections { XCTAssertFalse(set.frame.intersects(intersection.frame)) }
        }
    }

    @MainActor
    func testComplexExamplesContainMoreContentAndRenderAtThreeWidths() async throws {
        let renderer = NativeDiagramRenderer()
        let directory = ProcessInfo.processInfo.environment["NORNA_APPLE_FIXTURE_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        if let directory { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        for comparison in DiagramExample.comparisons {
            let simple = try await renderer.render(comparison.simple.source, options: .init(maxWidth: 640))
            for width: CGFloat in [320, 640, 1200] {
                let complex = try await renderer.render(comparison.complex.source, options: .init(maxWidth: width))
                let count: (DiagramScene) -> Int = { $0.nodes.count + $0.edges.count + $0.groups.count + $0.primitives.count }
                XCTAssertGreaterThan(count(complex.scene), count(simple.scene), comparison.id)
                XCTAssertTrue(complex.width.isFinite && complex.height.isFinite, comparison.id)
                XCTAssertGreaterThan(complex.width, 0)
                XCTAssertGreaterThan(complex.height, 0)
                for theme: DiagramTheme in [.appleLight, .appleDark, .appleLightHighContrast, .appleDarkHighContrast] {
                    XCTAssertTrue(XMLParser(data: Data(complex.themedSVG(theme).utf8)).parse(), comparison.id)
                    if let directory, width == 640 {
                        for style in [DiagramColorStyle.neutral, .themed] {
                            try writeFixture(complex, theme: theme, colorStyle: style, stem: comparison.id + "-complex", directory: directory)
                        }
                    }
                }
            }
            if let directory {
                try comparison.complex.source.write(to: directory.appendingPathComponent(comparison.id + "-complex.mmd"), atomically: true, encoding: .utf8)
            }
        }
        if let directory {
            struct Entry: Encodable {
                let kind: String
                let title: String
                let mode: String
                let note: String
            }
            let entries = DiagramKind.allCases.map { Entry(kind: $0.rawValue, title: $0.title,
                mode: $0.exampleComparison == nil ? "single" : "comparison", note: $0.exampleLayoutNote) }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(entries).write(to: directory.appendingPathComponent("examples-manifest.json"))
            for kind in DiagramKind.allCases {
                try kind.starter.source.write(to: directory.appendingPathComponent(kind.rawValue + "-simple.mmd"), atomically: true, encoding: .utf8)
            }
        }
    }

    @MainActor
    private func writeFixture(_ artifact: DiagramArtifact, theme: DiagramTheme, colorStyle: DiagramColorStyle, stem: String, directory: URL) throws {
        let scene = artifact.scene, scale = min(1.5, 2000 / max(scene.size.width, scene.size.height))
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil,
            pixelsWide: Int(ceil(scene.size.width * scale)), pixelsHigh: Int(ceil(scene.size.height * scale)),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let graphics = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        graphics.cgContext.translateBy(x: 0, y: CGFloat(bitmap.pixelsHigh))
        graphics.cgContext.scaleBy(x: scale, y: -scale)
        NSGraphicsContext.current = NSGraphicsContext(cgContext: graphics.cgContext, flipped: true)
        CoreGraphicsDiagramPainter.color(theme.background).setFill()
        CGRect(origin: .zero, size: scene.size).fill()
        CoreGraphicsDiagramPainter.draw(scene, theme: theme, colorStyle: colorStyle)
        NSGraphicsContext.restoreGraphicsState()
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let suffix = colorStyle == .neutral ? "" : "-themed"
        try png.write(to: directory.appendingPathComponent("\(stem)\(suffix)-\(theme.rawValue).png"))
        try artifact.themedSVG(theme, colorStyle: colorStyle).write(to: directory.appendingPathComponent("\(stem)\(suffix)-\(theme.rawValue).svg"), atomically: true, encoding: .utf8)
    }
}
