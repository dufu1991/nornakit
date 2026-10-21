import Foundation

public enum NodeShape: String, Sendable {
    case rectangle, rounded, stadium, circle, ellipse, diamond, cylinder, subroutine
    case doubleCircle, hexagon, asymmetric, parallelogram, parallelogramAlt, trapezoid, trapezoidAlt
}

public enum FlowDirection: String, Sendable {
    case topDown = "TD", bottomUp = "BT", leftRight = "LR", rightLeft = "RL"
    var horizontal: Bool { self == .leftRight || self == .rightLeft }
}

public struct FlowNode: Equatable, Sendable {
    public let id: String
    public var label: String
    public var shape: NodeShape
    public var parentID: String? = nil
    public var sequence: Int = 0
}

public struct FlowGroup: Equatable, Sendable {
    public let id: String
    public var label: String
    public let parentID: String?
    public var direction: FlowDirection?
    public let sequence: Int
}

public enum EdgeStyle: String, Sendable {
    case solid, dashed, thick, invisible
}

public enum EdgeMarker: String, Sendable { case none, arrow, circle, cross }

public struct FlowEdge: Equatable, Sendable {
    public let from: String
    public let to: String
    public let label: String
    public let style: EdgeStyle
    public let arrow: Bool
    public var sourceSide: Int? = nil
    public var targetSide: Int? = nil
    public var startMarker: EdgeMarker = .none
    public var endMarker: EdgeMarker? = nil
    public var minimumRankSpan: Int = 1
}

public struct FlowchartModel: Equatable, Sendable {
    public let direction: FlowDirection
    public let nodes: [FlowNode]
    public let edges: [FlowEdge]
    public var groups: [FlowGroup] = []
}

public struct SceneNode: Equatable, Sendable {
    public let id: String
    public let label: String
    public let shape: NodeShape
    public var frame: CGRect
    public let lines: [String]
}

public struct SceneEdge: Equatable, Sendable {
    public let from: String
    public let to: String
    public var points: [CGPoint]
    public let label: String
    public var labelFrame: CGRect
    public let style: EdgeStyle
    public let arrow: Bool
    public var startMarker: EdgeMarker = .none
    public var endMarker: EdgeMarker? = nil
}

public struct SceneGroup: Equatable, Sendable {
    public let id: String
    public let label: String
    public let parentID: String?
    public var frame: CGRect
    public var titleFrame: CGRect
    public let titleLines: [String]
    public let depth: Int
}

/// Geometry only. Neither parsing nor layout depends on a view framework.
public struct DiagramScene: Equatable, Sendable {
    public let size: CGSize
    public let nodes: [SceneNode]
    public let edges: [SceneEdge]
    public var groups: [SceneGroup] = []
    public var primitives: [ScenePrimitive] = []
    public var kind: DiagramKind = .flowchart
}
