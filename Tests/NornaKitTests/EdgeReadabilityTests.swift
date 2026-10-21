import XCTest
@testable import NornaKit

final class EdgeReadabilityTests: XCTestCase {
    func testAgentChainsStayAlignedAndLongBranchUsesOneContinuousCorridor() throws {
        let example = try XCTUnwrap(DiagramKind.agentflow.exampleComparison?.complex)
        let original = example.source.replacingOccurrences(of: "agentflow-beta", with: "flowchart")
        for source in [original, original.replacingOccurrences(of: "Research[研究智能体]", with: "Research[用于资料检索与事实核对的研究智能体]")] {
            for direction in ["TD", "BT", "LR", "RL"] {
                let model = try MermaidFlowchartParser.parse(source.replacingOccurrences(of: "flowchart TD", with: "flowchart \(direction)"))
                for width: CGFloat? in [nil, 320, 640] {
                    let scene = try LayeredLayoutEngine.layout(model, options: .init(maxWidth: width, autoDirection: false))
                    for pair in [("Research", "Sources"), ("Code", "Implement"), ("Data", "Analyze")] {
                        let edge = try XCTUnwrap(scene.edges.first { $0.from == pair.0 && $0.to == pair.1 })
                        XCTAssertEqual(edge.points.count, 2, "\(direction): \(pair), \(edge.points)")
                    }
                    let bypass = try XCTUnwrap(scene.edges.first { $0.from == "Quality" && $0.to == "Answer" })
                    XCTAssertLessThanOrEqual(bypass.points.count, 6, "\(direction): \(bypass.points)")
                    let horizontal = direction == "LR" || direction == "RL"
                    let crossSegments = zip(bypass.points, bypass.points.dropFirst()).filter { horizontal ? abs($0.0.y - $0.1.y) > 0.01 : abs($0.0.x - $0.1.x) > 0.01 }
                    XCTAssertLessThanOrEqual(crossSegments.count, 2)
                    for (a, b) in zip(bypass.points, bypass.points.dropFirst()) {
                        XCTAssertTrue(abs(a.x - b.x) < 0.01 || abs(a.y - b.y) < 0.01)
                        for node in scene.nodes where node.id != bypass.from && node.id != bypass.to {
                            XCTAssertTrue(EdgeGeometry.clear(a, b, obstacles: [node.frame.insetBy(dx: -4, dy: -4)]), "\(direction): bypass crosses \(node.id)")
                        }
                    }
                    for node in scene.nodes {
                        for other in scene.nodes where node.id < other.id { XCTAssertFalse(node.frame.intersects(other.frame)) }
                    }
                    XCTAssertTrue(ScenePath.edge(bypass.points).commands.contains { if case .cubic = $0 { return true }; return false })
                    XCTAssertTrue(isOnRoute(CGPoint(x: bypass.labelFrame.midX, y: bypass.labelFrame.midY), points: bypass.points))
                }
            }
        }
    }

