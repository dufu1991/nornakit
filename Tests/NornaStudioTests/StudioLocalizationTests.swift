import Foundation
import NornaKit
import XCTest
@testable import NornaStudio

final class StudioLocalizationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        let saved = ["studio.language", "studio.source"].map { ($0, defaults.object(forKey: $0)) }
        addTeardownBlock {
            for (key, value) in saved {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }
    }

    func testSystemLanguageNegotiation() {
        XCTAssertEqual(StudioLanguage.system.resolvedIdentifier(preferredLanguages: ["zh-Hans-CN", "en-US"]), "zh-Hans")
        XCTAssertEqual(StudioLanguage.system.resolvedIdentifier(preferredLanguages: ["en-GB", "zh-Hans"]), "en")
        XCTAssertEqual(StudioLanguage.system.resolvedIdentifier(preferredLanguages: ["fr-FR", "zh-Hans"]), "zh-Hans")
        XCTAssertEqual(StudioLanguage.system.resolvedIdentifier(preferredLanguages: ["de-DE"]), "en")
        XCTAssertEqual(StudioLanguage.english.resolvedIdentifier(preferredLanguages: ["zh-Hans"]), "en")
        XCTAssertEqual(StudioLanguage.simplifiedChinese.resolvedIdentifier(preferredLanguages: ["en"]), "zh-Hans")
    }

    func testDynamicCatalogTitlesHaveBothLanguages() {
        let titles = DiagramKind.allCases.map(\.title)
            + DiagramCategory.allCases.map(\.title)
            + DiagramColorStyle.allCases.map(\.title)
            + DiagramExportBackground.allCases.map(\.title)
            + DiagramExample.all.map(\.title).filter { !$0.contains(" · ") }
        for title in titles {
            let english = StudioLocalization.text(title, language: .english)
            XCTAssertFalse(english.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }, title)
            XCTAssertEqual(StudioLocalization.text(title, language: .simplifiedChinese), title)
        }
    }

    @MainActor
    func testLanguageSwitchPreservesDraftAndPersistsPreference() {
        let defaults = UserDefaults.standard
        let savedLanguage = defaults.object(forKey: "studio.language")
        defer {
            if let savedLanguage { defaults.set(savedLanguage, forKey: "studio.language") }
            else { defaults.removeObject(forKey: "studio.language") }
        }
        defaults.removeObject(forKey: "studio.language")
        let model = StudioModel()
        XCTAssertEqual(model.language, .system)
        model.source = "flowchart TD\n    A[My draft] --> B[Keep this content]"
        let source = model.source
        let kind = model.activeKind
        let example = model.selectedExample
        let request = model.renderRequest
        model.language = .english
        XCTAssertEqual("搜索图形".studioLocalized, "Search diagrams")
        XCTAssertEqual(StudioLocalization.format("第 %ld 行：%@", 3, "Example"), "Line 3: Example")
        XCTAssertEqual(StudioModel().language, .english)
        model.language = .simplifiedChinese
        XCTAssertEqual("搜索图形".studioLocalized, "搜索图形")
        XCTAssertEqual(model.source, source)
        XCTAssertEqual(model.activeKind, kind)
        XCTAssertEqual(model.selectedExample, example)
        XCTAssertEqual(model.renderRequest, request)
        model.language = .system
        XCTAssertEqual(StudioModel().language, .system)
    }

    @MainActor
    func testSelectedExamplesFollowLanguageAndKeepSelection() {
        let model = StudioModel()
        for example in DiagramExample.all {
            model.language = .simplifiedChinese
            model.loadExample(example.id)
            XCTAssertEqual(model.source, example.source, example.id)
            model.language = .english
            XCTAssertEqual(model.source, example.source(language: .english), example.id)
            XCTAssertEqual(model.selectedExample, example.id)
            XCTAssertEqual(model.activeKind, example.kind)
            model.language = .simplifiedChinese
            XCTAssertEqual(model.source, example.source, example.id)
            XCTAssertEqual(model.selectedExample, example.id)
        }
    }

    @MainActor
    func testSavedExampleUsesCurrentLanguageOnLaunch() {
        let defaults = UserDefaults.standard
        defaults.set(StudioLanguage.english.rawValue, forKey: "studio.language")
        defaults.set(DiagramKind.flowchart.starter.source, forKey: "studio.source")
        let model = StudioModel()
        XCTAssertEqual(model.selectedExample, DiagramKind.flowchart.starter.id)
        XCTAssertEqual(model.source, DiagramKind.flowchart.starter.source(language: .english))
        model.language = .system
        XCTAssertEqual(model.source, DiagramKind.flowchart.starter.source(language: StudioLanguage.system.exampleLanguage))
    }
}
