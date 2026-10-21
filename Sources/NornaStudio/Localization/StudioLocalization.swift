import Foundation
import NornaKit

enum StudioLanguage: String, CaseIterable, Identifiable {
    case system
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "跟随系统"
        case .simplifiedChinese: "简体中文"
        case .english: "English"
        }
    }

    func resolvedIdentifier(preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        guard self == .system else { return rawValue }
        return Bundle.preferredLocalizations(from: ["en", "zh-Hans"], forPreferences: preferredLanguages)[0]
    }

    var locale: Locale { Locale(identifier: resolvedIdentifier()) }
    var exampleLanguage: DiagramExampleLanguage {
        resolvedIdentifier() == "zh-Hans" ? .simplifiedChinese : .english
    }
}

enum StudioLocalization {
    static var language: StudioLanguage {
        UserDefaults.standard.string(forKey: "studio.language").flatMap(StudioLanguage.init(rawValue:)) ?? .system
    }

    private static let bundles: [String: Bundle] = {
        #if SWIFT_PACKAGE
        let resources = Bundle.module
        #else
        let resources = Bundle.main
        #endif
        return Dictionary(uniqueKeysWithValues: ["en", "zh-Hans"].map { identifier in
            guard let url = resources.url(forResource: identifier, withExtension: "lproj"),
                  let bundle = Bundle(url: url) else {
                preconditionFailure("Missing localization resources: \(identifier)")
            }
            return (identifier, bundle)
        })
    }()

    static func text(_ key: String, language: StudioLanguage = StudioLocalization.language) -> String {
        bundles[language.resolvedIdentifier()]!.localizedString(forKey: key, value: nil, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: language.locale, arguments: arguments)
    }

    static func errorDescription(_ error: Error) -> String {
        guard let error = error as? DiagramRenderError else { return error.localizedDescription }
        let message = text(error.message)
        guard let line = error.line, line > 0 else { return message }
        return format("第 %ld 行：%@", line, message)
    }
}

extension String {
    var studioLocalized: String { StudioLocalization.text(self) }
}

extension DiagramExample {
    func studioTitle(language: StudioLanguage) -> String {
        if title == kind.title { return StudioLocalization.text(title, language: language) }
        let prefix = kind.title + " · "
        if title.hasPrefix(prefix) {
            return StudioLocalization.text(kind.title, language: language) + " · " + StudioLocalization.text(String(title.dropFirst(prefix.count)), language: language)
        }
        return StudioLocalization.text(title, language: language)
    }
}
