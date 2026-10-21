import Foundation
import XCTest
@testable import NornaKit

final class NativeFlowchartTests: XCTestCase {
    func testBundledExamplesRenderWithoutOverlappingNodes() async throws {
        let renderer = NativeFlowchartRenderer()
        for example in DiagramExample.flowcharts {
            let artifact = try await renderer.render(example.source)
            XCTAssertTrue(artifact.width.isFinite && artifact.width > 0, example.id)
            XCTAssertTrue(artifact.height.isFinite && artifact.height > 0, example.id)
            assertNoNodeOverlaps(artifact.scene)
            let parser = XMLParser(data: Data(artifact.svg.utf8))
            XCTAssertTrue(parser.parse(), parser.parserError?.localizedDescription ?? "")
        }
    }

    func testAllSevenShapesAndReferenceDoesNotOverwriteLabel() throws {
        let model = try MermaidFlowchartParser.parse("""
        graph LR
            A[中文] --> B(圆角) --> C([起止]) --> D{判断}
            D --> E((圆形)) & F[(数据库)]
            E & F --> G[[子程序]]
            A --> G
        """)
        XCTAssertEqual(model.nodes.map(\.shape), [.rectangle, .rounded, .stadium, .diamond, .circle, .cylinder, .subroutine])
        XCTAssertEqual(model.nodes[0].label, "中文")
        XCTAssertEqual(model.edges.count, 8)
    }

    func testDirectionTransforms() throws {
        for direction in ["TD", "TB", "BT", "LR", "RL"] {
            let graph = try MermaidFlowchartParser.parse("flowchart \(direction)\n A --> B --> C")
            let scene = try LayeredLayoutEngine.layout(graph)
            let a = scene.nodes[0].frame, b = scene.nodes[1].frame
            switch direction {
            case "TD", "TB": XCTAssertLessThan(a.maxY, b.minY)
            case "BT": XCTAssertGreaterThan(a.minY, b.maxY)
            case "LR": XCTAssertLessThan(a.maxX, b.minX)
            default: XCTAssertGreaterThan(a.minX, b.maxX)
            }
            assertNoNodeOverlaps(scene)
        }
    }

    func testCyclesSelfLoopsAndDisconnectedNodesAreFiniteAndDeterministic() throws {
        let graph = try MermaidFlowchartParser.parse("""
        flowchart TD
            A --> B --> C --> A
            B --> B
            Isolated[独立节点]
        """)
        let scene = try LayeredLayoutEngine.layout(graph)
        XCTAssertEqual(scene, try LayeredLayoutEngine.layout(graph))
        XCTAssertEqual(scene.nodes.count, 4)
        XCTAssertEqual(scene.edges.count, 4)
        for edge in scene.edges {
            XCTAssertGreaterThanOrEqual(edge.points.count, 2)
            XCTAssertTrue(edge.points.allSatisfy { $0.x.isFinite && $0.y.isFinite })
        }
        assertNoNodeOverlaps(scene)
    }

    func testLongEdgesHaveReservedCorridors() throws {
        let graph = try MermaidFlowchartParser.parse("""
        flowchart TD
            A --> B --> C --> D --> E
            A --> E
            B --> D
        """)
        let scene = try LayeredLayoutEngine.layout(graph)
        assertEdgesAvoidOtherNodes(scene)
    }

    func testQuotedDelimitersChineseEmojiAndLineBreaks() throws {
        let graph = try MermaidFlowchartParser.parse("""
        flowchart TD;
        %% 注释不应生成节点。
        A["中文 [方括号] 与 Swift 6 🌋<br/>第二行"] -->|标签| B[结束]
        A --> C["分号; 与 %% 作为文本"] %% 行尾注释。
        """)
        XCTAssertEqual(graph.nodes[0].label, "中文 [方括号] 与 Swift 6 🌋\n第二行")
        XCTAssertEqual(graph.nodes[2].label, "分号; 与 %% 作为文本")
        XCTAssertEqual(graph.nodes.count, 3)
    }

