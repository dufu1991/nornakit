import XCTest
@testable import NornaKit

final class CompoundRoutingPropertyTests: XCTestCase {
    private let directions: [FlowDirection] = [.leftRight, .rightLeft, .topDown, .bottomUp]

    func testGeneratedCompoundTopologiesPreserveGeometryInvariants() throws {
        for direction in directions {
            for count in [1, 2, 3, 5, 8] {
                for nested in [false, true] {
                    for fanOut in [false, true] {
                        let graph = graph(direction: direction, sources: fanOut ? 1 : count,
                            targets: fanOut ? count : 1, nested: nested)
                        let scene = try LayeredLayoutEngine.layout(graph)
                        assertInvariants(scene, graph: graph)
                    }
                }
            }
        }
    }

    func testEdgeDeclarationPermutationsDoNotChangeCompoundGeometry() throws {
        for direction in directions {
            for nested in [false, true] {
                let graph = graph(direction: direction, sources: 3, targets: 4, nested: nested)
                let expected = try LayeredLayoutEngine.layout(graph)
                for edges in [Array(graph.edges.reversed()), Array(graph.edges.dropFirst(3)) + Array(graph.edges.prefix(3))] {
                    let permuted = FlowchartModel(direction: direction, nodes: graph.nodes, edges: edges, groups: graph.groups)
                    let actual = try LayeredLayoutEngine.layout(permuted)
                    XCTAssertEqual(actual.nodes, expected.nodes, "\(direction), nested=\(nested)")
                    XCTAssertEqual(actual.groups, expected.groups, "\(direction), nested=\(nested)")
                    for edge in actual.edges {
                        let previous = try XCTUnwrap(expected.edges.first { $0.from == edge.from && $0.to == edge.to })
                        XCTAssertEqual(edge, previous, "\(direction), nested=\(nested), \(edge.from)->\(edge.to)")
                    }
                }
            }
        }
    }

    func testNestedConnectionsKeepIndependentTracksAtSharedOuterBoundary() throws {
        for direction in directions {
            let graph = graph(direction: direction, sources: 2, targets: 3, nested: true)
            let scene = try LayeredLayoutEngine.layout(graph)
            assertInvariants(scene, graph: graph)
            let left = try XCTUnwrap(scene.groups.first { $0.id == "Left" }).frame
            let right = try XCTUnwrap(scene.groups.first { $0.id == "Right" }).frame
            let horizontal = direction.horizontal
            let positive = direction == .leftRight || direction == .topDown
            let first = horizontal ? (positive ? left.maxX : left.minX) : (positive ? left.maxY : left.minY)
            let last = horizontal ? (positive ? right.minX : right.maxX) : (positive ? right.minY : right.maxY)
            var tracks: [(CGFloat, CGFloat, CGFloat)] = []
            for edge in scene.edges {
                for (a, b) in zip(edge.points, edge.points.dropFirst()) {
                    let axisA = horizontal ? a.x : a.y, axisB = horizontal ? b.x : b.y
                    let crossA = horizontal ? a.y : a.x, crossB = horizontal ? b.y : b.x
                    if abs(axisA - axisB) < 0.01 && abs(crossA - crossB) > 1,
                       axisA > min(first, last), axisA < max(first, last) {
                        tracks.append((axisA, min(crossA, crossB), max(crossA, crossB)))
                    }
                }
            }
            for (index, a) in tracks.enumerated() {
                for b in tracks.dropFirst(index + 1) where min(a.2, b.2) - max(a.1, b.1) > 0.01 {
                    XCTAssertGreaterThanOrEqual(abs(a.0 - b.0), 12 - 0.01, "\(direction): shared outer corridor")
                }
            }
        }
    }

    func testMixedLocalDirectionsFeedbackAndLabelsKeepRoutingClear() throws {
        for root in ["LR", "RL", "TD", "BT"] {
            for local in ["LR", "RL", "TD", "BT"] {
                let source = """
                flowchart \(root)
                    subgraph Input[Input boundary]
                        direction \(local)
                        A[Receive input] --> B[Validate input]
                    end
                    subgraph Output[Output boundary]
                        C[Process request] --> D[Store result]
                    end
                    B -->|Validated request| C
                    D -->|Retry validation| A
                """
                let graph = try MermaidFlowchartParser.parse(source)
                for width: CGFloat? in [nil, 320] {
                    let scene = try LayeredLayoutEngine.layout(graph, options: .init(maxWidth: width))
                    assertInvariants(scene, graph: graph)
                }
            }
        }
    }

    private func graph(direction: FlowDirection, sources: Int, targets: Int, nested: Bool) -> FlowchartModel {
        var groups = [FlowGroup(id: "Left", label: "Source boundary", parentID: nil, sequence: 0),
            FlowGroup(id: "Right", label: "Destination boundary", parentID: nil, sequence: 1)]
        if nested {
            for side in ["Left", "Right"] {
                for branch in 0..<2 {
                    groups.append(FlowGroup(id: "\(side)\(branch)", label: "Branch \(branch)", parentID: side, sequence: groups.count))
                }
            }
        }
        let nodes = (0..<sources).map { FlowNode(id: "S\($0)", label: "Source \($0)", shape: .rectangle,
            parentID: nested ? "Left\($0 % 2)" : "Left", sequence: $0 + groups.count) }
            + (0..<targets).map { FlowNode(id: "T\($0)", label: "Target \($0)", shape: .rectangle,
                parentID: nested ? "Right\($0 % 2)" : "Right", sequence: sources + $0 + groups.count) }
        let edges = (0..<sources).flatMap { from in (0..<targets).map { to in
            FlowEdge(from: "S\(from)", to: "T\(to)", label: "", style: .solid, arrow: true)
        } }
        return FlowchartModel(direction: direction, nodes: nodes, edges: edges, groups: groups)
    }

    private func assertInvariants(_ scene: DiagramScene, graph: FlowchartModel, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(scene.edges.count, graph.edges.count, file: file, line: line)
        XCTAssertEqual(Set(scene.nodes.map(\.id)), Set(graph.nodes.map(\.id)), file: file, line: line)
        let audit = ConnectorAuditTests.auditConnections(scene)
        // A feedback route may intentionally leave the forward spine even when its endpoints align.
        let collisions = audit.issues.filter { !$0.hasPrefix("avoidable aligned bend") }
        XCTAssertTrue(collisions.isEmpty, "\(graph.direction): " + collisions.joined(separator: "; "), file: file, line: line)
        for edge in scene.edges {
            for (a, b) in zip(edge.points, edge.points.dropFirst()) {
                for group in scene.groups where group.id != edge.from && group.id != edge.to {
                    let rect = group.frame
                    let context = "\(graph.direction): \(edge.from)->\(edge.to), \(group.id)"
                    if abs(a.x - b.x) < 0.01 && min(max(a.y, b.y), rect.maxY) - max(min(a.y, b.y), rect.minY) > 0.01 {
                        XCTAssertGreaterThanOrEqual(min(abs(a.x - rect.minX), abs(a.x - rect.maxX)), 16 - 0.01, context, file: file, line: line)
                    }
                    if abs(a.y - b.y) < 0.01 && min(max(a.x, b.x), rect.maxX) - max(min(a.x, b.x), rect.minX) > 0.01 {
                        XCTAssertGreaterThanOrEqual(min(abs(a.y - rect.minY), abs(a.y - rect.maxY)), 16 - 0.01, context, file: file, line: line)
                    }
                }
            }
        }
    }
}
