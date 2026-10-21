import Foundation
import XCTest
@testable import NornaKit

final class SubgraphTests: XCTestCase {
    private let nested = """
    flowchart LR
        Start([开始]) --> A
        subgraph App[应用层]
            direction TB
            A[输入] --> B{有效？}
            subgraph Work[处理流水线]
                direction LR
                C[转换] --> D[校验]
            end
            B -->|是| C
            B -->|否| E[错误提示]
            E -.-> A
        end
        subgraph Store[存储层]
            F[(数据库)] --> G[索引]
        end
        D --> F
        G --> Done([完成])
    """

    func testParserPreservesNestedMembershipAndLocalDirections() throws {
        let graph = try MermaidFlowchartParser.parse(nested)
        XCTAssertEqual(graph.groups.count, 3)
        XCTAssertEqual(graph.groups[0].id, "App")
        XCTAssertEqual(graph.groups[0].direction, .topDown)
        XCTAssertEqual(graph.groups[1].parentID, "App")
        XCTAssertEqual(graph.groups[1].direction, .leftRight)
        XCTAssertEqual(graph.nodes.first { $0.id == "A" }?.parentID, "App")
        XCTAssertEqual(graph.nodes.first { $0.id == "D" }?.parentID, "Work")
        XCTAssertNil(graph.nodes.first { $0.id == "Start" }?.parentID)
    }

    func testCompoundLayoutContainsChildrenAndKeepsSiblingBoxesApart() throws {
        let graph = try MermaidFlowchartParser.parse(nested)
        let scene = try LayeredLayoutEngine.layout(graph)
        assertHierarchy(graph, scene)
        let c = scene.nodes.first { $0.id == "C" }!.frame
        let d = scene.nodes.first { $0.id == "D" }!.frame
        XCTAssertLessThan(c.maxX, d.minX)
        let a = scene.nodes.first { $0.id == "A" }!.frame
        let b = scene.nodes.first { $0.id == "B" }!.frame
        XCTAssertLessThan(a.maxY, b.minY)
        XCTAssertEqual(scene, try LayeredLayoutEngine.layout(graph))
    }

    func testCrossGroupEdgesAvoidNodesAndTitles() throws {
        let graph = try MermaidFlowchartParser.parse(nested)
        let scene = try LayeredLayoutEngine.layout(graph)
        assertRoutes(scene)
    }

    func testGroupEndpointsAndForwardReferencesDoNotCreateGhostNodes() throws {
        let graph = try MermaidFlowchartParser.parse("""
        flowchart LR
            Start --> Backend
            Backend --> Store
            subgraph Backend[服务端]
                A[网关] --> B[业务]
            end
            subgraph Store[存储]
                C[(数据库)]
            end
            B --> C
        """)
        XCTAssertEqual(Set(graph.nodes.map(\.id)), ["Start", "A", "B", "C"])
        let scene = try LayeredLayoutEngine.layout(graph)
        XCTAssertEqual(scene.edges.count, graph.edges.count)
        assertHierarchy(graph, scene)
        assertRoutes(scene)
    }

    func testAnonymousEmptyAndReopenedGroups() throws {
        let graph = try MermaidFlowchartParser.parse("""
        graph TD
            subgraph "中文分组 🌋"
                A[开始]
            end
            subgraph Empty["空分组<br/>第二行"]
            end
            subgraph Reopen[重复打开]
                B[第一次]
            end
            subgraph Reopen[重复打开]
                C[第二次]
            end
            A --> Reopen
        """)
        XCTAssertEqual(graph.groups.count, 3)
        XCTAssertEqual(graph.groups[1].label, "空分组\n第二行")
        XCTAssertEqual(graph.nodes.first { $0.id == "C" }?.parentID, "Reopen")
        let scene = try LayeredLayoutEngine.layout(graph)
        assertHierarchy(graph, scene)
        XCTAssertGreaterThan(scene.groups[1].frame.height, scene.groups[1].titleFrame.height)
    }