    func testLabelsAndEdgeStyles() throws {
        let model = try MermaidFlowchartParser.parse("""
        flowchart LR
            A -- 请求 --> B
            B -. 异步 .-> C
            C == 重要 ==> D
            D --- E
            E -.->|虚线| F
        """)
        XCTAssertEqual(model.edges.map(\.label), ["请求", "异步", "重要", "", "虚线"])
        XCTAssertEqual(model.edges.map(\.style), [.solid, .dashed, .thick, .solid, .dashed])
        XCTAssertFalse(model.edges[3].arrow)
    }

    func testInvalidOrUnsupportedSyntaxReportsSourceLine() throws {
        let inputs: [(String, String, Int)] = [
            ("flowchart TD\n A[unfinished", "syntax", 2),
            ("flowchart TD\n A -->", "syntax", 2),
            ("flowchart TD\n style A fill:red", "unsupported-syntax", 2),
            ("sequenceDiagram\n A->>B: Hello", "unsupported-diagram", 1),
            ("flowchart XX\n A --> B", "syntax", 1)
        ]
        for (source, code, line) in inputs {
            XCTAssertThrowsError(try MermaidFlowchartParser.parse(source)) { error in
                let error = error as? DiagramRenderError
                XCTAssertEqual(error?.code, code)
                XCTAssertEqual(error?.line, line)
            }
        }
        XCTAssertThrowsError(try MermaidFlowchartParser.parse(String(repeating: "x", count: 50_001)))
    }

    func testSVGIsSelfContainedEscapesUserTextAndIncludesSelectedPalette() async throws {
        let result = try await NativeFlowchartRenderer().render("flowchart TD\n A[\"<script> & 中文\"] --> B[正常]")
        for theme in DiagramTheme.allCases {
            let svg = result.themedSVG(theme)
            XCTAssertTrue(svg.contains(theme.background))
            XCTAssertTrue(svg.contains("&lt;script&gt; &amp; 中文"))
            XCTAssertFalse(svg.contains("<script>"))
            XCTAssertFalse(svg.contains("var(--"))
            let parser = XMLParser(data: Data(svg.utf8))
            XCTAssertTrue(parser.parse(), parser.parserError?.localizedDescription ?? "")
        }
    }

    func testMultipleIncomingAndOutgoingEdgesAcrossGeneratedDAGs() throws {
        for seed in 0..<12 {
            var source = "flowchart TD\n"
            for i in 0..<14 { source += "N\(i) --> N\(i + 1)\n" }
            for i in 0..<12 where (i + seed).isMultiple(of: 3) { source += "N\(i) --> N\(i + 3)\n" }
            let scene = try LayeredLayoutEngine.layout(MermaidFlowchartParser.parse(source))
            assertNoNodeOverlaps(scene)
            assertEdgesAvoidOtherNodes(scene)
        }
    }

    private func assertNoNodeOverlaps(_ scene: DiagramScene, file: StaticString = #filePath, line: UInt = #line) {
        for (index, a) in scene.nodes.enumerated() {
            XCTAssertTrue(CGRect(origin: .zero, size: scene.size).contains(a.frame), file: file, line: line)
            for b in scene.nodes.dropFirst(index + 1) {
                XCTAssertFalse(a.frame.intersects(b.frame), "\(a.id) overlaps \(b.id)", file: file, line: line)
            }
        }
    }

    private func assertEdgesAvoidOtherNodes(_ scene: DiagramScene, file: StaticString = #filePath, line: UInt = #line) {
        for edge in scene.edges {
            for (a, b) in zip(edge.points, edge.points.dropFirst()) {
                let count = max(1, Int(hypot(b.x - a.x, b.y - a.y) / 4))
                for step in 0...count {
                    let t = CGFloat(step) / CGFloat(count)
                    let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                    for node in scene.nodes where node.id != edge.from && node.id != edge.to {
                        XCTAssertFalse(node.frame.insetBy(dx: 1, dy: 1).contains(p), "\(edge.from) -> \(edge.to) crosses \(node.id)", file: file, line: line)
                    }
                }
            }
        }
    }
}
