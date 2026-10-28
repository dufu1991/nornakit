import XCTest
import CryptoKit
@testable import NornaKit
@testable import NornaExamples

final class ExampleLanguageTests: XCTestCase {
    func testSharedCatalogPreservesTheOriginalBilingualExamples() {
        XCTAssertEqual(DiagramExample.all.count, 79)
        let records = Dictionary(uniqueKeysWithValues: SharedExampleCatalog.snapshot.examples.map { ($0.id, $0) })
        let fields = DiagramExample.all.flatMap { example -> [String] in
            let record = records[example.id]!
            return [example.id, example.kind.rawValue, example.symbol, example.title,
                record.titles.en, example.source, example.source(language: .english)]
        }
        let digest = SHA256.hash(data: Data(fields.joined(separator: "\0").utf8))
            .map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(digest, "0b02676e05913aeef6d772ea627fe8ff634cb696ffb6d8a40f400fbeb8fe360b")
    }

    func testEveryBundledExampleHasAnEnglishSource() {
        XCTAssertEqual(Set(EnglishExampleSources.all.keys), Set(DiagramExample.all.map(\.id)))
        for example in DiagramExample.all {
            let english = example.source(language: .english)
            XCTAssertFalse(english.isEmpty, example.id)
            XCTAssertFalse(english.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }, example.id)
            XCTAssertEqual(example.source(language: .simplifiedChinese), example.source)
            XCTAssertEqual(DiagramKind.detect(english), example.kind, example.id)
        }
    }

    func testBothLanguagesRenderWithTheSameDiagramContent() async throws {
        let renderer = NativeDiagramRenderer()
        for example in DiagramExample.all {
            let chinese = try await renderer.render(example.source(language: .simplifiedChinese))
            let english = try await renderer.render(example.source(language: .english))
            XCTAssertEqual(english.scene.kind, chinese.scene.kind, example.id)
            XCTAssertEqual(english.scene.nodes.count, chinese.scene.nodes.count, example.id)
            XCTAssertEqual(english.scene.edges.count, chinese.scene.edges.count, example.id)
            XCTAssertEqual(english.scene.groups.count, chinese.scene.groups.count, example.id)
            XCTAssertGreaterThan(english.width, 0, example.id)
            XCTAssertGreaterThan(english.height, 0, example.id)
        }
    }
}