    func testInvalidGroupSyntaxHasActionableLineNumbers() throws {
        let cases: [(String, String, Int?)] = [
            ("flowchart TD\nend", "syntax", 2),
            ("flowchart TD\nsubgraph A\nB", "syntax", 2),
            ("flowchart TD\nsubgraph A\ndirection XX\nend", "syntax", 3),
            ("flowchart TD\nsubgraph A\nsubgraph A\nend\nend", "semantic", 3),
            ("flowchart TD\nA[节点]\nsubgraph A\nend", "semantic", nil),
            ("flowchart TD\nsubgraph", "syntax", 2)
        ]
        for (source, code, line) in cases {
            XCTAssertThrowsError(try MermaidFlowchartParser.parse(source)) { error in
                XCTAssertEqual((error as? DiagramRenderError)?.code, code)
                if let line { XCTAssertEqual((error as? DiagramRenderError)?.line, line) }
            }
        }
        let deep = "flowchart TD\n" + (0..<17).map { "subgraph G\($0)\n" }.joined() + "A\n" + String(repeating: "end\n", count: 17)
        XCTAssertThrowsError(try MermaidFlowchartParser.parse(deep)) { error in
            XCTAssertEqual((error as? DiagramRenderError)?.code, "limit")
        }
    }

    func testNestedGroupsAcrossAllRootAndLocalDirections() throws {
        for root in ["TD", "BT", "LR", "RL"] {
            for local in ["TD", "BT", "LR", "RL"] {
                let source = """
                flowchart \(root)
                    subgraph One[第一组]
                        direction \(local)
                        A[输入] --> B[输出]
                    end
                    subgraph Two[第二组]
                        C[处理] --> D[完成]
                    end
                    B -->|传递| C
                """
                let graph = try MermaidFlowchartParser.parse(source)
                let scene = try LayeredLayoutEngine.layout(graph)
                assertHierarchy(graph, scene)
                assertRoutes(scene)
            }
        }
    }

    func testSVGContainsEscapedGroupTitlesBehindEdgesAndNodes() async throws {
        let artifact = try await NativeFlowchartRenderer().render("""
        flowchart TD
            subgraph Group["<分组> & 中文"]
                A --> B
            end
        """)
        for theme in DiagramTheme.allCases {
            let svg = artifact.themedSVG(theme)
            XCTAssertTrue(svg.contains("&lt;分组&gt; &amp; 中文"))
            XCTAssertTrue(svg.contains("class=\"norna-cluster\""))
            XCTAssertTrue(svg.contains(theme.colors.surfaceAlt))
            XCTAssertTrue(XMLParser(data: Data(svg.utf8)).parse())
        }
    }

    func testGroupToDescendantAndSelfLoops() throws {
        let graph = try MermaidFlowchartParser.parse("""
        flowchart TD
            subgraph Outer[外层]
                subgraph Inner[内层]
                    A --> B
                    B --> B
                end
                C[其他]
            end
            Outer --> A
            B --> C
            C --> Outer
        """)
        let scene = try LayeredLayoutEngine.layout(graph)
        assertHierarchy(graph, scene)
        assertRoutes(scene)
        let outer = scene.groups.first { $0.id == "Outer" }!.frame
        for edge in scene.edges where edge.from == "Outer" || edge.to == "Outer" {
            XCTAssertTrue(edge.points.allSatisfy { outer.insetBy(dx: -0.1, dy: -0.1).contains($0) })
        }
    }

    func testBundledGroupExamplesHaveSeparatedLabels() throws {
        for example in DiagramExample.all.filter({ ["subgraphs", "nested", "groupLinks"].contains($0.id) }) {
            let graph = try MermaidFlowchartParser.parse(example.source)
            let scene = try LayeredLayoutEngine.layout(graph)
            assertHierarchy(graph, scene)
            assertRoutes(scene)
            let labels = scene.edges.filter { !$0.label.isEmpty }
            for (index, label) in labels.enumerated() {
                for other in labels.dropFirst(index + 1) {
                    XCTAssertFalse(label.labelFrame.intersects(other.labelFrame), "\(label.label) overlaps \(other.label)")
                }
            }
        }
    }

