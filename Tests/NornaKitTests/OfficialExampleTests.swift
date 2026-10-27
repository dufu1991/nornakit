import CryptoKit
import XCTest
@testable import NornaKit
import NornaExamples

struct OfficialResult: Codable {
    let id: String
    let kind: String
    let status: String
    let code: String?
    let message: String?
    let line: Int?
    let width: Double?
    let height: Double?
}

struct OfficialWidthResult: Codable {
    let requestedWidth: Int
    let result: OfficialResult
}

private struct OfficialReference: Decodable {
    struct Variant: Decodable { let file: String; let sha256: String }
    let id: String
    let pageURL: String
    let ordinal: Int
    let status: String
    let variants: [String: Variant]
}

final class OfficialExampleTests: XCTestCase {
    private var baselineDirectory: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Baselines")
    }

    func testWebsiteReferencesCoverEverySourceAndKeepTheirHashes() throws {
        let references = try JSONDecoder().decode([OfficialReference].self, from: Data(contentsOf: baselineDirectory.appendingPathComponent("official-reference.json")))
        XCTAssertEqual(references.count, 659)
        XCTAssertEqual(Set(references.map(\.id)), Set(OfficialExampleCatalog.snapshot.examples.map(\.id)))
        var checked = Set<String>()
        for reference in references {
            XCTAssertEqual(reference.status, "rendered", reference.id)
            XCTAssertNotNil(reference.variants["640"], reference.id)
            for variant in reference.variants.values where checked.insert(variant.file).inserted {
                XCTAssertEqual(variant.file, variant.sha256 + ".svg")
                let data = try Data(contentsOf: baselineDirectory.appendingPathComponent("OfficialReference/" + variant.file))
                XCTAssertEqual(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), variant.sha256)
                XCTAssertTrue(XMLParser(data: data).parse(), variant.file)
            }
        }
        XCTAssertEqual(checked.count, 852)
    }

    func testOfficialRadarAndVennLabelsWorkWithoutSourceRewriting() async throws {
        for id in ["official-39b48990c83837bf", "official-3e866a35e9ee4a7a", "official-7401455503e883e6", "official-cd2ead2b0d04ca5f", "official-dbe2e15b8822e28a"] {
            let example = try XCTUnwrap(OfficialExampleCatalog.snapshot.examples.first { $0.id == id })
            let artifact = try await NativeDiagramRenderer().render(example.source, options: .init(maxWidth: 320))
            XCTAssertEqual(artifact.scene.kind, example.kind)
            XCTAssertTrue(XMLParser(data: Data(artifact.svg.utf8)).parse())
            if id == "official-cd2ead2b0d04ca5f" { XCTAssertTrue(artifact.svg.contains("React")); XCTAssertTrue(artifact.svg.contains("OpenAPI")) }
        }
    }
    func testSnapshotIsCompleteAndOriginalSourcesHaveValidHashes() throws {
        let snapshot = try OfficialExampleCatalog.load()
        XCTAssertEqual(snapshot.schemaVersion, 1)
        XCTAssertEqual(snapshot.pages.count, 33)
        XCTAssertEqual(snapshot.pages.reduce(0) { $0 + $1.exampleCount }, 659)
        XCTAssertEqual(snapshot.examples.count, 600)
        XCTAssertEqual(Set(snapshot.examples.map(\.id)).count, snapshot.examples.count)
        XCTAssertEqual(Set(snapshot.examples.map(\.kind)).count, 32)
        for example in snapshot.examples {
            let hash = SHA256.hash(data: Data(example.source.utf8)).map { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(hash, example.sha256, example.id)
            XCTAssertFalse(example.origins.isEmpty, example.id)
            XCTAssertTrue(example.origins.allSatisfy { $0.url.hasPrefix("https://pele.run/examples") && $0.ordinal > 0 }, example.id)
        }
    }

    func testEveryOfficialExampleIsAttemptedAndSuccessfulBaselineDoesNotRegress() async throws {
        let snapshot = try OfficialExampleCatalog.load(), renderer = NativeDiagramRenderer()
        let baselineURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Baselines/official-results.json")
        let baseline: [OfficialResult] = FileManager.default.fileExists(atPath: baselineURL.path)
            ? try JSONDecoder().decode([OfficialResult].self, from: Data(contentsOf: baselineURL)) : []
        let passing = Set(baseline.filter { $0.status == "rendered" }.map(\.id))
        var results: [OfficialResult] = []
        for example in snapshot.examples {
            do {
                let artifact = try await renderer.render(example.source)
                let parser = XMLParser(data: Data(artifact.svg.utf8))
                let valid = parser.parse() && artifact.width.isFinite && artifact.height.isFinite && artifact.width > 0 && artifact.height > 0
                XCTAssertTrue(valid, example.id)
                results.append(OfficialResult(id: example.id, kind: example.kind.rawValue, status: valid ? "rendered" : "invalid-output",
                    code: nil, message: parser.parserError?.localizedDescription, line: nil, width: artifact.width, height: artifact.height))
            } catch let error as DiagramRenderError {
                XCTAssertFalse(passing.contains(example.id), "Regression \(example.id): \(error.message)")
                results.append(OfficialResult(id: example.id, kind: example.kind.rawValue, status: "rejected", code: error.code,
                    message: error.message, line: error.line, width: nil, height: nil))
            } catch { XCTFail("Unexpected failure \(example.id): \(error)") }
        }
        XCTAssertEqual(results.count, snapshot.examples.count)
        if let output = ProcessInfo.processInfo.environment["NORNA_BASELINE_OUTPUT"] {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(results).write(to: URL(fileURLWithPath: output))
        }
        print("Official source baseline: \(results.filter { $0.status == "rendered" }.count)/\(results.count) rendered; no visual equivalence claim")
    }

    func testEveryOfficialExampleAtThreeContainerWidths() async throws {
        let snapshot = try OfficialExampleCatalog.load(), renderer = NativeDiagramRenderer()
        let passing = Set(OfficialExampleCatalog.results.values.filter { $0.status == "rendered" }.map(\.id))
        var results: [OfficialWidthResult] = []
        for example in snapshot.examples {
            for width in [320, 480, 640] {
                let result: OfficialResult
                do {
                    let artifact = try await renderer.render(example.source, options: .init(maxWidth: CGFloat(width)))
                    XCTAssertTrue(XMLParser(data: Data(artifact.svg.utf8)).parse(), "\(example.id) at \(width)")
                    for primitive in artifact.scene.primitives where !primitive.bounds.isNull {
                        XCTAssertGreaterThanOrEqual(primitive.bounds.minX, 0, example.id)
                        XCTAssertGreaterThanOrEqual(primitive.bounds.minY, 0, example.id)
                        XCTAssertLessThanOrEqual(primitive.bounds.maxX, artifact.width + 0.01, example.id)
                        XCTAssertLessThanOrEqual(primitive.bounds.maxY, artifact.height + 0.01, example.id)
                    }
                    if let directory = ProcessInfo.processInfo.environment["NORNA_OFFICIAL_SVG_DIR"], width != 480 {
                        let url = URL(fileURLWithPath: directory, isDirectory: true)
                        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                        try artifact.svg.write(to: url.appendingPathComponent("\(example.id)-\(width).svg"), atomically: true, encoding: .utf8)
                    }
                    result = OfficialResult(id: example.id, kind: example.kind.rawValue, status: "rendered", code: nil, message: nil, line: nil, width: artifact.width, height: artifact.height)
                } catch let error as DiagramRenderError {
                    XCTAssertFalse(passing.contains(example.id), "Width regression \(example.id) at \(width): \(error.message)")
                    result = OfficialResult(id: example.id, kind: example.kind.rawValue, status: "rejected", code: error.code, message: error.message, line: error.line, width: nil, height: nil)
                }
                results.append(OfficialWidthResult(requestedWidth: width, result: result))
            }
        }
        XCTAssertEqual(results.count, snapshot.examples.count * 3)
        if let output = ProcessInfo.processInfo.environment["NORNA_LAYOUT_OUTPUT"] {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(results).write(to: URL(fileURLWithPath: output))
        }
    }
}
