import AppKit
import ImageIO
import XCTest
@testable import NornaKit
import NornaExamples

final class DiagramExportTests: XCTestCase {
    private let source = """
    flowchart TD
        A[提交订单] --> B{验证通过？}
        B -->|通过| C[处理请求]
        B -->|失败| D[返回错误]
    """

    @MainActor
    func testEveryFormatHasExpectedDimensionsAndRealTransparency() async throws {
        let artifact = try await NativeDiagramRenderer().render(source)
        for format in DiagramExportFormat.allCases {
            for background in DiagramExportBackground.allCases where background != .transparent || format.supportsTransparency {
                let options = DiagramExportOptions(format: format, background: background, scale: 2, padding: 12)
                let data = try DiagramExporter.data(for: artifact.scene, colorStyle: .custom,
                    customAccent: XCTUnwrap(DiagramAccentColor(hex: "#26804b")), options: options)
                let expected = try DiagramExporter.outputSize(for: artifact.scene, options: options)
                XCTAssertGreaterThan(data.count, 200, format.rawValue)
                if format == .svg {
                    let proof = SVGCanvasProof()
                    let parser = XMLParser(data: data)
                    parser.delegate = proof
                    XCTAssertTrue(parser.parse())
                    XCTAssertEqual(try XCTUnwrap(Double(proof.attributes["width"]!)), Double(expected.width), accuracy: 0.01)
                    XCTAssertEqual(try XCTUnwrap(Double(proof.attributes["height"]!)), Double(expected.height), accuracy: 0.01)
                    XCTAssertEqual(proof.backgroundRectangles, background == .theme ? 1 : 0)
                } else if format == .pdf {
                    let provider = try XCTUnwrap(CGDataProvider(data: data as CFData))
                    let document = try XCTUnwrap(CGPDFDocument(provider))
                    let page = try XCTUnwrap(document.page(at: 1))
                    XCTAssertEqual(document.numberOfPages, 1)
                    XCTAssertEqual(page.getBoxRect(.mediaBox).width, expected.width, accuracy: 0.01)
                    XCTAssertEqual(page.getBoxRect(.mediaBox).height, expected.height, accuracy: 0.01)
                    var resources: CGPDFDictionaryRef?, fonts: CGPDFDictionaryRef?
                    XCTAssertTrue(CGPDFDictionaryGetDictionary(try XCTUnwrap(page.dictionary), "Resources", &resources))
                    XCTAssertTrue(CGPDFDictionaryGetDictionary(try XCTUnwrap(resources), "Font", &fonts), "PDF should retain native vector text.")
                    let context = try bitmapContext(width: 64, height: 64)
                    context.scaleBy(x: 64 / expected.width, y: 64 / expected.height)
                    context.drawPDFPage(page)
                    let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(context.makeImage()))
                    XCTAssertEqual(try XCTUnwrap(bitmap.colorAt(x: 0, y: 0)).alphaComponent, background == .transparent ? 0 : 1, accuracy: 0.01)
                } else {
                    let decoded = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
                    XCTAssertEqual(CGImageSourceGetType(decoded) as String?, format.contentType.identifier)
                    let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(decoded, 0, nil))
                    XCTAssertEqual(image.width, Int(expected.width))
                    XCTAssertEqual(image.height, Int(expected.height))
                    let bitmap = NSBitmapImageRep(cgImage: image)
                    let corner = try XCTUnwrap(bitmap.colorAt(x: 0, y: 0))
                    XCTAssertEqual(corner.alphaComponent, background == .transparent ? 0 : 1, accuracy: 0.01)
                    if background == .theme {
                        let value = try XCTUnwrap(corner.usingColorSpace(.sRGB))
                        let expected = CoreGraphicsDiagramPainter.color(DiagramTheme.appleLight.background)
                        XCTAssertEqual(value.redComponent, expected.redComponent, accuracy: 0.03)
                    }
                }
                if let directory = ProcessInfo.processInfo.environment["NORNA_EXPORT_FIXTURE_DIR"] {
                    let folder = URL(fileURLWithPath: directory, isDirectory: true)
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    try data.write(to: folder.appendingPathComponent("flowchart-\(background.rawValue).\(format.fileExtension)"))
                }
            }
        }
    }

    func testExportValidationRejectsUnsupportedAndOversizedRequests() async throws {
        let scene = try await NativeDiagramRenderer().render(source).scene
        let invalid: [DiagramExportOptions] = [
            .init(format: .jpeg, background: .transparent), .init(scale: .infinity), .init(scale: 0),
            .init(quality: .nan), .init(quality: 1.1), .init(padding: -1), .init(padding: .infinity)
        ]
        for options in invalid { XCTAssertThrowsError(try DiagramExporter.data(for: scene, options: options)) }
        let huge = DiagramScene(size: CGSize(width: 30_000, height: 2000), nodes: [], edges: [])
        XCTAssertThrowsError(try DiagramExporter.data(for: huge))
        XCTAssertNoThrow(try DiagramExporter.outputSize(for: huge, options: .init(format: .svg)))
    }

    @MainActor
    func testJPEGQualityAffectsCompressionAndPNGRemainsLossless() async throws {
        let scene = try await NativeDiagramRenderer().render(source).scene
        let low = try DiagramExporter.data(for: scene, options: .init(format: .jpeg, quality: 0.1))
        let high = try DiagramExporter.data(for: scene, options: .init(format: .jpeg, quality: 1))
        XCTAssertNotEqual(low, high)
        XCTAssertGreaterThan(high.count, low.count)
        let pngLow = try DiagramExporter.data(for: scene, options: .init(quality: 0.1))
        let pngHigh = try DiagramExporter.data(for: scene, options: .init(quality: 1))
        XCTAssertEqual(pngLow, pngHigh)
    }

    @MainActor
    func testEveryFamilyExportsNativePNGWithCustomColor() async throws {
        let renderer = NativeDiagramRenderer()
        for kind in DiagramKind.allCases {
            let artifact = try await renderer.render(kind.starter.source, options: .init(maxWidth: 640))
            let data = try DiagramExporter.data(for: artifact.scene, theme: .appleDark, colorStyle: .custom,
                customAccent: XCTUnwrap(DiagramAccentColor(hex: "#00ff00")),
                options: .init(background: .transparent, scale: 1, padding: 8))
            let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
            let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            XCTAssertGreaterThan(image.width, 0, kind.rawValue)
            XCTAssertGreaterThan(image.height, 0, kind.rawValue)
        }
    }

    private func bitmapContext(width: Int, height: Int) throws -> CGContext {
        try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    }
}

private final class SVGCanvasProof: NSObject, XMLParserDelegate {
    var attributes: [String: String] = [:]
    var backgroundRectangles = 0
    private var depth = 0

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes attributeDict: [String: String]) {
        if depth == 0 { attributes = attributeDict }
        if depth == 1, elementName == "rect" { backgroundRectangles += 1 }
        depth += 1
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) { depth -= 1 }
}
