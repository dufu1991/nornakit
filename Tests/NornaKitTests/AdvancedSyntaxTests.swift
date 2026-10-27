import AppKit
import XCTest
@testable import NornaKit
import NornaExamples

final class AdvancedSyntaxTests: XCTestCase {
    func testFlowchartMarkersSurviveFlatAndCompoundLayout() throws {
        for grouped in [false, true] {
            let body = "A <--> B\nB o--o C\nC x--x D\nD -.-> E\nE === F\nF ~~~ A"
            let source = "flowchart TD\n" + (grouped ? "subgraph G[分组]\n\(body)\nend" : body)
            let graph = try MermaidFlowchartParser.parse(source)
            let scene = try LayeredLayoutEngine.layout(graph)
            XCTAssertEqual(scene.edges[0].startMarker, .arrow)
            XCTAssertEqual(scene.edges[0].endMarker, .arrow)
            XCTAssertEqual(scene.edges[1].startMarker, .circle)
            XCTAssertEqual(scene.edges[1].endMarker, .circle)
            XCTAssertEqual(scene.edges[2].startMarker, .cross)
            XCTAssertEqual(scene.edges[2].endMarker, .cross)
            XCTAssertEqual(scene.edges[3].style, .dashed)
            XCTAssertEqual(scene.edges[4].style, .thick)
            XCTAssertEqual(scene.edges[5].style, .invisible)
            let visibleOnly = DiagramScene(size: scene.size, nodes: scene.nodes, edges: Array(scene.edges.dropLast()), groups: scene.groups)
            XCTAssertEqual(SVGExporter.export(scene, theme: .appleDark), SVGExporter.export(visibleOnly, theme: .appleDark))
        }
    }

