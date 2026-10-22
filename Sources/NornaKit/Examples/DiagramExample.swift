import Foundation

public struct DiagramExample: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let symbol: String
    public let source: String
    public var declaredKind: DiagramKind? = nil
    public var originURL: String? = nil

    public var kind: DiagramKind { declaredKind ?? DiagramKind.detect(source)! }
    public static let official: [DiagramExample] = { OfficialExampleCatalog.snapshot.examples.enumerated().map { index, item in
        DiagramExample(id: item.id, title: "\(item.kind.title) · \(index + 1)", symbol: "doc.text", source: item.source,
                       declaredKind: item.kind, originURL: item.origins[0].url)
    } }()
    public static let library: [DiagramExample] = all + official
    public static var all: [DiagramExample] { catalog + flowcharts + advanced + comparisons.map(\.complex) }
    public static let starters: [DiagramKind: DiagramExample] = Dictionary(grouping: all, by: \.kind).mapValues { $0[0] }
    public static let flowcharts: [DiagramExample] = SharedExampleCatalog.group("flowcharts")
}
