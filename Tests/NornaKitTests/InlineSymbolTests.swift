import AppKit
import CoreGraphics
import ImageIO
import XCTest
@testable import NornaKit

final class InlineSymbolTests: XCTestCase {
    private let token = ":sf:icloud.and.arrow.up:"
    private let flow = """
    flowchart LR
        subgraph cloud[Cloud :sf:icloud:]
            A["Upload :sf:icloud.and.arrow.up: file"]
            B["Done :sf:checkmark.circle.fill:<br/>Next :sf:arrow.right:"]
            A -->|Save :sf:externaldrive:| B
        end
    """

    func testTokenParsingPreservesUnicodeAndMalformedInput() {
        XCTAssertEqual(InlineText.segments("上传 \(token) 文件"), [.text("上传 "), .symbol("icloud.and.arrow.up"), .text(" 文件")])
        XCTAssertEqual(InlineText.segments(":sf:person.fill::sf:checkmark:"), [.symbol("person.fill"), .symbol("checkmark")])
        for literal in [":sf:", ":sf::", ":sf:bad name:", ":sf:cloud", "https://example.com", "👨‍👩‍👧‍👦 文件"] {
            XCTAssertEqual(InlineText.segments(literal).map(\.source).joined(), literal)
            XCTAssertFalse(InlineText.segments(literal).contains { if case .symbol = $0 { return true }; return false })
        }
    }

    func testWrappingKeepsSymbolsAtomicAndMeasuresRenderedWidth() throws {
        let image = try XCTUnwrap(InlineText.symbol("icloud.and.arrow.up", size: 16))
        XCTAssertEqual(TextMeasurement.width(token), image.size.width, accuracy: 0.001)
        XCTAssertEqual(TextMeasurement.width("A\(token)B"), TextMeasurement.width("A") + image.size.width + TextMeasurement.width("B"), accuracy: 0.001)
        let width = image.size.width + 1
        let lines = TextMeasurement.lines("A\(token)B", maxWidth: width)
        XCTAssertEqual(lines, ["A", token, "B"])
        XCTAssertEqual(lines.joined(), "A\(token)B")
        XCTAssertEqual(TextMeasurement.lines("\(token)\n\n\(token)", maxWidth: 1), [token, "", token])
        XCTAssertEqual(TextMeasurement.lines("\(token)\(token)", maxWidth: width), [token, token])
        XCTAssertEqual(TextMeasurement.lines("👨‍👩‍👧‍👦\(token)", maxWidth: width).first, "👨‍👩‍👧‍👦")
        let small = TextMeasurement.width(token, size: 12), large = TextMeasurement.width(token, size: 30)
        XCTAssertGreaterThan(large, small)
        let unknown = ":sf:norna.symbol.does.not.exist:"
        XCTAssertNil(InlineText.symbol("norna.symbol.does.not.exist", size: 16))
        XCTAssertGreaterThan(TextMeasurement.width(unknown), TextMeasurement.width(token))
        XCTAssertTrue(InlineText.svg([unknown], frame: .zero, size: 16, lineHeight: 22, color: "#000000").contains(">\(unknown)</text>"))
    }

    func testSceneBuilderUsesAtomicWrappingWithActualFontWeightAndMonospaceMetrics() {
        let builder = SceneBuilder(.sequence)
        let width = TextMeasurement.width(token, size: 16, bold: true, mono: true) + 1
        builder.text("A\(token)B", CGRect(x: 0, y: 0, width: width, height: 100), bold: true, mono: true)
        guard case .text(let value) = builder.primitives[0].geometry else { return XCTFail("Expected text") }
        XCTAssertEqual(value.text, "A\n\(token)\nB")
        XCTAssertTrue(value.bold)
        XCTAssertTrue(value.mono)
    }

