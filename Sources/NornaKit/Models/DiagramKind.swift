import Foundation

public enum DiagramKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case flowchart, sequence, classDiagram = "class", state, er, pie, gantt, gitGraph, mindmap, timeline, journey, xychart
    case quadrantChart, requirement, c4, sankey, block, packet, kanban, architecture, radar, treemap, info
    case agentflow, usecase, railroad, treeView, venn, cynefin, wardley, swimlane, ishikawa, eventmodeling
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .flowchart: return "流程图"
        case .sequence: return "时序图"
        case .classDiagram: return "类图"
        case .state: return "状态图"
        case .er: return "实体关系图"
        case .pie: return "饼图"
        case .gantt: return "甘特图"
        case .gitGraph: return "Git 分支图"
        case .mindmap: return "思维导图"
        case .timeline: return "时间线"
        case .journey: return "用户旅程"
        case .xychart: return "XY 坐标图"
        case .quadrantChart: return "象限图"
        case .requirement: return "需求图"
        case .c4: return "C4 架构图"
        case .sankey: return "桑基图"
        case .block: return "块图"
        case .packet: return "数据包图"
        case .kanban: return "看板"
        case .architecture: return "架构图"
        case .radar: return "雷达图"
        case .treemap: return "矩形树图"
        case .info: return "信息图"
        case .agentflow: return "智能体流程"
        case .usecase: return "用例图"
        case .railroad: return "语法铁路图"
        case .treeView: return "目录树"
        case .venn: return "韦恩图"
        case .cynefin: return "Cynefin 框架"
        case .wardley: return "Wardley 地图"
        case .swimlane: return "泳道图"
        case .ishikawa: return "鱼骨图"
        case .eventmodeling: return "事件建模"
        }
    }

    public var mermaidType: String {
        switch self {
        case .flowchart: return "flowchart-v2"
        case .classDiagram: return "classDiagram"
        case .state: return "stateDiagram"
        default: return rawValue
        }
    }

    public static func detect(_ source: String) -> DiagramKind? {
        var lines = DiagramSyntax.lines(source)
        if lines.first?.text == "---", let end = lines.dropFirst().firstIndex(where: { $0.text == "---" }) { lines = Array(lines.dropFirst(end + 1)) }
        guard let first = lines.first?.text else { return nil }
        let token = first.split(whereSeparator: { $0.isWhitespace || $0 == ":" }).first.map(String.init) ?? ""
        let map: [String: DiagramKind] = [
            "flowchart": .flowchart, "graph": .flowchart, "flowchart-elk": .flowchart, "sequenceDiagram": .sequence,
            "classDiagram": .classDiagram, "stateDiagram": .state, "stateDiagram-v2": .state, "erDiagram": .er,
            "pie": .pie, "gantt": .gantt, "gitGraph": .gitGraph, "mindmap": .mindmap, "timeline": .timeline,
            "journey": .journey, "xychart": .xychart, "xychart-beta": .xychart, "quadrantChart": .quadrantChart,
            "requirementDiagram": .requirement, "requirement": .requirement, "sankey": .sankey, "sankey-beta": .sankey,
            "block": .block, "block-beta": .block, "packet": .packet, "packet-beta": .packet, "kanban": .kanban,
            "architecture": .architecture, "architecture-beta": .architecture, "radar-beta": .radar, "treemap": .treemap,
            "treemap-beta": .treemap, "info": .info, "agentflow-beta": .agentflow, "usecase-beta": .usecase,
            "railroad-beta": .railroad, "railroad-ebnf-beta": .railroad, "railroad-abnf-beta": .railroad, "railroad-peg-beta": .railroad,
            "treeView-beta": .treeView, "venn-beta": .venn, "cynefin-beta": .cynefin, "wardley-beta": .wardley,
            "swimlane-beta": .swimlane, "ishikawa": .ishikawa, "ishikawa-beta": .ishikawa, "eventmodeling": .eventmodeling
        ]
        if token.hasPrefix("C4"), ["C4Context", "C4Container", "C4Component", "C4Dynamic", "C4Deployment"].contains(token) { return .c4 }
        return map[token]
    }
}
