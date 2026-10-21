import AppKit
import NornaKit

/// Documentation previews use the exact localized sources bundled with the workbench.
@main
struct RenderInlineContent {
    private struct Example: Encodable {
        let id: String
        let sources: [String: String]
    }

    @MainActor
    static func main() async throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let renderer = NativeDiagramRenderer()
        var examples: [Example] = []
        for id in ["sf-symbols-color", "rich-text"] {
            let example = DiagramExample.all.first { $0.id == id }!
            var sources: [String: String] = [:]
            for language in DiagramExampleLanguage.allCases {
                let source = example.source(language: language)
                sources[language.rawValue] = source
                let stem = "inline-\(id)-\(language.rawValue)"
                try source.write(to: output.appendingPathComponent("\(stem).mmd"), atomically: true, encoding: .utf8)
                let artifact = try await renderer.render(source, options: .init(maxWidth: 640))
                for (appearance, theme) in [("light", DiagramTheme.appleLight), ("dark", DiagramTheme.appleDark)] {
                    for format in [DiagramExportFormat.png, .svg, .pdf] {
                        let data = try DiagramExporter.data(for: artifact.scene, theme: theme, colorStyle: .themed, options: .init(format: format, scale: 2, padding: 24))
                        try data.write(to: output.appendingPathComponent("\(stem)-\(appearance).\(format.fileExtension)"))
                    }
                }
            }
            examples.append(Example(id: id, sources: sources))
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(examples).write(to: output.appendingPathComponent("inline-examples.json"))
        print("Rendered 2 bilingual inline-content examples in PNG, SVG, and PDF.")
    }
}
