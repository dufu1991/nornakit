import Foundation

public enum DiagramCategory: String, CaseIterable, Identifiable, Sendable {
    case process, relationships, architecture, charts, planning, hierarchy, development
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .process: "流程与交互"
        case .relationships: "关系与约束"
        case .architecture: "系统与架构"
        case .charts: "数据图表"
        case .planning: "规划与分析"
        case .hierarchy: "层级结构"
        case .development: "开发与信息"
        }
    }
}

extension DiagramKind {
    public var category: DiagramCategory {
        switch self {
        case .flowchart, .sequence, .state, .swimlane: .process
        case .classDiagram, .er, .usecase, .requirement, .venn: .relationships
        case .c4, .architecture, .agentflow, .eventmodeling: .architecture
        case .pie, .xychart, .quadrantChart, .radar, .sankey, .treemap: .charts
        case .gantt, .timeline, .journey, .kanban, .wardley, .cynefin, .ishikawa: .planning
        case .mindmap, .treeView: .hierarchy
        case .gitGraph, .block, .packet, .railroad, .info: .development
        }
    }

    public var starter: DiagramExample { DiagramExample.starters[self]! }
    public var symbol: String { starter.symbol }
}
