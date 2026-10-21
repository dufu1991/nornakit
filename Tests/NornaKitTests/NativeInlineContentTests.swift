import AppKit
import ImageIO
import XCTest
@testable import NornaKit

final class NativeInlineContentTests: XCTestCase {
    func testRichStylesWrapWithoutLosingNestingOrExplicitBreaks() throws {
        let text = "[b][color=#2563eb]粗体文字 :sf:cloud.sun.fill@multicolor: 与说明文字\n第二行继续使用相同样式[/color][/b]"
        let lines = TextMeasurement.lines(text, maxWidth: 90)
        XCTAssertGreaterThan(lines.count, 3)
        for line in lines {
            let runs = InlineText.line(line, size: 16).runs
            XCTAssertTrue(runs.allSatisfy { $0.style.bold && $0.style.color == "#2563eb" })
            XCTAssertLessThanOrEqual(InlineText.line(line, size: 16).width, 90)
        }
        let segments = lines.flatMap { InlineText.styledSegments($0) }
        XCTAssertEqual(segments.filter { if case .configuredSymbol = $0.segment { return true }; return false }.count, 1)
        let visible = segments.map { $0.segment.source }.joined()
        XCTAssertFalse(visible.contains("[b]"))
        XCTAssertTrue(visible.contains("第二行继续使用相同样式"))
        for literal in ["[b]not closed", "[unknown]literal[/unknown]", "[color=red]literal[/color]", "[b][i]crossed[/b][/i]"] {
            XCTAssertEqual(InlineText.styledSegments(literal).map { $0.segment.source }.joined(), literal)
        }
        XCTAssertFalse(InlineText.svg(["[b][/b]"], frame: .zero, size: 16, lineHeight: 22, color: "#000000").contains("[b]"))
        let english = "[b]Bold emphasis[/b] and [i]italic details[/i]"
        let wordLines = TextMeasurement.lines(english, maxWidth: TextMeasurement.width("[b]Bold emphasis[/b] ") + 1)
        let visibleLines = wordLines.map { InlineText.styledSegments($0).map { $0.segment.source }.joined() }
        XCTAssertEqual(visibleLines.joined(), "Bold emphasis and italic details")
        XCTAssertEqual(visibleLines.first, "Bold emphasis ")
        XCTAssertTrue(visibleLines.contains { $0.contains("italic") })
        let chinese = "中文内容很多 甲乙丙丁戊己"
        XCTAssertEqual(TextMeasurement.lines(chinese, maxWidth: TextMeasurement.width("中文内容很多 甲乙") + 1).first, "中文内容很多 甲乙")
    }

    func testNativeFontsAndDecorationsUseMeasuredRuns() throws {
        let line = InlineText.line("[b]Bold[/b] [i]Italic[/i] [code]code[/code] [u]under[/u] [s]gone[/s]", size: 20)
        XCTAssertTrue(line.runs.contains { $0.style.bold && $0.font.fontDescriptor.symbolicTraits.contains(.bold) })
        XCTAssertTrue(line.runs.contains { $0.style.italic && $0.font.fontDescriptor.symbolicTraits.contains(.italic) })
        XCTAssertTrue(line.runs.contains { $0.style.mono && $0.font.isFixedPitch })
        XCTAssertLessThan(line.width, InlineText.line("[bogus]Bold[/bogus] [bogus]Italic[/bogus] [bogus]code[/bogus]", size: 20).width)
        for alignment in [TextAlignment.leading, .center, .trailing] {
            let frame = CGRect(x: 40, y: 10, width: 420, height: 50)
            let svg = InlineText.svg(["[b]Bold[/b] [i]Italic[/i] [u]under[/u] [s]gone[/s]"], frame: frame, size: 20, lineHeight: 28, color: "#000000", alignment: alignment)
            let proof = try parse(svg)
            let width = InlineText.line("[b]Bold[/b] [i]Italic[/i] [u]under[/u] [s]gone[/s]", size: 20).width
            XCTAssertEqual(try XCTUnwrap(Double(proof.texts.first!["x"]!)), InlineText.origin(width: width, frame: frame, alignment: alignment), accuracy: 0.01)
            XCTAssertTrue(svg.contains("font-style=\"italic\""))
            XCTAssertEqual(proof.paths, 2)
            XCTAssertFalse(proof.text.contains("["))
        }
    }

