import Foundation

public struct DiagramArtifact: Sendable, Equatable {
    public let scene: DiagramScene
    public var width: Double { scene.size.width }
    public var height: Double { scene.size.height }
    public var type: String { scene.kind.rawValue }
    public var mermaidType: String { scene.kind.mermaidType }
    public var svg: String { themedSVG(.appleLight) }

    public func themedSVG(_ theme: DiagramTheme, colorStyle: DiagramColorStyle = .neutral, customAccent: DiagramAccentColor = .norna) -> String {
        SVGExporter.export(scene, theme: theme, colorStyle: colorStyle, customAccent: customAccent)
    }
}

public struct DiagramRenderError: LocalizedError, Sendable, Equatable {
    public let message: String
    public let code: String
    public let line: Int?
    public let column: Int?

    public init(message: String, code: String, line: Int? = nil, column: Int? = nil) {
        self.message = message
        self.code = code
        self.line = line
        self.column = column
    }

    public var errorDescription: String? { message }
}

public protocol DiagramRendering: Sendable {
    func render(_ source: String) async throws -> DiagramArtifact
    func render(_ source: String, options: DiagramLayoutOptions) async throws -> DiagramArtifact
}

public actor NativeFlowchartRenderer: DiagramRendering {
    public init() {}

    public func render(_ source: String) async throws -> DiagramArtifact {
        try await render(source, options: .init())
    }

    public func render(_ source: String, options: DiagramLayoutOptions) async throws -> DiagramArtifact {
        try options.validate()
        let document = try MermaidDocument.prepare(source)
        let model = try MermaidFlowchartParser.parse(document.body)
        let scene = try AdaptiveFlowLayout.layout(model, options: options).addingTitle(document.title)
        return DiagramArtifact(scene: scene)
    }
}
