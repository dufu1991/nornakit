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
    static let all: [String: String] = {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: ExampleResourceBundle.self)
        #endif
        let url = bundle.url(forResource: "examples-en", withExtension: "json", subdirectory: "Resources")!
        return try! JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
    }()
}

private final class ExampleResourceBundle: NSObject {}