    func testInitialStateTransitionsStayStraightBesideReturnTransitions() throws {
        let parallel = try XCTUnwrap(DiagramExample.all.first { $0.id == "state-parallel" })
        let basic = "stateDiagram-v2\n[*] --> Idle\nIdle --> Busy : 接收任务\nBusy --> Idle : 完成"
        for source in [basic, parallel.source, DiagramKind.state.exampleComparison!.complex.source] {
            for direction in ["TD", "BT", "LR", "RL"] {
                let graph = try StateDiagram.parse(source.replacingOccurrences(of: "stateDiagram-v2", with: "stateDiagram-v2\ndirection \(direction)"))
                let initial = Set(graph.entities.filter { $0.stateMarker == 1 }.map(\.id))
                let regular = Set(graph.entities.filter { $0.stateMarker == 0 && !$0.synchronization }.map(\.id))
                for width: CGFloat? in [nil, 320, 640] {
                    let scene = try graph.scene(options: .init(maxWidth: width, autoDirection: false))
                    var checked = 0
                    for (index, relation) in graph.relations.enumerated() where initial.contains(relation.from) && regular.contains(relation.to) {
                        let route = try XCTUnwrap(scene.primitives.first { $0.id == "relation-\(index)" })
                        guard case .path(let commands) = route.geometry else { return XCTFail("Expected initial transition") }
                        XCTAssertEqual(commands.count, 2, "\(direction), \(String(describing: width)): \(relation.to), \(commands)")
                        let points = routePoints(route)
                        XCTAssertTrue(abs(points[0].x - points[1].x) < 0.01 || abs(points[0].y - points[1].y) < 0.01)
                        let marker = try XCTUnwrap(scene.primitives.first { $0.id == relation.from })
                        XCTAssertEqual(hypot(points[0].x - marker.bounds.midX, points[0].y - marker.bounds.midY), 9, accuracy: 0.01)
                        let target = try XCTUnwrap(scene.primitives.first { $0.id == relation.to })
                        XCTAssertTrue(target.bounds.insetBy(dx: -0.01, dy: -0.01).contains(points[1]))
                        checked += 1
                    }
                    XCTAssertGreaterThan(checked, 0)
                    for (index, relation) in graph.relations.enumerated() where !graph.groups.isEmpty && ["完成", "断开"].contains(relation.label) {
                        let route = try XCTUnwrap(scene.primitives.first { $0.id == "relation-\(index)" })
                        guard case .path(let commands) = route.geometry else { return XCTFail("Expected return transition") }
                        XCTAssertEqual(commands.filter { if case .cubic = $0 { return true }; return false }.count, 2)
                        let points = routePoints(route)
                        for i in 1..<(points.count - 1) {
                            let a = points[i - 1], b = points[i], c = points[i + 1]
                            XCTAssertGreaterThanOrEqual((b.x - a.x) * (c.x - b.x) + (b.y - a.y) * (c.y - b.y), -0.01)
                        }
                    }
                }
            }
        }
    }

    func testRetryAndSelfLoopHaveIndependentRoundedChannels() throws {
        let declarations = "A([提交任务])\nB[执行请求]\nC{请求成功？}\nD([完成])\nE[等待重试]"
        let edges = ["A --> B", "B --> C", "C -->|是| D", "C -->|否| E", "E -.-> B", "D --> D"]
        for direction in ["TD", "BT", "LR", "RL"] {
            for order in [edges, [edges[5]] + Array(edges.dropLast()), Array(edges.reversed())] {
                for width: CGFloat? in [nil, 320, 640] {
                    let source = "flowchart \(direction)\n" + declarations + "\n" + order.joined(separator: "\n")
                    let scene = try LayeredLayoutEngine.layout(MermaidFlowchartParser.parse(source), options: .init(maxWidth: width))
                    let loop = try XCTUnwrap(scene.edges.first { $0.from == "D" && $0.to == "D" })
                    XCTAssertTrue(ScenePath.edge(loop.points).commands.contains { if case .cubic = $0 { return true }; return false })
                    for other in scene.edges where other.from != "D" || other.to != "D" {
                        for (a, b) in zip(loop.points, loop.points.dropFirst()) {
                            for (c, d) in zip(other.points, other.points.dropFirst()) {
                                XCTAssertFalse(segmentsMeet(a, b, c, d), "\(direction): self loop crosses \(other.from) to \(other.to)")
                                XCTAssertGreaterThanOrEqual(min(pointDistance(a, c, d), pointDistance(b, c, d), pointDistance(c, a, b), pointDistance(d, a, b)), 4)
                            }
                        }
                    }
                    for (a, b) in zip(loop.points, loop.points.dropFirst()) {
                        for node in scene.nodes where node.id != "D" { XCTAssertTrue(EdgeGeometry.clear(a, b, obstacles: [node.frame])) }
                    }
                    for edge in scene.edges where !edge.label.isEmpty {
                        XCTAssertTrue(isOnRoute(CGPoint(x: edge.labelFrame.midX, y: edge.labelFrame.midY), points: edge.points))
                        for (a, b) in zip(loop.points, loop.points.dropFirst()) {
                            XCTAssertTrue(EdgeGeometry.clear(a, b, obstacles: [edge.labelFrame.insetBy(dx: -4, dy: -4)]))
                        }
                    }
                }
            }
        }
    }

