import AppKit
import XCTest
@testable import NornaKit
import NornaExamples

final class AdaptiveLayoutTests: XCTestCase {
    func testFlowchartTurnsWithoutChangingNodesEdgesOrExplicitSubgraphDirections() async throws {
        let source = "flowchart LR\nA[Source] --> B[Parse] --> C[Layout] --> D[Draw] --> E[Export]"
        let renderer = NativeDiagramRenderer()
        let wide = try await renderer.render(source), narrow = try await renderer.render(source, options: .init(maxWidth: 320))
        XCTAssertLessThan(narrow.width, wide.width)
        XCTAssertGreaterThan(narrow.height, wide.height)
        XCTAssertEqual(Set(wide.scene.nodes.map(\.id)), Set(narrow.scene.nodes.map(\.id)))
        XCTAssertEqual(wide.scene.edges.count, narrow.scene.edges.count)
        XCTAssertEqual(wide.scene.nodes.map(\.frame.size), narrow.scene.nodes.map(\.frame.size))
        let fixed = try await renderer.render(source, options: .init(maxWidth: 320, autoDirection: false))
        XCTAssertGreaterThan(fixed.width, narrow.width)
        let restored = try await renderer.render(source)
        XCTAssertEqual(restored, wide)
        let compound = "flowchart LR\nsubgraph G[Group]\ndirection LR\nA[First] --> B[Second]\nend\nB --> C[Third] --> D[Fourth]"
        let grouped = try await renderer.render(compound, options: .init(maxWidth: 320))
        let a = try XCTUnwrap(grouped.scene.nodes.first { $0.id == "A" }), b = try XCTUnwrap(grouped.scene.nodes.first { $0.id == "B" })
        XCTAssertLessThan(a.frame.midX, b.frame.midX)
        XCTAssertEqual(a.frame.midY, b.frame.midY, accuracy: 0.01)
    }

    func testLongLabelsRewrapAtOriginalFontSize() async throws {
        let source = "flowchart LR\nA[This long label must wrap into additional lines when the container gets narrower] --> B[Next]"
        let renderer = NativeDiagramRenderer()
        let wide = try await renderer.render(source), narrow = try await renderer.render(source, options: .init(maxWidth: 240))
        let a = try XCTUnwrap(wide.scene.nodes.first { $0.id == "A" }), b = try XCTUnwrap(narrow.scene.nodes.first { $0.id == "A" })
        XCTAssertEqual(a.label, b.label)
        XCTAssertGreaterThan(b.lines.count, a.lines.count)
        XCTAssertGreaterThan(b.frame.height, a.frame.height)
    }

    func testSequenceMessagesAndParticipantsSurviveNarrowLayout() async throws {
        let source = "sequenceDiagram\nactor A as Reader\nparticipant B as Editor\nparticipant C as Engine\nA->>B: A long request message that needs wrapping\nB->>+C: Parse\nC-->>-B: Done\nB-->>A: Display"
        let renderer = NativeDiagramRenderer()
        let wide = try await renderer.render(source), narrow = try await renderer.render(source, options: .init(maxWidth: 320))
        XCTAssertLessThan(narrow.width, wide.width)
        let labels: (DiagramScene) -> String = { $0.primitives.compactMap { if case .text(let text) = $0.geometry { return text.text.replacingOccurrences(of: "\n", with: "") }; return nil }.joined() }
        XCTAssertEqual(labels(wide.scene), labels(narrow.scene))
        XCTAssertLessThanOrEqual(narrow.width, 340)
        XCTAssertGreaterThanOrEqual(narrow.height, wide.height)
    }

    func testChartsReflowAndRetainIdentifiedData() async throws {
        for id in ["pie", "xychart", "timeline", "journey", "gantt", "kanban", "treemap", "swimlane"] {
            let example = try XCTUnwrap(DiagramExample.all.first { $0.id == id }), renderer = NativeDiagramRenderer()
            let wide = try await renderer.render(example.source), narrow = try await renderer.render(example.source, options: .init(maxWidth: 360))
            XCTAssertLessThan(narrow.width, wide.width, id)
            let ids: (DiagramScene) -> Set<String> = { Set($0.primitives.compactMap(\.id)) }
            XCTAssertEqual(ids(wide.scene), ids(narrow.scene), id)
            XCTAssertTrue(XMLParser(data: Data(narrow.svg.utf8)).parse(), id)
        }
    }

    func testFrontmatterPreservesOriginalErrorLinesAndRejectsUnsupportedConfiguration() async throws {
        let renderer = NativeDiagramRenderer()
        let title = try await renderer.render("---\ntitle: Native title\n---\nflowchart LR\nA --> B", options: .init(maxWidth: 320))
        XCTAssertTrue(title.svg.contains("Native title"))
        XCTAssertEqual(DiagramKind.detect("---\ntitle: Test\n---\nsequenceDiagram\nA->>B: hi"), .sequence)
        do { _ = try await renderer.render("---\ntitle: Test\n---\nsequenceDiagram\nunsupported command"); XCTFail("Expected source error") }
        catch let error as DiagramRenderError { XCTAssertEqual(error.line, 5) }
        do { _ = try await renderer.render("---\nconfig:\n  packet:\n    bitsPerRow: 16\n---\npacket\n0-7: \"A\""); XCTFail("Expected configuration error") }
        catch let error as DiagramRenderError { XCTAssertEqual(error.code, "unsupported-configuration"); XCTAssertEqual(error.line, 3) }
        for width in [CGFloat.nan, .infinity, 0, -1, 250_001] {
            do { _ = try await renderer.render("flowchart LR\nA --> B", options: .init(maxWidth: width)); XCTFail("Expected invalid width") }
            catch let error as DiagramRenderError { XCTAssertEqual(error.code, "limit") }
        }
    }

    @MainActor
    func testNativeRasterFixturesAtWideAndNarrowWidths() async throws {
        guard let directory = ProcessInfo.processInfo.environment["NORNA_ADAPTIVE_FIXTURE_DIR"] else { return }
        let url = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        for id in ["sequence", "pie", "xychart", "timeline", "journey", "gantt", "kanban", "swimlane"] {
            let example = try XCTUnwrap(DiagramExample.all.first { $0.id == id })
            for width in [CGFloat(1200), 360] {
                let artifact = try await NativeDiagramRenderer().render(example.source, options: .init(maxWidth: width))
                let scene = artifact.scene, scale = min(2, 2400 / max(scene.size.width, scene.size.height))
                let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(ceil(scene.size.width * scale)), pixelsHigh: Int(ceil(scene.size.height * scale)), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
                let graphics = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
                NSGraphicsContext.saveGraphicsState()
                graphics.cgContext.translateBy(x: 0, y: CGFloat(bitmap.pixelsHigh)); graphics.cgContext.scaleBy(x: scale, y: -scale)
                NSGraphicsContext.current = NSGraphicsContext(cgContext: graphics.cgContext, flipped: true)
                NSColor.white.setFill(); CGRect(origin: .zero, size: scene.size).fill()
                CoreGraphicsDiagramPainter.draw(scene, theme: .paper)
                NSGraphicsContext.restoreGraphicsState()
                let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                try png.write(to: url.appendingPathComponent("\(id)-\(Int(width)).png"))
                try artifact.svg.write(to: url.appendingPathComponent("\(id)-\(Int(width)).svg"), atomically: true, encoding: .utf8)
            }
        }
    }
}
