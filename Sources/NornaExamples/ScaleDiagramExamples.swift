import Foundation
import NornaKit

public struct DiagramExampleComparison: Identifiable, Sendable {
    public var id: String { kind.rawValue }
    public let kind: DiagramKind
    public let simple: DiagramExample
    public let complex: DiagramExample
    public let layoutNote: String

    init(kind: DiagramKind, simple: DiagramExample, complex: DiagramExample, layoutNote: String) {
        self.kind = kind
        self.simple = simple
        self.complex = complex
        self.layoutNote = layoutNote
    }

    init(_ kind: DiagramKind, _ layoutNote: String, source: String) {
        self.kind = kind
        self.layoutNote = layoutNote
        simple = (DiagramExample.catalog + DiagramExample.flowcharts).first { $0.kind == kind }!
        complex = DiagramExample(id: "\(kind.rawValue)-complex", title: "\(kind.title) · 复杂示例",
                                 symbol: simple.symbol, source: source)
    }
}

extension DiagramKind {
    public var exampleComparison: DiagramExampleComparison? { DiagramExample.comparisons.first { $0.kind == self } }
    public var exampleLayoutNote: String {
        switch self {
        case .quadrantChart: "固定四象限坐标结构，增加数据点不改变分区方式，保留单例。"
        case .wardley: "固定价值链与演化坐标，增加组件不改变坐标结构，保留单例。"
        case .cynefin: "固定五领域框架，增加条目不改变领域结构，保留单例。"
        case .info: "固定的引擎信息展示，无需按数据规模拆分示例。"
        default: exampleComparison!.layoutNote
        }
    }
}

extension DiagramExample {
    public static let comparisons: [DiagramExampleComparison] = SharedExampleCatalog.comparisons
}