    func testLargerCompoundGraphAndForeignGroupsRemainObstacles() throws {
        var source = "flowchart LR\n"
        for group in 0..<10 {
            source += "subgraph G\(group)[分组 \(group)]\ndirection TD\n"
            source += "N\(group)_0 --> N\(group)_1 --> N\(group)_2 --> N\(group)_3\nend\n"
        }
        for group in 0..<9 { source += "N\(group)_3 --> N\(group + 1)_0\n" }
        source += "N0_2 --> N4_1\nN3_2 --> N8_1\nN9_3 --> N1_0\n"
        let graph = try MermaidFlowchartParser.parse(source)
        let scene = try LayeredLayoutEngine.layout(graph)
        assertHierarchy(graph, scene)
        assertRoutes(scene)
        let parents = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0.parentID) })
        for edge in scene.edges {
            for group in scene.groups where group.id != parents[edge.from] && group.id != parents[edge.to] {
                for (a, b) in zip(edge.points, edge.points.dropFirst()) {
                    let segment = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: max(0.01, abs(a.x - b.x)), height: max(0.01, abs(a.y - b.y)))
                    XCTAssertFalse(group.frame.insetBy(dx: 1, dy: 1).intersects(segment), "Edge crosses foreign group \(group.id)")
                }
            }
        }
    }

    func testPortsTouchActualNodeOutlines() throws {
        for example in DiagramExample.flowcharts {
            let scene = try LayeredLayoutEngine.layout(MermaidFlowchartParser.parse(example.source))
            for edge in scene.edges {
                for (id, point) in [(edge.from, edge.points.first!), (edge.to, edge.points.last!)] {
                    guard let node = scene.nodes.first(where: { $0.id == id }) else { continue }
                    let center = CGPoint(x: node.frame.midX, y: node.frame.midY)
                    let dx = point.x - center.x, dy = point.y - center.y
                    let length = hypot(dx, dy)
                    let inside = CGPoint(x: point.x - dx / length * 0.7, y: point.y - dy / length * 0.7)
                    let outside = CGPoint(x: point.x + dx / length * 0.7, y: point.y + dy / length * 0.7)
                    XCTAssertTrue(ScenePath.node(node).cgPath.contains(inside), "\(example.id): \(id) port is outside")
                    XCTAssertFalse(ScenePath.node(node).cgPath.contains(outside), "\(example.id): \(id) port is inside")
                }
            }
        }
    }

    private func assertHierarchy(_ graph: FlowchartModel, _ scene: DiagramScene, file: StaticString = #filePath, line: UInt = #line) {
        let groups = Dictionary(uniqueKeysWithValues: scene.groups.map { ($0.id, $0) })
        let canvas = CGRect(origin: .zero, size: scene.size)
        for node in scene.nodes {
            XCTAssertTrue(canvas.contains(node.frame), file: file, line: line)
            if let parent = graph.nodes.first(where: { $0.id == node.id })?.parentID {
                XCTAssertTrue(groups[parent]!.frame.contains(node.frame), node.id, file: file, line: line)
            }
            for group in scene.groups { XCTAssertFalse(group.titleFrame.intersects(node.frame), node.id, file: file, line: line) }
        }
        for group in scene.groups {
            XCTAssertTrue(canvas.contains(group.frame), file: file, line: line)
            XCTAssertTrue(group.frame.contains(group.titleFrame), file: file, line: line)
            if let parent = group.parentID { XCTAssertTrue(groups[parent]!.frame.contains(group.frame), file: file, line: line) }
            for sibling in scene.groups where sibling.id != group.id && sibling.parentID == group.parentID {
                XCTAssertFalse(group.frame.intersects(sibling.frame), "\(group.id) overlaps \(sibling.id)", file: file, line: line)
            }
        }
        for (index, node) in scene.nodes.enumerated() {
            for other in scene.nodes.dropFirst(index + 1) { XCTAssertFalse(node.frame.intersects(other.frame), file: file, line: line) }
        }
    }

    private func assertRoutes(_ scene: DiagramScene, file: StaticString = #filePath, line: UInt = #line) {
        for edge in scene.edges {
            XCTAssertGreaterThanOrEqual(edge.points.count, 2, file: file, line: line)
            for (a, b) in zip(edge.points, edge.points.dropFirst()) {
                XCTAssertTrue(abs(a.x - b.x) < 0.01 || abs(a.y - b.y) < 0.01, file: file, line: line)
                let count = max(1, Int(hypot(b.x - a.x, b.y - a.y) / 3))
                for step in 0...count {
                    let t = CGFloat(step) / CGFloat(count)
                    let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                    for node in scene.nodes where node.id != edge.from && node.id != edge.to {
                        XCTAssertFalse(node.frame.insetBy(dx: 0.5, dy: 0.5).contains(p), "\(edge.from) → \(edge.to) crosses \(node.id)", file: file, line: line)
                    }
                    for group in scene.groups {
                        XCTAssertFalse(group.titleFrame.insetBy(dx: 0.5, dy: 0.5).contains(p), "Edge crosses title \(group.id)", file: file, line: line)
                    }
                }
            }
            if !edge.label.isEmpty {
                for node in scene.nodes { XCTAssertFalse(edge.labelFrame.intersects(node.frame), "Label overlaps \(node.id)", file: file, line: line) }
            }
        }
    }
}
