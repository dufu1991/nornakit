import AppKit
import Combine
import NornaKit
import NornaExamples
import UniformTypeIdentifiers

@MainActor
final class StudioModel: ObservableObject {
    @Published var source: String {
        didSet {
            UserDefaults.standard.set(source, forKey: "studio.source")
            if let kind = DiagramKind.detect(source) { activeKind = kind }
            if let id = selectedExample,
               DiagramExample.all.first(where: { $0.id == id })?.source(language: language.exampleLanguage) != source {
                selectedExample = nil
            }
        }
    }
    @Published private(set) var activeKind: DiagramKind?
    @Published var language: StudioLanguage = .system {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "studio.language")
            refreshExampleLanguage()
        }
    }
    @Published var appearance: CanvasAppearance = .system {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "studio.appearance") }
    }
    @Published var colorStyle: DiagramColorStyle = .themed {
        didSet { UserDefaults.standard.set(colorStyle.rawValue, forKey: "studio.colorStyle") }
    }
    @Published var customAccent: DiagramAccentColor = .norna {
        didSet { UserDefaults.standard.set(customAccent.hex, forKey: "studio.customAccent") }
    }
    @Published var exportSession: DiagramExportSession?
    @Published private(set) var theme: DiagramTheme = .appleLight
    @Published private(set) var paletteRevision = 0
    @Published var showGrid = false
    @Published var adaptiveLayout = true
    @Published private(set) var availableWidth: CGFloat?
    @Published private(set) var renderedRequest: RenderRequest?
    @Published private(set) var artifact: DiagramArtifact?
    @Published private(set) var renderedSource: String?
    @Published private var renderError: Error?
    var error: String? { renderError.map(StudioLocalization.errorDescription) }
    @Published private(set) var isRendering = false
    @Published var selectedExample: String? = "flowchart"
    @Published var fileError: String?
    private let renderer: any DiagramRendering = NativeDiagramRenderer()

    init() {
        let savedLanguage = StudioLocalization.language
        source = UserDefaults.standard.string(forKey: "studio.source")
            ?? DiagramKind.flowchart.starter.source(language: savedLanguage.exampleLanguage)
        language = savedLanguage
        appearance = UserDefaults.standard.string(forKey: "studio.appearance").flatMap(CanvasAppearance.init(rawValue:)) ?? .system
        colorStyle = UserDefaults.standard.string(forKey: "studio.colorStyle").flatMap(DiagramColorStyle.init(rawValue:)) ?? .themed
        customAccent = UserDefaults.standard.string(forKey: "studio.customAccent").flatMap(DiagramAccentColor.init(hex:)) ?? .norna
        selectedExample = DiagramExample.all.first { example in
            DiagramExampleLanguage.allCases.contains { example.source(language: $0) == source }
        }?.id
        activeKind = DiagramKind.detect(source)
        refreshExampleLanguage()
    }

    struct RenderRequest: Hashable {
        let source: String
        let options: DiagramLayoutOptions
    }

    var resolvedLanguage: StudioLanguage { StudioLanguage(rawValue: language.resolvedIdentifier())! }
    var renderRequest: RenderRequest { RenderRequest(source: source, options: DiagramLayoutOptions(maxWidth: adaptiveLayout ? availableWidth : nil)) }
    var canExport: Bool { artifact != nil && renderedRequest == renderRequest && error == nil }
    var examplesForActiveKind: [DiagramExample] { DiagramExample.all.filter { $0.kind == activeKind } }
    var exampleComparison: DiagramExampleComparison? { activeKind?.exampleComparison }
    var additionalExamplesForActiveKind: [DiagramExample] {
        guard let comparison = exampleComparison else { return examplesForActiveKind }
        return examplesForActiveKind.filter { $0.id != comparison.simple.id && $0.id != comparison.complex.id }
    }

    func openDiagramType(_ kind: DiagramKind?) {
        guard let kind, kind != activeKind else { return }
        loadExample(kind.starter.id)
    }

    func updateAppearance(systemIsDark: Bool, highContrast: Bool) {
        let dark = appearance == .dark || appearance == .system && systemIsDark
        let resolved: DiagramTheme = highContrast ? (dark ? .appleDarkHighContrast : .appleLightHighContrast) : (dark ? .appleDark : .appleLight)
        if theme != resolved { theme = resolved }
    }

    func refreshSystemColors() {
        DiagramTheme.invalidateSystemColors()
        paletteRevision += 1
    }

    func updateAvailableWidth(_ width: CGFloat) {
        let width = max(160, floor(width / 24) * 24)
        if availableWidth != width { availableWidth = width }
    }

    func loadExample(_ id: String) {
        guard let example = DiagramExample.all.first(where: { $0.id == id }) else { return }
        source = example.source(language: language.exampleLanguage)
        selectedExample = id
    }

    func refreshExampleLanguage() {
        guard let id = selectedExample else { return }
        loadExample(id)
    }

    func refresh() async {
        let request = renderRequest
        let snapshot = request.source
        isRendering = true
        renderError = nil
        do {
            try await Task.sleep(for: .milliseconds(250))
            guard !snapshot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                artifact = nil
                renderedSource = nil
                renderedRequest = nil
                isRendering = false
                return
            }
            let result = try await renderer.render(snapshot, options: request.options)
            try Task.checkCancellation()
            guard request == renderRequest else { return }
            artifact = result
            renderedSource = snapshot
            renderedRequest = request
            isRendering = false
        } catch is CancellationError {
            // The replacement task owns the preview state.
        } catch {
            guard !Task.isCancelled, request == renderRequest else { return }
            renderError = error
            isRendering = false
        }
    }

    func openSource() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .text, UTType(filenameExtension: "mmd") ?? .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                self?.source = try String(contentsOf: url, encoding: .utf8)
                self?.selectedExample = nil
            } catch {
                self?.fileError = error.localizedDescription
            }
        }
    }

    func saveSource() {
        save(source, name: "diagram.mmd", type: .plainText)
    }

    func presentExport() {
        guard canExport, let artifact else { return }
        exportSession = DiagramExportSession(artifact: artifact, theme: theme, colorStyle: colorStyle, customAccent: customAccent)
    }

    func saveExport(_ session: DiagramExportSession, prepared: PreparedDiagramExport) async throws -> Bool {
        let options = prepared.options
        let panel = NSSavePanel()
        panel.allowedContentTypes = [options.format.contentType]
        panel.nameFieldStringValue = "norna-\(session.artifact.scene.kind.rawValue).\(options.format.fileExtension)"
        panel.canCreateDirectories = true
        guard await panel.begin() == .OK, let url = panel.url else { return false }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        try prepared.data.write(to: url, options: .atomic)
        return true
    }

    func copySVG() {
        guard canExport, let artifact else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(artifact.themedSVG(theme, colorStyle: colorStyle, customAccent: customAccent), forType: .string)
    }

    private func save(_ text: String, name: String, type: UTType) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.nameFieldStringValue = name
        panel.canCreateDirectories = true
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                self?.fileError = error.localizedDescription
            }
        }
    }
}

enum CanvasAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }
}
