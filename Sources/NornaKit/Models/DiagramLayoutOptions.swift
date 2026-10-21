import Foundation

public struct DiagramLayoutOptions: Equatable, Hashable, Sendable {
    public var maxWidth: CGFloat?
    public var autoDirection: Bool
    public var directionBreakpoint: CGFloat

    public init(maxWidth: CGFloat? = nil, autoDirection: Bool = true, directionBreakpoint: CGFloat = 640) {
        self.maxWidth = maxWidth
        self.autoDirection = autoDirection
        self.directionBreakpoint = directionBreakpoint
    }

    var labelWidth: CGFloat { min(200, max(80, (maxWidth ?? 640) - 100)) }
    var compact: Bool { maxWidth.map { $0 < directionBreakpoint } ?? false }

    func width(_ natural: CGFloat, minimum: CGFloat = 320) -> CGFloat {
        guard let maxWidth else { return natural }
        return min(natural, max(minimum, maxWidth))
    }

    func validate() throws {
        guard maxWidth == nil || maxWidth!.isFinite && maxWidth! >= 160 && maxWidth! <= 250_000,
              directionBreakpoint.isFinite, directionBreakpoint >= 160, directionBreakpoint <= 250_000 else {
            throw DiagramRenderError(message: "布局宽度和转向阈值必须是有效范围内的有限数值。", code: "limit")
        }
    }
}

enum AdaptiveFlowLayout {
    static func layout(_ graph: FlowchartModel, options: DiagramLayoutOptions) throws -> DiagramScene {
        let scene = try LayeredLayoutEngine.layout(graph, options: options)
        guard let width = options.maxWidth, options.autoDirection, options.compact,
              graph.direction.horizontal, scene.size.width > width else { return scene }
        let vertical = FlowchartModel(direction: .topDown, nodes: graph.nodes, edges: graph.edges, groups: graph.groups)
        let candidate = try LayeredLayoutEngine.layout(vertical, options: options)
        // Explicit directions inside subgraphs are retained; turn only when it reduces width.
        return candidate.size.width < scene.size.width ? candidate : scene
    }
}