    func testExpandedShapesHaveMatchingOutlinesAndPorts() throws {
        let graph = try MermaidFlowchartParser.parse(#"""
        flowchart TD
        A{{六边形}} --> B>非对称节点]
        B --> C[/平行四边形/]
        C --> D[\反向平行四边形\]
        D --> E[/梯形\]
        E --> F[\反向梯形/]
        F --> G(((双圆)))
        H@{ label: "文本含有逗号、英文 comma, 和冒号: end", shape: hex }
        """#)
        XCTAssertEqual(graph.nodes.map(\.shape), [.hexagon, .asymmetric, .parallelogram, .parallelogramAlt, .trapezoid, .trapezoidAlt, .doubleCircle, .hexagon])
        XCTAssertTrue(graph.nodes.last!.label.contains("comma,"))
        for node in graph.nodes {
            let frame = CGRect(x: 10, y: 10, width: 160, height: 90)
            let outline = ScenePath.node(SceneNode(id: node.id, label: node.label, shape: node.shape, frame: frame, lines: [] )).cgPath
            for side in 0..<4 {
                for fraction: CGFloat in [-0.7, -0.25, 0, 0.65] {
                    let point = NodeGeometry.anchor(shape: node.shape, frame: frame, side: side, offset: fraction * (side.isMultiple(of: 2) ? frame.width : frame.height) / 2)
                    let outward = [CGPoint(x: 0, y: -1), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: -1, y: 0)][side]
                    XCTAssertTrue(outline.contains(CGPoint(x: point.x - outward.x * 0.2, y: point.y - outward.y * 0.2)), "\(node.shape): \(side)")
                    XCTAssertFalse(outline.contains(CGPoint(x: point.x + outward.x * 0.2, y: point.y + outward.y * 0.2)), "\(node.shape): \(side)")
                }
            }
        }
    }

    func testLongFlowchartEdgesReserveRanksAndMalformedAttributesFail() throws {
        let short = try LayeredLayoutEngine.layout(MermaidFlowchartParser.parse("flowchart TD\nA-->B"))
        let long = try LayeredLayoutEngine.layout(MermaidFlowchartParser.parse("flowchart TD\nA---->B"))
        XCTAssertGreaterThan(long.size.height, short.size.height + 50)
        for source in ["flowchart TD\nA@{shape: unknown}", "flowchart TD\nA@{shape: rect, shape: circle}", "flowchart TD\nA@{icon: foo}", "flowchart TD\nA-------------->B"] {
            XCTAssertThrowsError(try MermaidFlowchartParser.parse(source))
        }
    }

    func testSequenceLifecycleIsBoundToMessagesAndStopsLifelines() throws {
        let example = try XCTUnwrap(DiagramExample.advanced.first { $0.id == "sequence-lifecycle" })
        let model = try SequenceDiagram.parse(example.source)
        let create = try XCTUnwrap(model.events.firstIndex(of: .create("Worker")))
        let destroy = try XCTUnwrap(model.events.firstIndex(of: .destroy("Worker")))
        XCTAssertEqual(model.events[create + 1], .message("API", "Worker", "创建并执行", "->>", 0))
        XCTAssertEqual(model.events[destroy - 1], .message("API", "Worker", "释放资源", "-x", 0))
        XCTAssertTrue(model.events.contains(.note(["API", "Worker"], "over", "任务结束后释放工作进程\n生命线在销毁消息处结束")))
        let scene = try SequenceDiagram.layout(model, options: .init())
        let workerHeaders = scene.primitives.filter { $0.id == "participant-Worker" }
        let workerLife = try XCTUnwrap(scene.primitives.first { $0.id == "lifeline-Worker" })
        let termination = try XCTUnwrap(scene.primitives.first { $0.id == "destroy-Worker" })
        XCTAssertEqual(workerHeaders.count, 1)
        XCTAssertGreaterThan(workerHeaders[0].bounds.minY, scene.primitives.first { $0.id == "participant-API" }!.bounds.minY + 80)
        XCTAssertEqual(workerLife.bounds.minY, workerHeaders[0].bounds.maxY, accuracy: 0.01)
        XCTAssertEqual(workerLife.bounds.maxY, termination.bounds.midY, accuracy: 0.01)
        XCTAssertLessThan(workerLife.bounds.maxY, scene.primitives.first { $0.id == "lifeline-User" }!.bounds.maxY)
    }

    func testSequenceLifecycleRejectsInvalidTransitionsWithLineNumbers() {
        let invalid = [
            "sequenceDiagram\nparticipant A\ncreate participant A\nB->>A: create",
            "sequenceDiagram\ncreate participant B\nB->>A: wrong recipient",
            "sequenceDiagram\nparticipant A\ndestroy A\nB->>C: unrelated",
            "sequenceDiagram\nparticipant A\ndestroy A",
            "sequenceDiagram\ncreate participant A",
            "sequenceDiagram\nA->>B: one\ndestroy B\nA-xB: stop\nB->>A: illegal",
            "sequenceDiagram\nnote over A\nunclosed"
        ]
        for source in invalid {
            XCTAssertThrowsError(try SequenceDiagram.parse(source)) { error in
                XCTAssertNotNil((error as? DiagramRenderError)?.line)
            }
        }
        XCTAssertNoThrow(try SequenceDiagram.parse("sequenceDiagram\nA->>+ B: start\nB-->>- A: done"))
        XCTAssertNoThrow(try SequenceDiagram.parse("sequenceDiagram\nA->>B: start\ndestroy B\nB->>A: finish"))
    }

    func testSequenceParticipantTypesDrawDistinctSymbolsAndRespectAliasPrecedence() throws {
        let types: [SequenceParticipantStyle] = [.participant, .actor, .boundary, .control, .entity, .database, .collections, .queue]
        var geometries: [[VectorGeometry]] = []
        for style in types {
            let source = "sequenceDiagram\nparticipant A@{\"type\":\"\(style.rawValue)\",\"alias\":\"内部名称\"} as 外部名称\nA->>B: 请求"
            let model = try SequenceDiagram.parse(source)
            XCTAssertEqual(model.participants[0].style, style)
            XCTAssertEqual(model.participants[0].label, "外部名称")
            let scene = try SequenceDiagram.layout(model, options: .init())
            let shapes = scene.primitives.compactMap { primitive -> VectorGeometry? in
                if case .text = primitive.geometry { return nil }
                return primitive.geometry
            }
            XCTAssertFalse(geometries.contains(shapes), style.rawValue)
            geometries.append(shapes)
            XCTAssertTrue(XMLParser(data: Data(SVGExporter.export(scene, theme: .appleDark).utf8)).parse())
        }
        for attributes in [#"{"type":"unknown"}"#, #"{"type":5}"#, #"{"type":"database","url":"https://example.com"}"#, #"{broken}"#] {
            XCTAssertThrowsError(try SequenceDiagram.parse("sequenceDiagram\nparticipant A@\(attributes)\nA->>B: request")) { error in
                XCTAssertEqual((error as? DiagramRenderError)?.line, 2)
            }
        }
    }

    func testClassAnnotationsCardinalityNotesAndQuotedNamesKeepTheirSemantics() throws {
        let graph = try ClassDiagram.parse("""
        classDiagram
            namespace API["应用接口"] {
                class `Payment Service` <<interface>>
                `Payment Service` : +authorize() bool
                class Order {
                    <<entity>>
                    +String id
                    +total() Money
                }
                `Payment Service` "1" <|..|> "0..*" Order : 关联
            }
            <<service>> Order
            note for Order "一笔订单<br>多个项目"
            note "总览"
        """)
        XCTAssertEqual(graph.groups[0].label, "应用接口")
        XCTAssertEqual(graph.entities.first { $0.id == "Payment Service" }?.stereotype, "«interface»")
        XCTAssertEqual(graph.entities.first { $0.id == "Order" }?.stereotype, "«service»")
        XCTAssertEqual(graph.entities.first { $0.id == "Order" }?.members, ["+String id", "+total() Money"])
        XCTAssertEqual(graph.relations[0].fromMultiplicity, "1")
        XCTAssertEqual(graph.relations[0].toMultiplicity, "0..*")
        XCTAssertEqual(graph.relations[0].start, "triangle")
        XCTAssertEqual(graph.relations[0].end, "triangle")
        XCTAssertTrue(graph.relations[0].dashed)
        XCTAssertEqual(graph.notes[0].target, "Order")
        XCTAssertEqual(graph.notes[0].text, "一笔订单\n多个项目")
        let scene = try graph.scene()
        XCTAssertEqual(scene.primitives.filter { $0.id?.hasPrefix("note-") == true }.count, 2)
        let cardinalities = scene.primitives.filter { $0.id?.hasPrefix("multiplicity-") == true }
        XCTAssertEqual(cardinalities.count, 2)
        XCTAssertFalse(cardinalities[0].bounds.intersects(cardinalities[1].bounds))
        XCTAssertNoThrow(try ClassDiagram.render("classDiagram\nnote \"独立注释\""))
        let lollipop = try ClassDiagram.parse("classDiagram\nA ()-- B\nB --() C")
        XCTAssertEqual(lollipop.relations[0].start, "interface")
        XCTAssertEqual(lollipop.relations[1].end, "interface")
    }

    func testReverseStateTransitionsKeepTheirLabelsSeparate() throws {
        let scene = try StateDiagram.render("stateDiagram-v2\nstate Active {\nA-->B: 接收任务\nB-->A: 完成\n}")
        let labels = scene.primitives.compactMap { primitive -> SceneText? in
            guard case .text(let text) = primitive.geometry, ["接收任务", "完成"].contains(text.text) else { return nil }
            return text
        }
        XCTAssertEqual(labels.count, 2)
        XCTAssertFalse(labels[0].frame.intersects(labels[1].frame))
    }

    func testStateParallelRegionsOwnDistinctInitialAndFinalStates() throws {
        let graph = try StateDiagram.parse("""
        stateDiagram-v2
            state "运行中" as Active {
                [*] --> A
                A --> [*]
                --
                [*] --> B
                B --> [*]
                --
                [*] --> C
            }
            note left of Active: 三个并发区域
        """)
        XCTAssertEqual(graph.regionGroups.count, 3)
        XCTAssertEqual(Set(graph.entities.filter { $0.stateMarker == 1 }.map(\.parent)).count, 3)
        XCTAssertEqual(Set(graph.entities.filter { $0.stateMarker == 2 }.map(\.parent)).count, 2)
        XCTAssertEqual(graph.groups.first { $0.id == "Active" }?.label, "运行中")
        XCTAssertEqual(graph.notes.first?.side, "left")
        XCTAssertNoThrow(try graph.scene())
        XCTAssertThrowsError(try StateDiagram.parse("stateDiagram-v2\n--"))
        XCTAssertThrowsError(try StateDiagram.parse("stateDiagram-v2\nnote right of A\nunclosed"))
    }

    func testForkAndJoinBarsArePerpendicularAndTransitionsTouchTheirEdges() throws {
        for direction in ["TD", "LR", "RL", "BT"] {
            let scene = try StateDiagram.render("stateDiagram-v2\ndirection \(direction)\nstate F <<fork>>\nstate J <<join>>\n[*]-->F\nF-->A\nF-->B\nA-->J\nB-->J\nJ-->[*]")
            let svg = SVGExporter.export(scene, theme: .appleLight)
            XCTAssertTrue(XMLParser(data: Data(svg.utf8)).parse())
            for id in ["F", "J"] {
                let bar = try XCTUnwrap(scene.primitives.first { $0.id == id })
                XCTAssertEqual(min(bar.bounds.width, bar.bounds.height), 8, accuracy: 0.01)
                XCTAssertGreaterThan(max(bar.bounds.width, bar.bounds.height), 30)
                XCTAssertEqual(bar.bounds.height > bar.bounds.width, direction == "LR" || direction == "RL")
            }
            for (index, id, atStart) in [(0, "F", false), (1, "F", true), (2, "F", true), (3, "J", false), (4, "J", false), (5, "J", true)] {
                let bar = try XCTUnwrap(scene.primitives.first { $0.id == id })
                let transition = try XCTUnwrap(scene.primitives.first { $0.id == "relation-\(index)" })
                guard case .path(let commands) = transition.geometry else { return XCTFail("Expected transition path") }
                let endpoint = atStart ? commands.first : commands.last
                let point: CGPoint
                switch endpoint {
                case .move(let value), .line(let value): point = value
                default: return XCTFail("Expected path endpoint")
                }
                XCTAssertTrue(bar.bounds.insetBy(dx: -0.01, dy: -0.01).contains(point))
                let distance = min(abs(point.x - bar.bounds.minX), abs(point.x - bar.bounds.maxX), abs(point.y - bar.bounds.minY), abs(point.y - bar.bounds.maxY))
                XCTAssertLessThan(distance, 0.01)
            }
        }
    }

    @MainActor
    func testAdvancedExamplesRenderAtThreeWidthsInEverySystemAppearance() async throws {
        let renderer = NativeDiagramRenderer()
        let themes: [DiagramTheme] = [.appleLight, .appleDark, .appleLightHighContrast, .appleDarkHighContrast]
        for example in DiagramExample.advanced {
            for width in [320, 480, 640] {
                let artifact = try await renderer.render(example.source, options: .init(maxWidth: CGFloat(width)))
                for primitive in artifact.scene.primitives where !primitive.bounds.isNull {
                    XCTAssertGreaterThanOrEqual(primitive.bounds.minX, 0, example.id)
                    XCTAssertGreaterThanOrEqual(primitive.bounds.minY, 0, example.id)
                    XCTAssertLessThanOrEqual(primitive.bounds.maxX, artifact.width + 0.01, example.id)
                    XCTAssertLessThanOrEqual(primitive.bounds.maxY, artifact.height + 0.01, example.id)
                }
                for theme in themes {
                    XCTAssertTrue(XMLParser(data: Data(artifact.themedSVG(theme).utf8)).parse(), example.id)
                    if width == 640, let directory = ProcessInfo.processInfo.environment["NORNA_COMPLEX_FIXTURE_DIR"] {
                        try writeFixture(artifact, example: example, theme: theme, directory: directory)
                    }
                }
            }
        }
    }

    @MainActor
    private func writeFixture(_ artifact: DiagramArtifact, example: DiagramExample, theme: DiagramTheme, directory: String) throws {
        let scene = artifact.scene, scale = min(1.5, 1800 / max(scene.size.width, scene.size.height))
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(ceil(scene.size.width * scale)),
            pixelsHigh: Int(ceil(scene.size.height * scale)), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let graphics = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        graphics.cgContext.translateBy(x: 0, y: CGFloat(bitmap.pixelsHigh)); graphics.cgContext.scaleBy(x: scale, y: -scale)
        NSGraphicsContext.current = NSGraphicsContext(cgContext: graphics.cgContext, flipped: true)
        CoreGraphicsDiagramPainter.color(theme.background).setFill(); CGRect(origin: .zero, size: scene.size).fill()
        CoreGraphicsDiagramPainter.draw(scene, theme: theme)
        NSGraphicsContext.restoreGraphicsState()
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        XCTAssertGreaterThan(png.count, 1000)
        let url = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let name = "\(example.kind.rawValue)-\(theme.rawValue)"
        try png.write(to: url.appendingPathComponent(name + ".png"))
        try artifact.themedSVG(theme).write(to: url.appendingPathComponent(name + ".svg"), atomically: true, encoding: .utf8)
    }
}