    func testSVGAndNativeShareBaselineAndLeadingCenterTrailingOrigins() throws {
        let frame = CGRect(x: 40, y: 20, width: 200, height: 60)
        let line = InlineText.line("Go \(token) now", size: 20, bold: true, mono: true)
        let font = InlineText.font(size: 20, bold: true, mono: true)
        let baseline = InlineText.baseline(top: frame.midY - 14, lineHeight: 28, font: font)
        let symbol = try XCTUnwrap(line.runs.first { $0.image != nil })
        for (alignment, origin) in [(TextAlignment.leading, frame.minX), (.center, frame.midX - line.width / 2), (.trailing, frame.maxX - line.width)] {
            let svg = InlineText.svg(["Go \(token) now"], frame: frame, size: 20, lineHeight: 28,
                color: "#26804b", alignment: alignment, bold: true, mono: true)
            let proof = SymbolSVGProof()
            let parser = XMLParser(data: Data(svg.utf8))
            parser.delegate = proof
            XCTAssertTrue(parser.parse())
            XCTAssertEqual(try XCTUnwrap(Double(proof.images[0]["x"]!)), Double(origin + symbol.x), accuracy: 0.01)
            let expected = InlineText.symbolFrame(try XCTUnwrap(symbol.image), x: origin + symbol.x, baseline: baseline)
            XCTAssertEqual(try XCTUnwrap(Double(proof.images[0]["y"]!)), Double(expected.minY), accuracy: 0.01)
            XCTAssertEqual(try XCTUnwrap(Double(proof.texts[0]["y"]!)), Double(baseline), accuracy: 0.01)
            XCTAssertTrue(svg.contains("font-weight=\"600\""))
            XCTAssertTrue(svg.contains("Menlo, monospace"))
            let data = try XCTUnwrap(Data(base64Encoded: try XCTUnwrap(proof.images[0]["href"]).components(separatedBy: ",")[1]))
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data))
            var coloredPixels = 0, transparentPixels = 0
            var colorError: CGFloat = 0
            for y in 0..<bitmap.pixelsHigh {
                for x in 0..<bitmap.pixelsWide {
                    // NSBitmapImageRep exposes stored sRGB samples as calibrated components.
                    let pixel = try XCTUnwrap(bitmap.colorAt(x: x, y: y))
                    if pixel.alphaComponent > 0.9 {
                        coloredPixels += 1
                        colorError = max(colorError, abs(pixel.greenComponent - 128.0 / 255))
                    }
                    if pixel.alphaComponent == 0 { transparentPixels += 1 }
                }
            }
            XCTAssertGreaterThan(coloredPixels, 20)
            XCTAssertGreaterThan(transparentPixels, 20)
            XCTAssertLessThan(colorError, 0.025)
        }
    }

    @MainActor
    func testEveryExportFormatIncludesSymbolsInBothSceneRepresentations() async throws {
        let sources = [flow, """
        sequenceDiagram
            participant A as User :sf:person.fill:
            participant B as Cloud :sf:icloud:
            A->>B: Upload :sf:icloud.and.arrow.up: file
            B-->>A: Done :sf:checkmark.circle.fill:
        """]
        for source in sources {
            let scene = try await NativeDiagramRenderer().render(source).scene
            for theme in [DiagramTheme.appleLight, .appleDark] {
                for format in DiagramExportFormat.allCases {
                    let data = try DiagramExporter.data(for: scene, theme: theme,
                        options: .init(format: format, background: format == .jpeg ? .theme : .transparent))
                    XCTAssertGreaterThan(data.count, 200)
                    if format == .svg {
                        let proof = SymbolSVGProof()
                        let parser = XMLParser(data: data)
                        parser.delegate = proof
                        XCTAssertTrue(parser.parse())
                        XCTAssertGreaterThanOrEqual(proof.images.count, 4)
                        XCTAssertFalse(proof.visibleText.contains(":sf:"))
                        XCTAssertTrue(proof.images.allSatisfy { $0["href"]!.hasPrefix("data:image/png;base64,") })
                    } else if format == .pdf {
                        let document = try XCTUnwrap(CGPDFDocument(try XCTUnwrap(CGDataProvider(data: data as CFData))))
                        XCTAssertEqual(document.numberOfPages, 1)
                    } else {
                        let image = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
                        XCTAssertNotNil(CGImageSourceCreateImageAtIndex(image, 0, nil))
                    }
                }
            }
        }
    }

    @MainActor
    func testSymbolPixelsSurvivePNGAndPDFAtTheSamePosition() throws {
        let text = SceneText(text: ":sf:arrow.up:", frame: CGRect(x: 20, y: 20, width: 80, height: 80), size: 40, color: .literal("#26804b"))
        let scene = DiagramScene(size: CGSize(width: 120, height: 120), nodes: [], edges: [], primitives: [.init(geometry: .text(text))])
        var bounds: [CGRect] = []
        for format in [DiagramExportFormat.png, .pdf] {
            let data = try DiagramExporter.data(for: scene, options: .init(format: format, background: .transparent, scale: 1, padding: 0))
            let bitmap: NSBitmapImageRep
            if format == .png { bitmap = try XCTUnwrap(NSBitmapImageRep(data: data)) }
            else {
                let document = try XCTUnwrap(CGPDFDocument(try XCTUnwrap(CGDataProvider(data: data as CFData))))
                let context = try XCTUnwrap(CGContext(data: nil, width: 120, height: 120, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.drawPDFPage(try XCTUnwrap(document.page(at: 1)))
                bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(context.makeImage()))
            }
            var bound = CGRect.null
            var colorError: CGFloat = 0
            for y in 0..<120 {
                for x in 0..<120 {
                    let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y))
                    if color.alphaComponent > 0.5 {
                        if color.alphaComponent > 0.95 { colorError = max(colorError, abs(color.greenComponent - 128.0 / 255)) }
                        bound = bound.union(CGRect(x: x, y: y, width: 1, height: 1))
                    }
                }
            }
            XCTAssertGreaterThan(bound.width, 10)
            XCTAssertGreaterThan(bound.height, 20)
            XCTAssertLessThan(colorError, 0.025)
            bounds.append(bound)
        }
        XCTAssertEqual(bounds[0], bounds[1])
    }

    @MainActor
    func testWriteVisualFixturesWhenRequested() async throws {
        guard let directory = ProcessInfo.processInfo.environment["NORNA_SYMBOL_FIXTURE_DIR"] else { return }
        let folder = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let scene = try await NativeDiagramRenderer().render(flow).scene
        for theme in [DiagramTheme.appleLight, .appleDark] {
            for format in [DiagramExportFormat.png, .svg, .pdf] {
                let data = try DiagramExporter.data(for: scene, theme: theme, colorStyle: .themed, options: .init(format: format))
                try data.write(to: folder.appendingPathComponent("sf-symbols-\(theme == .appleLight ? "light" : "dark").\(format.fileExtension)"))
            }
        }
    }
}

private final class SymbolSVGProof: NSObject, XMLParserDelegate {
    var images: [[String: String]] = []
    var texts: [[String: String]] = []
    var visibleText = ""
    private var inText = false
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        if elementName == "image" { images.append(attributes) }
        if elementName == "text" { texts.append(attributes); inText = true }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { if inText { visibleText += string } }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        if elementName == "text" { inText = false }
    }
}
