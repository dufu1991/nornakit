import Foundation

/// Routes every registered diagram family to Swift parsing and native geometry.
public actor NativeDiagramRenderer: DiagramRendering {
    public init() {}
    private var cachedFlow: (source: String, model: FlowchartModel)?
    private var cachedSequence: (source: String, model: SequenceModel)?

    public func render(_ source: String) async throws -> DiagramArtifact {
        try await render(source, options: .init())
    }

    public func render(_ source: String, options: DiagramLayoutOptions) async throws -> DiagramArtifact {
        try options.validate()
        guard source.utf16.count <= 50_000 else { throw DiagramRenderError(message: "源码超过 50000 个字符。", code: "limit") }
        guard !source.unicodeScalars.contains(where: { $0.value < 32 && ![9, 10, 13].contains($0.value) }) else { throw DiagramRenderError(message: "源码包含无法导出的控制字符。", code: "syntax") }
        try Task.checkCancellation()
        let document = try MermaidDocument.prepare(source)
        let source = document.body
        guard let kind = DiagramKind.detect(source) else { throw DiagramRenderError(message: "无法识别图表声明，请从示例中选择一种图形。", code: "unsupported-diagram", line: DiagramSyntax.lines(source).first?.number) }
        var scene: DiagramScene
        switch kind {
        case .flowchart:
            let model = try cachedFlow.flatMap { $0.source == source ? $0.model : nil } ?? MermaidFlowchartParser.parse(source)
            cachedFlow = (source, model)
            scene = try AdaptiveFlowLayout.layout(model, options: options)
        case .sequence:
            let model = try cachedSequence.flatMap { $0.source == source ? $0.model : nil } ?? SequenceDiagram.parse(source)
            cachedSequence = (source, model)
            scene = try SequenceDiagram.layout(model, options: options)
        case .classDiagram: scene = try ClassDiagram.render(source, options: options)
        case .state: scene = try StateDiagram.render(source, options: options)
        case .er: scene = try ERDiagram.render(source, options: options)
        case .pie: scene = try DataCharts.pie(source, options: options)
        case .xychart: scene = try DataCharts.xy(source, options: options)
        case .quadrantChart: scene = try DataCharts.quadrant(source)
        case .radar: scene = try DataCharts.radar(source, options: options)
        case .mindmap: scene = try HierarchyDiagrams.mindmap(source, options: options)
        case .treeView: scene = try HierarchyDiagrams.tree(source)
        case .treemap: scene = try HierarchyDiagrams.treemap(source, options: options)
        case .ishikawa: scene = try HierarchyDiagrams.ishikawa(source)
        case .kanban: scene = try HierarchyDiagrams.kanban(source, options: options)
        case .timeline: scene = try TemporalDiagrams.timeline(source, options: options)
        case .journey: scene = try TemporalDiagrams.journey(source, options: options)
        case .gantt: scene = try TemporalDiagrams.gantt(source, options: options)
        case .gitGraph: scene = try GitDiagram.render(source)
        case .packet: scene = try PacketEventDiagrams.packet(source)
        case .eventmodeling: scene = try PacketEventDiagrams.events(source)
        case .requirement: scene = try ArchitectureDiagrams.requirement(source, options: options)
        case .c4: scene = try ArchitectureDiagrams.c4(source, options: options)
        case .architecture: scene = try ArchitectureDiagrams.architecture(source, options: options)
        case .usecase: scene = try ArchitectureDiagrams.usecase(source, options: options)
        case .agentflow: scene = try BlockLaneDiagrams.agent(source, options: options)
        case .block: scene = try BlockLaneDiagrams.block(source)
        case .swimlane: scene = try BlockLaneDiagrams.swimlane(source, options: options)
        case .sankey: scene = try SpatialDataDiagrams.sankey(source)
        case .venn: scene = try SpatialDataDiagrams.venn(source)
        case .cynefin: scene = try SpatialDataDiagrams.cynefin(source)
        case .wardley: scene = try SpatialDataDiagrams.wardley(source)
        case .railroad: scene = try RailroadDiagram.render(source)
        case .info:
            for line in DiagramSyntax.lines(source).dropFirst() where line.text != "showInfo" { throw line.error("info 当前只接受 showInfo。") }
            let builder = SceneBuilder(.info)
            builder.box("NornaKit\nPure Swift · CoreGraphics\n33 native diagram families", CGRect(x: 16, y: 16, width: 420, height: 140), fill: .surfaceAlt)
            scene = builder.scene(width: 452, height: 172)
        }
        let lines = DiagramSyntax.lines(source)
        let hasTitle = !DiagramSyntax.title(lines).isEmpty || kind == .pie && lines.first?.text.contains("title ") == true
        if !hasTitle { scene = scene.addingTitle(document.title) }
        try Task.checkCancellation()
        guard scene.size.width.isFinite, scene.size.height.isFinite, scene.size.width > 0, scene.size.height > 0,
              scene.size.width <= 250_000, scene.size.height <= 250_000, scene.primitives.count <= 20_000 else {
            throw DiagramRenderError(message: "图表几何数据超过安全绘制范围，请减少数据项。", code: "limit")
        }
        for primitive in scene.primitives {
            let r = primitive.bounds
            guard r.isNull || r.origin.x.isFinite && r.origin.y.isFinite && r.width.isFinite && r.height.isFinite else {
                throw DiagramRenderError(message: "布局生成了无效几何数据。", code: "layout")
            }
        }
        let artifact = DiagramArtifact(scene: scene)
        guard artifact.svg.utf8.count <= 4_000_000 else { throw DiagramRenderError(message: "SVG 输出超过 4 MB。", code: "limit") }
        return artifact
    }
}
