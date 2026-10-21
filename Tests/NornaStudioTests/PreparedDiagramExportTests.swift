import AppKit
import ImageIO
import NornaKit
import XCTest
@testable import NornaStudio

final class PreparedDiagramExportTests: XCTestCase {
    @MainActor
    func testPreparedFilesMatchSelectedFormatAndDimensions() async throws {
        let artifact = try await NativeDiagramRenderer().render("flowchart TD\nA[Start] --> B[Finish]")
        let session = DiagramExportSession(artifact: artifact, theme: .appleLight, colorStyle: .themed, customAccent: .norna)
        for format in DiagramExportFormat.allCases {
            let options = DiagramExportOptions(format: format, scale: 3, quality: 0.5, padding: 24)
            let prepared = try await PreparedDiagramExport.generate(session: session, options: options)
            XCTAssertEqual(prepared.options, options)
            XCTAssertGreaterThan(prepared.data.count, 100)
            if format == .svg {
                XCTAssertTrue(String(decoding: prepared.data, as: UTF8.self).contains("<svg"))
            } else if format == .pdf {
                let provider = try XCTUnwrap(CGDataProvider(data: prepared.data as CFData))
                let document = try XCTUnwrap(CGPDFDocument(provider))
                XCTAssertEqual(document.numberOfPages, 1)
            } else {
                let source = try XCTUnwrap(CGImageSourceCreateWithData(prepared.data as CFData, nil))
                XCTAssertEqual(CGImageSourceGetType(source) as String?, format.contentType.identifier)
                let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
                let expected = try DiagramExporter.outputSize(for: artifact.scene, options: options)
                XCTAssertEqual(image.width, Int(expected.width))
                XCTAssertEqual(image.height, Int(expected.height))
            }
        }
    }

    @MainActor
    func testCancelledPreparationDoesNotReturnStaleFile() async throws {
        let artifact = try await NativeDiagramRenderer().render("flowchart TD\nA --> B")
        let session = DiagramExportSession(artifact: artifact, theme: .appleLight, colorStyle: .themed, customAccent: .norna)
        let preparation = Task {
            try await PreparedDiagramExport.generate(session: session, options: .init())
        }
        preparation.cancel()
        do {
            _ = try await preparation.value
            XCTFail("Cancelled preparation must not return a file.")
        } catch is CancellationError {
        }
    }
}
