import Foundation
import NornaKit

public enum DiagramExampleLanguage: String, CaseIterable, Sendable {
    case simplifiedChinese = "zh"
    case english = "en"
}

extension DiagramExample {
    /// Localizes bundled examples; external examples retain their original source.
    public func source(language: DiagramExampleLanguage) -> String {
        guard language == .english else { return source }
        return EnglishExampleSources.all[id] ?? source
    }
}

enum EnglishExampleSources {
    static let all: [String: String] = Dictionary(uniqueKeysWithValues:
        SharedExampleCatalog.snapshot.examples.map { ($0.id, $0.sources.en) })
}

enum SharedExampleCatalog {
    struct Languages: Decodable, Sendable {
        let en: String
        let zh: String
    }
    struct Entry: Decodable, Sendable {
        let id: String
        let kind: DiagramKind
        let symbol: String
        let titles: Languages
        let sources: Languages

        var example: DiagramExample {
            DiagramExample(id: id, title: titles.zh, symbol: symbol, source: sources.zh, declaredKind: kind)
        }
    }
    struct Comparison: Decodable, Sendable {
        let kind: DiagramKind
        let simpleId: String
        let complexId: String
        let layoutNotes: Languages
    }
    struct Snapshot: Decodable, Sendable {
        let schemaVersion: Int
        let examples: [Entry]
        let groups: [String: [String]]
        let comparisons: [Comparison]
    }

    static let snapshot: Snapshot = {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: ExampleResourceBundle.self)
        #endif
        let url = bundle.url(forResource: "examples", withExtension: "json", subdirectory: "Resources")!
        let value = try! JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: url))
        precondition(value.schemaVersion == 1, "Unsupported bundled example schema version.")
        return value
    }()

    static let entries: [String: DiagramExample] = Dictionary(uniqueKeysWithValues:
        snapshot.examples.map { ($0.id, $0.example) })

    static func group(_ name: String) -> [DiagramExample] {
        snapshot.groups[name]!.map { entries[$0]! }
    }

    static let comparisons: [DiagramExampleComparison] = snapshot.comparisons.map { comparison in
        DiagramExampleComparison(kind: comparison.kind, simple: entries[comparison.simpleId]!,
            complex: entries[comparison.complexId]!, layoutNote: comparison.layoutNotes.zh)
    }
}

private final class ExampleResourceBundle: NSObject {}