    func testSwimlaneStepsAlignAndHandoffsAvoidDistantPerimeterDetours() throws {
        for direction in ["LR", "TD"] {
            let source = DiagramKind.swimlane.exampleComparison!.complex.source.replacingOccurrences(of: "swimlane-beta LR", with: "swimlane-beta \(direction)")
            for width: CGFloat? in [nil, 320, 640] {
                let scene = try BlockLaneDiagrams.swimlane(source, options: .init(maxWidth: width, autoDirection: false))
                let nodes = Dictionary(uniqueKeysWithValues: scene.primitives.filter { ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"].contains($0.id ?? "") }.map { ($0.id!, $0.bounds) })
                XCTAssertEqual(nodes.count, 10)
                let routes = scene.primitives.filter { $0.id?.hasPrefix("lane-edge-") == true }
                XCTAssertEqual(routes.count, 12)
                let connections = [("A", "B"), ("B", "C"), ("D", "E"), ("E", "F"), ("G", "H"), ("I", "J"), ("A", "D"), ("E", "G"), ("B", "H"), ("H", "F"), ("F", "I"), ("J", "C")]
                for (index, pair) in connections.enumerated() {
                    let route = try XCTUnwrap(routes.first { $0.id == "lane-edge-\(index)" })
                    let points = sampledRoutePoints(route)
                    if index < 6 {
                        guard case .path(let commands) = route.geometry else { return XCTFail("Expected lane connection") }
                        XCTAssertEqual(commands.count, 2, "\(direction): \(pair)")
                        XCTAssertEqual(direction == "LR" ? nodes[pair.0]!.midY : nodes[pair.0]!.midX,
                                       direction == "LR" ? nodes[pair.1]!.midY : nodes[pair.1]!.midX, accuracy: 0.01)
                    }
                    for (id, frame) in nodes where id != pair.0 && id != pair.1 {
                        XCTAssertTrue(points.allSatisfy { !frame.insetBy(dx: -2, dy: -2).contains($0) }, "\(direction): \(pair) crosses \(id)")
                    }
                    if index >= 6 {
                        let local = nodes[pair.0]!.union(nodes[pair.1]!).insetBy(dx: -32, dy: -32)
                        XCTAssertTrue(points.allSatisfy(local.contains), "\(direction): \(pair) detours around unrelated lanes")
                    }
                }
                let incoming = sampledRoutePoints(try XCTUnwrap(routes.first { $0.id == "lane-edge-8" })).last!
                let outgoing = sampledRoutePoints(try XCTUnwrap(routes.first { $0.id == "lane-edge-9" })).first!
                XCTAssertGreaterThanOrEqual(hypot(incoming.x - outgoing.x, incoming.y - outgoing.y), 12)
                for first in routes.indices {
                    let a = sampledRoutePoints(routes[first])
                    for second in routes.indices where second > first {
                        let b = sampledRoutePoints(routes[second])
                        for (p, q) in zip(a, a.dropFirst()) {
                            for (r, s) in zip(b, b.dropFirst()) {
                                if abs(p.x - q.x) < 0.001, abs(r.x - s.x) < 0.001, abs(p.x - r.x) < 0.001 {
                                    XCTAssertLessThanOrEqual(min(max(p.y, q.y), max(r.y, s.y)) - max(min(p.y, q.y), min(r.y, s.y)), 0.01)
                                }
                                if abs(p.y - q.y) < 0.001, abs(r.y - s.y) < 0.001, abs(p.y - r.y) < 0.001 {
                                    XCTAssertLessThanOrEqual(min(max(p.x, q.x), max(r.x, s.x)) - max(min(p.x, q.x), min(r.x, s.x)), 0.01)
                                }
                            }
                        }
                    }
                }
            }
        }
        let parallel = try BlockLaneDiagrams.swimlane("swimlane-beta LR\nsubgraph One[服务]\nA --> B & C\nB & C --> D\nend")
        let b = try XCTUnwrap(parallel.primitives.first { $0.id == "B" }), c = try XCTUnwrap(parallel.primitives.first { $0.id == "C" })
        XCTAssertFalse(b.bounds.intersects(c.bounds))
    }

    func testCompoundForwardEdgesAvoidHeaderDetoursAndTinySteps() throws {
        let source = DiagramKind.flowchart.exampleComparison!.complex.source
        for direction in ["TD", "BT", "LR", "RL"] {
            let graph = try MermaidFlowchartParser.parse(source.replacingOccurrences(of: "flowchart TD", with: "flowchart \(direction)"))
            for width: CGFloat? in [nil, 320, 640, 1200] {
                let scene = try AdaptiveFlowLayout.layout(graph, options: .init(maxWidth: width, autoDirection: false))
                let entry = try XCTUnwrap(scene.edges.first { $0.from == "Check" && $0.to == "Stock" })
                XCTAssertLessThanOrEqual(entry.points.count, 4, "\(direction), \(String(describing: width)): \(entry.points)")
                let chain = try XCTUnwrap(scene.edges.first { $0.from == "Reserve" && $0.to == "Payment" })
                XCTAssertEqual(chain.points.count, 2, "\(direction), \(String(describing: width)): \(chain.points)")
                let directBranch = try XCTUnwrap(scene.edges.first { $0.from == "Payment" && $0.to == "Risk" })
                XCTAssertEqual(directBranch.points.count, 2, "\(direction), \(String(describing: width)): \(directBranch.points)")
                for edge in [entry, chain, directBranch] {
                    for (a, b) in zip(edge.points, edge.points.dropFirst()) {
                        XCTAssertTrue(abs(a.x - b.x) < 0.01 || abs(a.y - b.y) < 0.01)
                        for node in scene.nodes where node.id != edge.from && node.id != edge.to {
                            XCTAssertTrue(EdgeGeometry.clear(a, b, obstacles: [node.frame]))
                        }
                        for group in scene.groups { XCTAssertTrue(EdgeGeometry.clear(a, b, obstacles: [group.titleFrame])) }
                    }
                }
            }
        }
    }

    func testBranchesKeepRoundedElbowsAndSmallerLabelsOnTheirLines() throws {
        for direction in ["TD", "LR", "BT", "RL"] {
            let source = DiagramKind.flowchart.starter.source.replacingOccurrences(of: "flowchart TD", with: "flowchart \(direction)")
            let scene = try LayeredLayoutEngine.layout(MermaidFlowchartParser.parse(source))
            let branches = scene.edges.filter { $0.from == "B" }
            XCTAssertEqual(branches.count, 2)
            XCTAssertTrue(branches.contains { $0.points.count > 2 }, direction)
            for edge in branches {
                if edge.points.count > 2 {
                    XCTAssertTrue(ScenePath.edge(edge.points).commands.contains { if case .cubic = $0 { return true }; return false })
                }
                let center = CGPoint(x: edge.labelFrame.midX, y: edge.labelFrame.midY)
                XCTAssertTrue(isOnRoute(center, points: edge.points), direction)
                for node in scene.nodes { XCTAssertFalse(node.frame.intersects(edge.labelFrame), "\(direction): \(edge.label), \(edge.labelFrame), \(node.id), \(node.frame), \(edge.points)") }
                XCTAssertEqual(edge.labelFrame.height, DiagramStyle.edgeLineHeight)
            }
            XCTAssertFalse(branches[0].labelFrame.intersects(branches[1].labelFrame))
            XCTAssertLessThanOrEqual(DiagramStyle.edgeFontSize, DiagramStyle.fontSize * 0.75)
            let svg = SVGExporter.export(scene, theme: .appleLight)
            XCTAssertTrue(svg.contains("font-size=\"12.00\""))
            for edge in branches { XCTAssertTrue(svg.contains(ScenePath.edge(edge.points).svg)) }
        }
    }

    func testSegmentObstaclesAreDetectedForHorizontalVerticalAndDiagonalLines() {
        let obstacle = CGRect(x: 40, y: 40, width: 20, height: 20)
        XCTAssertFalse(EdgeGeometry.clear(.zero, CGPoint(x: 100, y: 100), obstacles: [obstacle]))
        XCTAssertFalse(EdgeGeometry.clear(CGPoint(x: 50, y: 0), CGPoint(x: 50, y: 100), obstacles: [obstacle]))
        XCTAssertFalse(EdgeGeometry.clear(CGPoint(x: 0, y: 50), CGPoint(x: 100, y: 50), obstacles: [obstacle]))
        XCTAssertTrue(EdgeGeometry.clear(CGPoint(x: 0, y: 40), CGPoint(x: 100, y: 40), obstacles: [obstacle]))
    }

    func testUsecaseMiddleAssociationIsStraightAndOuterAssociationsKeepRoundedElbows() async throws {
        let scene = try await NativeDiagramRenderer().render(DiagramKind.usecase.starter.source).scene
        let relations = scene.primitives.filter { $0.id?.hasPrefix("relation-") == true }
        XCTAssertEqual(relations.count, 3)
        let caption = try XCTUnwrap(scene.primitives.compactMap { primitive -> SceneText? in
            guard case .text(let text) = primitive.geometry, text.text == "用户" else { return nil }
            return text
        }.first)
        for relation in relations {
            guard case .path(let commands) = relation.geometry,
                  case .move(let start) = commands.first, case .line(let end) = commands.last else { return XCTFail("Expected association path") }
            if relation.id == "relation-1" {
                XCTAssertEqual(commands.count, 2)
                XCTAssertEqual(start.y, end.y, accuracy: 0.01)
                XCTAssertEqual(start.y, caption.frame.minY - 28, accuracy: 0.01)
            } else {
                XCTAssertGreaterThan(commands.count, 2)
                XCTAssertTrue(commands.contains { if case .cubic = $0 { return true }; return false })
            }
            let points = commands.compactMap { command -> CGPoint? in
                switch command { case .move(let p), .line(let p), .quad(_, let p), .cubic(_, _, let p): p; default: nil }
            }
            for (a, b) in zip(points, points.dropFirst()) { XCTAssertTrue(EdgeGeometry.clear(a, b, obstacles: [caption.frame])) }
            XCTAssertNotEqual(start, end)
        }
    }

    func testArchitectureGroupHeaderDoesNotIntroduceTinySteps() async throws {
        for width: CGFloat? in [nil, 320, 640] {
            let scene = try await NativeDiagramRenderer().render(DiagramKind.architecture.starter.source, options: .init(maxWidth: width, autoDirection: false)).scene
            let services = scene.primitives.filter { ["web", "api", "db"].contains($0.id ?? "") }
            XCTAssertEqual(services.count, 3)
            for service in services { XCTAssertEqual(service.bounds.midY, services[0].bounds.midY, accuracy: 0.01) }
            let routes = scene.primitives.filter { $0.style.stroke == .line }.compactMap { primitive -> [PathCommand]? in
                guard case .path(let commands) = primitive.geometry else { return nil }
                return commands
            }
            XCTAssertEqual(routes.count, 2)
            for route in routes {
                XCTAssertEqual(route.count, 2)
                guard case .move(let start) = route.first, case .line(let end) = route.last else { return XCTFail("Expected aligned connection") }
                XCTAssertEqual(start.y, end.y, accuracy: 0.01)
            }
        }
    }

    func testArchitectureBranchesStillUseRoundedOrthogonalRoutes() async throws {
        let source = """
        architecture-beta
        service client(internet)[客户端]
        group backend(server)[服务层]
        service api(server)[网关] in backend
        service db(database)[数据库] in backend
        client:R --> L:api
        client:R --> L:db
        """
        let scene = try await NativeDiagramRenderer().render(source).scene
        let routes = scene.primitives.filter { $0.style.stroke == .line }.compactMap { primitive -> [PathCommand]? in
            guard case .path(let commands) = primitive.geometry else { return nil }
            return commands
        }
        XCTAssertEqual(routes.count, 2)
        XCTAssertTrue(routes.allSatisfy { $0.contains { if case .cubic = $0 { return true }; return false } })
    }

    func testC4RelationsUseActorGlyphAndKeepArrowClearOfCorners() async throws {
        for width: CGFloat? in [nil, 320, 640] {
            let scene = try await NativeDiagramRenderer().render(DiagramKind.c4.starter.source, options: .init(maxWidth: width)).scene
            let caption = try XCTUnwrap(scene.primitives.compactMap { primitive -> SceneText? in
                guard case .text(let text) = primitive.geometry, text.text == "用户\n编辑图表" else { return nil }
                return text
            }.first)
            let connection = try XCTUnwrap(scene.primitives.first { $0.id == "relation-0" })
            let points = routePoints(connection)
            let start = try XCTUnwrap(points.first)
            XCTAssertEqual(start.x, caption.frame.midX + 18, accuracy: 0.01)
            XCTAssertEqual(start.y, caption.frame.minY - 28, accuracy: 0.01)
            XCTAssertTrue(sampledRoutePoints(connection).allSatisfy { !caption.frame.contains($0) })
            XCTAssertTrue({ if case .path(let commands) = connection.geometry { return commands.contains { if case .cubic = $0 { return true }; return false } }; return false }())
            for route in scene.primitives.filter({ $0.id?.hasPrefix("relation-") == true }) {
                let points = routePoints(route)
                XCTAssertGreaterThanOrEqual(points.count, 2)
                let tip = try XCTUnwrap(points.last), approach = points[points.count - 2]
                XCTAssertGreaterThanOrEqual(hypot(tip.x - approach.x, tip.y - approach.y), 12)
            }
            let label = try XCTUnwrap(scene.primitives.compactMap { primitive -> SceneText? in
                guard case .text(let text) = primitive.geometry, text.text == "编辑" else { return nil }
                return text
            }.first)
            XCTAssertEqual(label.size, DiagramStyle.edgeFontSize)
            XCTAssertTrue(isOnRoute(CGPoint(x: label.frame.midX, y: label.frame.midY), points: points))
        }
    }

    func testUsecaseFanOutDoesNotCrossOrMergeAssociations() async throws {
        let associations = ["User --> Edit", "User --> Preview", "User --> Export"]
        let original = associations.joined(separator: "\n    ")
        for order in [associations, associations.reversed(), [associations[1], associations[2], associations[0]]] {
            let source = DiagramKind.usecase.starter.source.replacingOccurrences(of: original, with: order.joined(separator: "\n    "))
            XCTAssertTrue(source.contains(order.joined(separator: "\n    ")))
            for width: CGFloat? in [nil, 320, 640] {
                let scene = try await NativeDiagramRenderer().render(source, options: .init(maxWidth: width)).scene
                let routes = scene.primitives.filter { $0.id?.hasPrefix("relation-") == true }
                XCTAssertEqual(routes.count, 3)
                let middle = try XCTUnwrap(routes.first { $0.id == "relation-\(order.firstIndex(of: associations[1])!)" })
                guard case .path(let middleCommands) = middle.geometry else { return XCTFail("Expected association path") }
                XCTAssertEqual(middleCommands.count, 2, "The middle association should remain straight regardless of width or declaration order")
                for first in routes.indices {
                    for second in routes.indices where second > first {
                        let a = sampledRoutePoints(routes[first]), b = sampledRoutePoints(routes[second])
                        var separation = CGFloat.infinity
                        for (p, q) in zip(a, a.dropFirst()) {
                            for (r, s) in zip(b, b.dropFirst()) {
                                XCTAssertFalse(segmentsMeet(p, q, r, s), "Association routes must stay separate")
                                separation = min(separation, pointDistance(p, r, s), pointDistance(q, r, s), pointDistance(r, p, q), pointDistance(s, p, q))
                            }
                        }
                        XCTAssertGreaterThanOrEqual(separation, 4, "Rounded associations must remain visually distinct")
                    }
                }
            }
        }
    }

    func testStateLabelsAreSmallerAndStayOnTheirTransitions() async throws {
        let owners = ["编辑源码": "relation-1", "成功": "relation-2", "语法错误": "relation-3", "修正": "relation-4"]
        for direction: FlowDirection in [.topDown, .bottomUp, .leftRight, .rightLeft] {
            for width: CGFloat? in [nil, 320, 640] {
                for grouped in [false, true] {
                    let source = grouped ? DiagramKind.state.starter.source.replacingOccurrences(of: "stateDiagram-v2", with: "stateDiagram-v2\nstate Work {") + "\n}" : DiagramKind.state.starter.source
                    var model = try StateDiagram.parse(source)
                    model.direction = direction
                    let scene = try model.scene(options: .init(maxWidth: width, autoDirection: false))
                    let labels = scene.primitives.compactMap { primitive -> SceneText? in
                        guard case .text(let text) = primitive.geometry, owners[text.text] != nil else { return nil }
                        return text
                    }
                    let routes = scene.primitives.filter { $0.id?.hasPrefix("relation-") == true }
                    XCTAssertEqual(labels.count, 4)
                    for label in labels {
                        XCTAssertEqual(label.size, DiagramStyle.edgeFontSize)
                        let own = try XCTUnwrap(routes.first { $0.id == owners[label.text] })
                        let center = CGPoint(x: label.frame.midX, y: label.frame.midY)
                        XCTAssertTrue(isOnRoute(center, points: routePoints(own)), "\(direction), \(String(describing: width)): \(label.text), \(center), \(routePoints(own))")
                        for other in routes where other.id != own.id {
                            let points = routePoints(other)
                            for (a, b) in zip(points, points.dropFirst()) {
                                XCTAssertTrue(EdgeGeometry.clear(a, b, obstacles: [label.frame.insetBy(dx: -6, dy: -6)]), "\(direction): \(label.text), \(other.id!)")
                            }
                        }
                    }
                }
            }
        }
    }

    func testReturnTransitionUsesSeparateFaceAndLabelsAvoidOtherRoutes() throws {
        for direction in ["TD", "BT", "LR", "RL"] {
            let source = "flowchart \(direction)\nIdle -->|编辑源码| Parsing\nParsing -->|成功| Ready\nParsing -->|语法错误| Error\nError -->|修正| Parsing"
            let scene = try LayeredLayoutEngine.layout(MermaidFlowchartParser.parse(source))
            let normal = scene.edges[0], returning = scene.edges[3]
            let normalEnd = try XCTUnwrap(normal.points.last), returnEnd = try XCTUnwrap(returning.points.last)
            XCTAssertGreaterThan(hypot(normalEnd.x - returnEnd.x, normalEnd.y - returnEnd.y), 20)
            XCTAssertTrue(ScenePath.edge(returning.points).commands.contains { if case .cubic = $0 { return true }; return false })
            for edge in scene.edges {
                for other in scene.edges where other.points != edge.points {
                    for (a, b) in zip(other.points, other.points.dropFirst()) {
                        XCTAssertTrue(EdgeGeometry.clear(a, b, obstacles: [edge.labelFrame.insetBy(dx: -6, dy: -6)]), "\(direction): \(edge.label)")
                    }
                }
            }
        }
    }

    private func routePoints(_ primitive: ScenePrimitive) -> [CGPoint] {
        guard case .path(let commands) = primitive.geometry else { return [] }
        return commands.compactMap { command in
            switch command { case .move(let p), .line(let p), .quad(_, let p), .cubic(_, _, let p): p; default: nil }
        }
    }

    private func segmentsMeet(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> Bool {
        let cross: (CGPoint, CGPoint, CGPoint) -> CGFloat = { p, q, r in
            (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x)
        }
        let ab = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y)).insetBy(dx: -0.001, dy: -0.001)
        let cd = CGRect(x: min(c.x, d.x), y: min(c.y, d.y), width: abs(d.x - c.x), height: abs(d.y - c.y)).insetBy(dx: -0.001, dy: -0.001)
        return ab.intersects(cd) && cross(a, b, c) * cross(a, b, d) <= 0 && cross(c, d, a) * cross(c, d, b) <= 0
    }

    private func sampledRoutePoints(_ primitive: ScenePrimitive) -> [CGPoint] {
        guard case .path(let commands) = primitive.geometry else { return [] }
        var points: [CGPoint] = []
        for command in commands {
            switch command {
            case .move(let end), .line(let end): points.append(end)
            case .cubic(let first, let second, let end):
                let start = points.last!
                for step in 1...24 {
                    let t = CGFloat(step) / 24, u = 1 - t
                    points.append(CGPoint(x: u * u * u * start.x + 3 * u * u * t * first.x + 3 * u * t * t * second.x + t * t * t * end.x,
                                          y: u * u * u * start.y + 3 * u * u * t * first.y + 3 * u * t * t * second.y + t * t * t * end.y))
                }
            default: XCTFail("Unexpected association path command")
            }
        }
        return points
    }

    private func pointDistance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y, length = dx * dx + dy * dy
        let t = length > 0 ? min(1, max(0, ((p.x - a.x) * dx + (p.y - a.y) * dy) / length)) : 0
        return hypot(p.x - a.x - dx * t, p.y - a.y - dy * t)
    }

    private func isOnRoute(_ point: CGPoint, points: [CGPoint]) -> Bool {
        zip(points, points.dropFirst()).contains { a, b in
            let length = hypot(b.x - a.x, b.y - a.y)
            guard length > 0.001 else { return false }
            let cross = abs((point.x - a.x) * (b.y - a.y) - (point.y - a.y) * (b.x - a.x)) / length
            return cross < 0.01 && point.x >= min(a.x, b.x) - 0.01 && point.x <= max(a.x, b.x) + 0.01
                && point.y >= min(a.y, b.y) - 0.01 && point.y <= max(a.y, b.y) + 0.01
        }
    }
}
