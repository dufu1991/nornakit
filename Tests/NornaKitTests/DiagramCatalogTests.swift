import AppKit
import XCTest
@testable import NornaKit

final class DiagramCatalogTests: XCTestCase {
    func testCatalogCoversEveryRegisteredFamily() {
        XCTAssertEqual(DiagramKind.allCases.count, 33)
        XCTAssertEqual(Set(DiagramExample.all.map(\.kind)), Set(DiagramKind.allCases))
        XCTAssertEqual(Set(DiagramExample.all.map(\.id)).count, DiagramExample.all.count)
        XCTAssertNil(DiagramKind.detect("unknownDiagram\nA --> B"))
    }

    @MainActor
    func testEveryCatalogExampleProducesNativePixelsAndValidSVG() async throws {
        let renderer = NativeDiagramRenderer()
        for example in DiagramExample.all {
            do {
                let artifact = try await renderer.render(example.source)
                XCTAssertEqual(artifact.type, example.kind.rawValue, example.id)
                XCTAssertGreaterThan(artifact.scene.size.width, 20, example.id)
                XCTAssertGreaterThan(artifact.scene.size.height, 20, example.id)
                for primitive in artifact.scene.primitives where !primitive.bounds.isNull {
                    XCTAssertTrue(primitive.bounds.minX >= 0 && primitive.bounds.minY >= 0, example.id)
                    XCTAssertLessThanOrEqual(primitive.bounds.maxX, artifact.scene.size.width, example.id)
                    XCTAssertLessThanOrEqual(primitive.bounds.maxY, artifact.scene.size.height, example.id)
                }
                for theme in DiagramTheme.allCases {
                    let svg = SVGExporter.export(artifact.scene, theme: theme)
                    XCTAssertTrue(XMLParser(data: Data(svg.utf8)).parse(), example.id)
                    let geometry = svg.replacingOccurrences(of: #"data:image/png;base64,[A-Za-z0-9+/=]+"#, with: "", options: .regularExpression)
                    XCTAssertFalse(geometry.contains("NaN"), example.id)
                    XCTAssertFalse(svg.contains("<script"), example.id)
                }
                let scale = min(2, 2000 / max(artifact.scene.size.width, artifact.scene.size.height))
                let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil,
                    pixelsWide: max(1, Int(ceil(artifact.scene.size.width * scale))), pixelsHigh: max(1, Int(ceil(artifact.scene.size.height * scale))),
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
                let graphics = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
                NSGraphicsContext.saveGraphicsState()
                graphics.cgContext.translateBy(x: 0, y: CGFloat(bitmap.pixelsHigh))
                graphics.cgContext.scaleBy(x: scale, y: -scale)
                NSGraphicsContext.current = NSGraphicsContext(cgContext: graphics.cgContext, flipped: true)
                NSColor.white.setFill()
                CGRect(origin: .zero, size: artifact.scene.size).fill()
                CoreGraphicsDiagramPainter.draw(artifact.scene, theme: .paper)
                NSGraphicsContext.restoreGraphicsState()
                let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                XCTAssertGreaterThan(png.count, 1000, example.id)
                if let directory = ProcessInfo.processInfo.environment["NORNA_FIXTURE_DIR"] {
                    let url = URL(fileURLWithPath: directory, isDirectory: true)
                    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                    try png.write(to: url.appendingPathComponent(example.id + ".png"))
                    try artifact.svg.write(to: url.appendingPathComponent(example.id + ".svg"), atomically: true, encoding: .utf8)
                }
            } catch { XCTFail("\(example.id): \(error)") }
        }
    }

    func testInvalidSyntaxAndSemanticsNeverSilentlyRender() async {
        let sources = [
            "sequenceDiagram\nA->>B: hello\nelse wrong",
            "sequenceDiagram\ndeactivate A",
            "sequenceDiagram\nA->>B: hello\nloop wait",
            "pie\n\"negative\": -1", "pie\n\"zero\": 0",
            "xychart-beta\nx-axis [a,b]\nline [1,2,3]",
            "quadrantChart\nOutside: [2, 0]",
            "radar-beta\naxis A,B\ncurve x{1,2}",
            "gantt\nTask :after missing, 3d",
            "gitGraph\ncheckout missing",
            "sankey-beta\nA,B,2\nB,A,3",
            "packet-beta\n0-7: \"A\"\n4-8: \"B\"",
            "architecture-beta\nservice A(server)[A]\nA:R --> L:missing",
            "requirementDiagram\nA - satisfies -> B",
            "venn-beta\nset A: 10\nset B: 5\nunion A,B: 6",
            "wardley-beta\ncomponent A [2, 300]",
            "railroad-ebnf-beta\nrule = [ \"x\" ;",
            "eventmodeling\ntf 01 cmd A ->> missing",
            "classDiagram\nclass A {\n+method()",
            "unknownDiagram\nA --> B"
        ]
        for source in sources {
            do { _ = try await NativeDiagramRenderer().render(source); XCTFail("Unexpected acceptance: \(source)") }
            catch { XCTAssertTrue(error is DiagramRenderError, "\(source): \(error)") }
        }
    }

    func testSequencePreservesAliasesArrowsFramesAndActivation() throws {
        let model = try SequenceDiagram.parse("""
        sequenceDiagram
            actor A as 用户
            participant B as 服务
            autonumber 10 2
            A->>+B: 请求
            loop 重试
                B->>B: 自调用
            end
            B-->>-A: 响应
        """)
        XCTAssertEqual(model.participants.map(\.label), ["用户", "服务"])
        XCTAssertTrue(model.participants[0].actor)
        XCTAssertTrue(model.events.contains(.numbering(10, 2, true)))
        XCTAssertTrue(model.events.contains(.message("A", "B", "请求", "->>", 1)))
        XCTAssertTrue(model.events.contains(.message("B", "A", "响应", "-->>", -1)))
        XCTAssertTrue(model.events.contains(.frame("loop", "重试")))
    }

    func testTextEscapingAndDeterministicLayoutAcrossFamilies() async throws {
        for source in ["sequenceDiagram\nA->>B: <tag> & \"quoted\" 中文", "pie\n\"A & B\": 5\n\"C < D\": 3", "classDiagram\nclass A {\n+value List<T>\n}"] {
            let renderer = NativeDiagramRenderer()
            let a = try await renderer.render(source), b = try await renderer.render(source)
            XCTAssertEqual(a.svg, b.svg)
            XCTAssertTrue(XMLParser(data: Data(a.svg.utf8)).parse())
            XCTAssertFalse(a.svg.contains("<tag>"))
        }
    }

    func testInputLimitAndCancellation() async throws {
        do { _ = try await NativeDiagramRenderer().render(String(repeating: "x", count: 50_001)); XCTFail("Expected limit") }
        catch let error as DiagramRenderError { XCTAssertEqual(error.code, "limit") }
        let task = Task { try await NativeDiagramRenderer().render("sequenceDiagram\nA->>B: hello") }
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
    }
}
