import AppKit
import XCTest
@testable import NornaKit

final class BusinessMermaidRegressionTests: XCTestCase {
    struct Fixture: Decodable {
        let id: String
        let title: String
        let source: String
    }

    static func fixtures() throws -> [Fixture] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Fixtures/MermaidBusiness/cases.json")
        return try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url))
    }

    func testBusinessExamplesKeepConnectionsAndLabelsClearAtFourWidths() async throws {
        let fixtures = try Self.fixtures()
        XCTAssertEqual(fixtures.count, 12)
        let renderer = NativeDiagramRenderer()
        for fixture in fixtures {
            for width: CGFloat? in [nil, 320, 640, 1200] {
                let scene = try await renderer.render(fixture.source, options: .init(maxWidth: width)).scene
                let context = "\(fixture.id), \(String(describing: width))"
                XCTAssertTrue(scene.size.width.isFinite && scene.size.height.isFinite, context)
                XCTAssertTrue(XMLParser(data: Data(SVGExporter.export(scene, theme: .appleLight).utf8)).parse(), context)
                let audit = ConnectorAuditTests.auditConnections(scene)
                XCTAssertTrue(audit.issues.isEmpty, context + ": " + audit.issues.joined(separator: "; "))
                for (index, node) in scene.nodes.enumerated() {
                    for other in scene.nodes.dropFirst(index + 1) { XCTAssertFalse(node.frame.intersects(other.frame), context) }
                }
                if scene.kind == .flowchart {
                    let graph = try MermaidFlowchartParser.parse(fixture.source)
                    XCTAssertEqual(Set(scene.nodes.map(\.id)), Set(graph.nodes.map(\.id)), context)
                    XCTAssertEqual(scene.edges.count, graph.edges.count, context)
                    assertGroupBorderClearance(scene, context: context)
                }
                if scene.kind == .mindmap { assertMindmap(scene, context: context) }
            }
        }
    }

    func testTroubleshootingRetryStaysBackwardWhenEdgeOrderChanges() throws {
        let source = try XCTUnwrap(Self.fixtures().first { $0.id == "11" }).source
        let original = try MermaidFlowchartParser.parse(source)
        let variants = [original.edges, Array(original.edges.reversed()), Array(original.edges.dropFirst(3)) + Array(original.edges.prefix(3))]
        for direction in [FlowDirection.topDown, .bottomUp, .leftRight, .rightLeft] {
            for edges in variants {
                let graph = FlowchartModel(direction: direction, nodes: original.nodes, edges: edges)
                let scene = try LayeredLayoutEngine.layout(graph)
                let frames = Dictionary(uniqueKeysWithValues: scene.nodes.map { ($0.id, $0.frame) })
                for edge in edges {
                    let a = frames[edge.from]!, b = frames[edge.to]!
                    let forward: Bool
                    switch direction {
                    case .topDown: forward = a.maxY < b.minY
                    case .bottomUp: forward = a.minY > b.maxY
                    case .leftRight: forward = a.maxX < b.minX
                    case .rightLeft: forward = a.minX > b.maxX
                    }
                    XCTAssertEqual(forward, !(edge.from == "N" && edge.to == "G"), "\(direction): \(edge.from)->\(edge.to)")
                }
                let issues = ConnectorAuditTests.auditConnections(scene).issues
                XCTAssertTrue(issues.isEmpty, "\(direction): " + issues.joined(separator: "; "))
            }
        }
    }

    func testXYLinesInterpolateEverySampleWithoutConnectorRounding() async throws {
        for fixture in try Self.fixtures().filter({ ["01", "02"].contains($0.id) }) {
            for horizontal in [false, true] {
                let source = horizontal ? fixture.source.replacingOccurrences(of: "xychart-beta", with: "xychart-beta horizontal") : fixture.source
                for width: CGFloat? in [nil, 320, 640, 1200] {
                    let scene = try await NativeDiagramRenderer().render(source, options: .init(maxWidth: width)).scene
                    let lines = scene.primitives.filter { $0.id?.hasPrefix("xy-line-") == true }
                    XCTAssertEqual(lines.count, fixture.id == "01" ? 2 : 1)
                    for line in lines {
                        guard case .path(let commands) = line.geometry else { return XCTFail("Expected data polyline") }
                        XCTAssertEqual(commands.count, 6)
                        let vertices = commands.compactMap { command -> CGPoint? in
                            switch command {
                            case .move(let p), .line(let p): return p
                            default: XCTFail("Data lines must pass through samples"); return nil
                            }
                        }
                        let index = try XCTUnwrap(line.id?.split(separator: "-").last)
                        for sample in 0..<6 {
                            let marker = try XCTUnwrap(scene.primitives.first { $0.id == "point-\(index)-\(sample)" })
                            XCTAssertEqual(vertices[sample].x, marker.bounds.midX, accuracy: 0.001)
                            XCTAssertEqual(vertices[sample].y, marker.bounds.midY, accuracy: 0.001)
                        }
                    }
                }
            }
        }
    }

    func testDivergingBarsExposeTheZeroBaseline() async throws {
        let source = try XCTUnwrap(Self.fixtures().first { $0.id == "04" }).source
        for horizontal in [false, true] {
            let source = horizontal ? source.replacingOccurrences(of: "xychart-beta", with: "xychart-beta horizontal") : source
            let scene = try await NativeDiagramRenderer().render(source).scene
            let zero = try XCTUnwrap(scene.primitives.first { $0.id == "xy-zero-baseline" })
            let negative = try XCTUnwrap(scene.primitives.first { $0.id == "bar-0-0" })
            let positive = try XCTUnwrap(scene.primitives.first { $0.id == "bar-0-2" })
            if horizontal {
                XCTAssertEqual(zero.bounds.minX, negative.bounds.maxX, accuracy: 0.001)
                XCTAssertEqual(zero.bounds.minX, positive.bounds.minX, accuracy: 0.001)
            } else {
                XCTAssertEqual(zero.bounds.minY, negative.bounds.minY, accuracy: 0.001)
                XCTAssertEqual(zero.bounds.minY, positive.bounds.maxY, accuracy: 0.001)
            }
            XCTAssertTrue(scene.primitives.contains { if case .text(let t) = $0.geometry { return t.text == "0" }; return false })
        }
    }

    func testMindmapReflowsAtReadableFontSizeWithinRequestedWidth() async throws {
        let source = try XCTUnwrap(Self.fixtures().first { $0.id == "07" }).source
        let renderer = NativeDiagramRenderer()
        let natural = try await renderer.render(source).scene
        for width: CGFloat in [320, 640, 1200] {
            let narrow = try await renderer.render(source, options: .init(maxWidth: width)).scene
            XCTAssertLessThanOrEqual(narrow.size.width, width + 0.01)
            XCTAssertEqual(Set(narrow.primitives.compactMap(\.id)), Set(natural.primitives.compactMap(\.id)))
            for primitive in narrow.primitives {
                if case .text(let text) = primitive.geometry { XCTAssertGreaterThanOrEqual(text.size, 13.9) }
            }
        }
    }

    func testStateChainAndLongRefundTransitionAvoidSmallPortStairs() async throws {
        let source = try XCTUnwrap(Self.fixtures().first { $0.id == "09" }).source
        for width: CGFloat? in [nil, 320, 640, 1200] {
            let scene = try await NativeDiagramRenderer().render(source, options: .init(maxWidth: width)).scene
            let shipping = try XCTUnwrap(scene.primitives.first { $0.id == "relation-3" })
            let refund = try XCTUnwrap(scene.primitives.first { $0.id == "relation-4" })
            guard case .path(let shippingPath) = shipping.geometry, case .path(let refundPath) = refund.geometry else {
                return XCTFail("Expected state transitions")
            }
            XCTAssertEqual(shippingPath.count, 2)
            XCTAssertEqual(refundPath.filter { if case .cubic = $0 { return true }; return false }.count, 2)
        }
    }

    func testGroupedFlowTriesNarrowerDirectionAtTheBreakpoint() async throws {
        let source = try XCTUnwrap(Self.fixtures().first { $0.id == "06" }).source
        let renderer = NativeDiagramRenderer()
        let natural = try await renderer.render(source).scene
        let narrow = try await renderer.render(source, options: .init(maxWidth: 640)).scene
        XCTAssertLessThan(narrow.size.width, natural.size.width)
        XCTAssertEqual(narrow.nodes.count, natural.nodes.count)
        XCTAssertEqual(narrow.edges.count, natural.edges.count)
    }

    func testPipelineTurnsKeepClearOfGroupBordersAcrossDirectionsAndWidths() async throws {
        let source = try XCTUnwrap(Self.fixtures().first { $0.id == "06" }).source
        for direction in ["LR", "RL", "TD", "BT"] {
            for width: CGFloat? in [nil, 320, 640, 1200] {
                let scene = try await NativeDiagramRenderer().render(
                    source.replacingOccurrences(of: "flowchart LR", with: "flowchart \(direction)"),
                    options: .init(maxWidth: width)).scene
                assertGroupBorderClearance(scene, context: "\(direction), \(String(describing: width))")
            }
        }
    }

    func testPermissionFanoutKeepsEveryTurnClearOfGroupBorders() async throws {
        let source = try XCTUnwrap(Self.fixtures().first { $0.id == "08" }).source
        for direction in ["LR", "RL", "TD", "BT"] {
            for width: CGFloat? in [nil, 320, 640, 1200] {
                let scene = try await NativeDiagramRenderer().render(
                    source.replacingOccurrences(of: "flowchart LR", with: "flowchart \(direction)"),
                    options: .init(maxWidth: width)).scene
                let context = "Permissions \(direction), \(String(describing: width))"
                XCTAssertEqual(scene.edges.count, 13, context)
                assertGroupBorderClearance(scene, context: context)
                XCTAssertTrue(ConnectorAuditTests.auditConnections(scene).issues.isEmpty, context)
            }
        }
    }

    func testNestedParallelChannelsClearOutermostGroupBorders() throws {
        let original = try MermaidFlowchartParser.parse("""
        flowchart LR
            subgraph Outer[Source]
                subgraph Inner[Inputs]
                    A[One]
                    B[Two]
                    C[Three]
                end
            end
            subgraph Target[Outputs]
                X[One]
                Y[Two]
                Z[Three]
            end
            A --> Z
            B --> Y
            C --> X
        """)
        for direction in [FlowDirection.leftRight, .rightLeft, .topDown, .bottomUp] {
            for edges in [original.edges, Array(original.edges.reversed())] {
                let graph = FlowchartModel(direction: direction, nodes: original.nodes, edges: edges, groups: original.groups)
                let scene = try LayeredLayoutEngine.layout(graph)
                assertGroupBorderClearance(scene, context: "Nested \(direction)")
                XCTAssertEqual(scene.edges.count, 3)
                XCTAssertTrue(ConnectorAuditTests.auditConnections(scene).issues.isEmpty, "Nested \(direction)")
            }
        }
    }

    func testGroupEndpointConnectionsLeaveRoomForInternalRoutes() async throws {
        let source = """
        flowchart TB
            c1 --> a2
            subgraph one
                a1 --> a2
            end
            subgraph two
                b1 --> b2
            end
            subgraph three
                c1 --> c2
            end
            one --> two
            three --> two
            two --> c2
        """
        for width: CGFloat? in [nil, 320, 480, 640] {
            let scene = try await NativeDiagramRenderer().render(source, options: .init(maxWidth: width)).scene
            assertGroupBorderClearance(scene, context: "Group endpoints, \(String(describing: width))")
            XCTAssertTrue(ConnectorAuditTests.auditConnections(scene).issues.isEmpty)
        }
    }

    func testBusinessRoutingDoesNotIntroduceAvoidableCrossings() async throws {
        for fixture in try Self.fixtures().filter({ ["05", "07", "08"].contains($0.id) }) {
            for width: CGFloat? in [nil, 320, 640, 1200] {
                let scene = try await NativeDiagramRenderer().render(fixture.source, options: .init(maxWidth: width)).scene
                let routes = scene.edges.isEmpty ? scene.primitives.compactMap { primitive -> [PathCommand]? in
                    guard case .path(let commands) = primitive.geometry, primitive.style.fill == .none else { return nil }
                    return commands
                } : scene.edges.map { ScenePath.edge($0.points).commands }
                // The permission graph has ten crossings for these fixed role and permission orders.
                XCTAssertLessThanOrEqual(crossingPairs(routes), fixture.id == "08" ? 10 : 0,
                    "\(fixture.id), \(String(describing: width))")
            }
        }
    }

    private func crossingPairs(_ routes: [[PathCommand]]) -> Int {
        let segments = routes.map(EdgeGeometry.segments)
        var count = 0
        for (index, first) in segments.enumerated() {
            for second in segments.dropFirst(index + 1) {
                let crosses = first.contains { a, b in second.contains { c, d in
                    let vx = b.x - a.x, vy = b.y - a.y, wx = d.x - c.x, wy = d.y - c.y
                    let determinant = vx * wy - vy * wx
                    guard abs(determinant) > 0.000001 else { return false }
                    let t = ((c.x - a.x) * wy - (c.y - a.y) * wx) / determinant
                    let u = ((c.x - a.x) * vy - (c.y - a.y) * vx) / determinant
                    return t > 0.000001 && t < 0.999999 && u > 0.000001 && u < 0.999999
                } }
                if crosses { count += 1 }
            }
        }
        return count
    }

    private func assertGroupBorderClearance(_ scene: DiagramScene, context: String, file: StaticString = #filePath, line: UInt = #line) {
        for edge in scene.edges {
            for (a, b) in zip(edge.points, edge.points.dropFirst()) {
                for group in scene.groups where group.id != edge.from && group.id != edge.to {
                    let rect = group.frame
                    let message = "\(context), \(edge.from)->\(edge.to), \(group.id)"
                    if abs(a.x - b.x) < 0.01 && min(max(a.y, b.y), rect.maxY) - max(min(a.y, b.y), rect.minY) > 0.01 {
                        XCTAssertGreaterThanOrEqual(min(abs(a.x - rect.minX), abs(a.x - rect.maxX)), 16 - 0.01, message, file: file, line: line)
                    }
                    if abs(a.y - b.y) < 0.01 && min(max(a.x, b.x), rect.maxX) - max(min(a.x, b.x), rect.minX) > 0.01 {
                        XCTAssertGreaterThanOrEqual(min(abs(a.y - rect.minY), abs(a.y - rect.maxY)), 16 - 0.01, message, file: file, line: line)
                    }
                }
            }
        }
    }

    private func assertMindmap(_ scene: DiagramScene, context: String) {
        let nodes = scene.primitives.filter { $0.id?.hasPrefix("mindmap-") == true }
        XCTAssertEqual(nodes.count, 18, context)
        let routes = scene.primitives.compactMap { primitive -> [PathCommand]? in
            guard case .path(let commands) = primitive.geometry, primitive.style.fill == .none else { return nil }
            return commands
        }
        XCTAssertEqual(routes.count, 17, context)
        for (index, node) in nodes.enumerated() {
            for other in nodes.dropFirst(index + 1) { XCTAssertFalse(node.bounds.intersects(other.bounds), context) }
        }
        for route in routes {
            let segments = EdgeGeometry.segments(route)
            let start = segments.first!.0, end = segments.last!.1
            for node in nodes where !node.bounds.insetBy(dx: -0.1, dy: -0.1).contains(start) && !node.bounds.insetBy(dx: -0.1, dy: -0.1).contains(end) {
                XCTAssertTrue(segments.allSatisfy { EdgeGeometry.clear($0.0, $0.1, obstacles: [node.bounds]) }, context)
            }
        }
        if scene.size.width <= 1200 {
            for (index, route) in routes.enumerated() {
                for other in routes.dropFirst(index + 1) {
                    for (a, b) in EdgeGeometry.segments(route) {
                        for (c, d) in EdgeGeometry.segments(other) {
                            XCTAssertLessThanOrEqual(EdgeGeometry.sharedLength(a, b, c, d), 0.01, context)
                        }
                    }
                }
            }
        }
    }
}
