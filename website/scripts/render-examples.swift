import AppKit
import NornaKit

/// Renders the site's gallery directly from the workbench's bilingual examples.
@main
struct RenderExamples {
    private struct SiteExample: Encodable {
        let id: String
        let builtinID: String
        let zh: String
        let en: String
        let sources: [String: String]
    }

    @MainActor
    static func main() async throws {
        let site = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let assets = site.appendingPathComponent("assets", isDirectory: true)
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        let titles = ["Flowchart", "Sequence", "Class", "State", "Entity relationship", "Pie", "Gantt", "Git graph", "Mind map", "Timeline", "User journey", "XY chart", "Quadrant", "Requirement", "C4 architecture", "Sankey", "Block", "Packet", "Kanban", "Architecture", "Radar", "Treemap", "Info", "Agent flow", "Use case", "Railroad", "Tree view", "Venn", "Cynefin", "Wardley map", "Swimlane", "Fishbone", "Event modeling"]
        var definitions = zip(DiagramKind.allCases, titles).map { kind, title in
            (id: kind.rawValue, example: kind.starter, english: title)
        }
        let symbols = [
            ("sf-symbols", "SF Symbols Icons"),
            ("sf-symbols-wrapping", "SF Symbols Wrapping"),
            ("sequence-sf-symbols", "SF Symbols Messages")
        ].map { id, title in
            (id: "example-\(id)", example: DiagramExample.all.first { $0.id == id }!, english: title)
        }
        definitions.insert(contentsOf: symbols, at: 1)
        let renderer = NativeDiagramRenderer()
        var examples: [SiteExample] = []
        for definition in definitions {
            let example = definition.example
            var sources: [String: String] = [:]
            for language in DiagramExampleLanguage.allCases {
                let source = example.source(language: language)
                sources[language.rawValue] = source
                let stem = "\(definition.id)-\(language.rawValue)"
                try source.write(to: assets.appendingPathComponent("\(stem).mmd"), atomically: true, encoding: .utf8)
                let artifact = try await renderer.render(source, options: .init(maxWidth: 640))
                for (appearance, theme) in [("light", DiagramTheme.appleLight), ("dark", DiagramTheme.appleDark)] {
                    let data = try DiagramExporter.data(for: artifact.scene, theme: theme, colorStyle: .themed,
                        options: .init(format: .png, scale: 2, padding: 24))
                    try data.write(to: assets.appendingPathComponent("\(stem)-\(appearance).png"))
                }
            }
            examples.append(SiteExample(id: definition.id, builtinID: example.id,
                zh: definition.id.hasPrefix("example-") ? example.title : example.kind.title,
                en: definition.english, sources: sources))
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(examples).write(to: site.appendingPathComponent("examples.json"))
        print("Rendered \(examples.count) bilingual examples in light and dark appearances.")
    }
}