    func testSymbolModesPreserveMultipleColorsAndTint() throws {
        let modes = ["monochrome", "hierarchical", "multicolor", "palette(#2563eb,#f59e0b)"]
        var fingerprints: [Data] = []
        for mode in modes {
            let token = ":sf:cloud.sun.fill@\(mode):"
            XCTAssertEqual(TextMeasurement.lines(token + token, maxWidth: 30), [token, token])
            let proof = try parse(InlineText.svg([token], frame: .zero, size: 30, lineHeight: 42, color: "#a03276"))
            XCTAssertEqual(proof.images.count, 1)
            let data = try decoded(proof.images[0])
            fingerprints.append(data)
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data))
            var colors = Set<String>()
            for y in 0..<bitmap.pixelsHigh {
                for x in 0..<bitmap.pixelsWide {
                    let pixel = try XCTUnwrap(bitmap.colorAt(x: x, y: y))
                    if pixel.alphaComponent > 0.95 {
                        colors.insert("\(Int((pixel.redComponent * 10).rounded()))/\(Int((pixel.greenComponent * 10).rounded()))/\(Int((pixel.blueComponent * 10).rounded()))")
                    }
                }
            }
            if mode == "multicolor" || mode.hasPrefix("palette") { XCTAssertGreaterThan(colors.count, 1, mode) }
        }
        XCTAssertEqual(Set(fingerprints).count, 4)
        XCTAssertEqual(InlineText.segments(":sf:cloud.sun.fill@unsupported:"), [.text(":sf:cloud.sun.fill@unsupported:")])
    }

    @MainActor
    func testRichTextAndMulticolorSymbolsSurviveEveryExport() async throws {
        let source = "flowchart TD\n A[\"[b]Before[/b] :sf:cloud.sun.fill@multicolor: [i]after[/i]<br/>[color=#2563eb][u]Styled label[/u][/color]\"]"
        let artifact = try await NativeDiagramRenderer().render(source)
        let flow = try await NativeFlowchartRenderer().render(source)
        XCTAssertEqual(artifact.scene, flow.scene)
        for format in DiagramExportFormat.allCases {
            for theme in [DiagramTheme.appleLight, .appleDark] {
                let data = try DiagramExporter.data(for: artifact.scene, theme: theme, options: .init(format: format, background: format == .jpeg ? .theme : .transparent))
                if format == .svg {
                    let proof = try parse(String(decoding: data, as: UTF8.self))
                    XCTAssertEqual(proof.images.count, 1)
                    XCTAssertEqual(proof.images[0]["data-symbol-mode"], "multicolor")
                    XCTAssertFalse(proof.text.contains("[b]"))
                    XCTAssertFalse(proof.text.contains(":sf:"))
                    XCTAssertNotNil(NSBitmapImageRep(data: try decoded(proof.images[0])))
                    XCTAssertTrue(proof.texts.contains { $0["font-style"] == "italic" })
                    XCTAssertTrue(proof.texts.contains { $0["fill"] == "#2563eb" })
                } else if format == .pdf {
                    let document = try XCTUnwrap(CGPDFDocument(try XCTUnwrap(CGDataProvider(data: data as CFData))))
                    XCTAssertEqual(document.numberOfPages, 1)
                } else {
                    XCTAssertNotNil(CGImageSourceCreateWithData(data as CFData, nil))
                }
            }
        }
    }

    func testRemovedImageNotationIsOrdinaryText() throws {
        let text = "Before :img:norna: after"
        XCTAssertEqual(InlineText.segments(text), [.text(text)])
        XCTAssertEqual(TextMeasurement.lines(":img:norna:", maxWidth: 1).joined(), ":img:norna:")
        let svg = InlineText.svg([text], frame: .zero, size: 16, lineHeight: 22, color: "#000000")
        let proof = try parse(svg)
        XCTAssertTrue(proof.images.isEmpty)
        XCTAssertEqual(proof.text, text)
    }

    @MainActor
    func testRichTextAndSymbolPixelsMatchBetweenPDFAndPNG() async throws {
        let text = "[b]Text[/b] [i]Italic[/i] [u]under[/u] [s]gone[/s] :sf:cloud.sun.fill@multicolor:"
        let primitive = ScenePrimitive(geometry: .text(SceneText(text: text, frame: CGRect(x: 20, y: 20, width: 400, height: 60), size: 24)))
        let scene = DiagramScene(size: CGSize(width: 440, height: 100), nodes: [], edges: [], primitives: [primitive])
        var bounds: [CGRect] = []
        for format in [DiagramExportFormat.png, .pdf] {
            let data = try DiagramExporter.data(for: scene, options: .init(format: format, background: .transparent, scale: 1, padding: 0))
            let bitmap: NSBitmapImageRep
            if format == .png { bitmap = try XCTUnwrap(NSBitmapImageRep(data: data)) }
            else {
                let value = try XCTUnwrap(CGPDFDocument(try XCTUnwrap(CGDataProvider(data: data as CFData))))
                let context = try XCTUnwrap(CGContext(data: nil, width: 440, height: 100, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.drawPDFPage(try XCTUnwrap(value.page(at: 1)))
                bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(context.makeImage()))
            }
            var bound = CGRect.null
            for y in 0..<bitmap.pixelsHigh {
                for x in 0..<bitmap.pixelsWide where bitmap.colorAt(x: x, y: y)!.alphaComponent > 0.5 {
                    bound = bound.union(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
            XCTAssertGreaterThan(bound.width, 150)
            bounds.append(bound)
        }
        XCTAssertEqual(bounds[0].minX, bounds[1].minX, accuracy: 1)
        XCTAssertEqual(bounds[0].maxX, bounds[1].maxX, accuracy: 1)
        XCTAssertEqual(bounds[0].minY, bounds[1].minY, accuracy: 1)
        XCTAssertEqual(bounds[0].maxY, bounds[1].maxY, accuracy: 1)
    }

    private func parse(_ svg: String) throws -> InlineContentSVGProof {
        let proof = InlineContentSVGProof(), parser = XMLParser(data: Data(svg.utf8))
        parser.delegate = proof
        XCTAssertTrue(parser.parse(), parser.parserError?.localizedDescription ?? "")
        return proof
    }
    private func decoded(_ attributes: [String: String]) throws -> Data {
        try XCTUnwrap(Data(base64Encoded: try XCTUnwrap(attributes["href"]).components(separatedBy: ",")[1]))
    }
}

private final class InlineContentSVGProof: NSObject, XMLParserDelegate {
    var images: [[String: String]] = [], texts: [[String: String]] = []
    var paths = 0, text = ""
    private var inText = false
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        if name == "image" { images.append(attributes) }
        if name == "text" { texts.append(attributes); inText = true }
        if name == "path" { paths += 1 }
    }
    func parser(_ parser: XMLParser, foundCharacters value: String) { if inText { text += value } }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) { if name == "text" { inText = false } }
}
