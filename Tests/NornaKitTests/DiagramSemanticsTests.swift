import XCTest
@testable import NornaKit

final class DiagramSemanticsTests: XCTestCase {
    func testSequenceControlVariantsAndNativeColor() async throws {
        for frame in ["loop retries", "opt enabled", "break stopped", "par concurrent", "critical guarded", "rect rgb(191, 223, 255)"] {
            let branch = frame.hasPrefix("par") ? "and other\nB-->>A: result\n" : frame.hasPrefix("critical") ? "option failed\nB-->>A: error\n" : ""
            let source = "sequenceDiagram\nbox Backend\nparticipant A\nparticipant B\nend\n\(frame)\nA<<-->>B: request\n\(branch)end\nNote left of A: a note\nB->>B: self"
            let scene = try await NativeDiagramRenderer().render(source).scene
            XCTAssertFalse(scene.primitives.isEmpty)
            if frame.hasPrefix("rect") { XCTAssertTrue(scene.primitives.contains { $0.style.fill == .literal("#bfdfff") }) }
        }
    }

    func testRelationshipVariantsAndCompositeState() async throws {
        let sources = [
            "classDiagram\nnamespace Domain {\nclass A {\n+id Int\n}\nclass B\n}\nA *-- B : owns\nA o-- C\nC ..|> B",
            "stateDiagram-v2\nstate Process {\ndirection LR\n[*] --> Running\nRunning --> [*]\n}\n[*] --> Process\nProcess --> Done",
            "erDiagram\nA }o..o{ B : optional\nB ||--|| C : required",
            "requirementDiagram\nrequirement R {\nid: 1\ntext: Native\n}\nelement E {\ntype: software\n}\nE - verifies -> R",
            "C4Container\nContainer(a, \"A\", \"Swift\", \"Native\")\nContainerDb(b, \"B\", \"SQLite\")\nRel_Back(a,b,\"reads\")"
        ]
        for source in sources { let artifact = try await NativeDiagramRenderer().render(source); XCTAssertFalse(artifact.scene.primitives.isEmpty) }
    }

    func testGanttDatesAndDependenciesAffectActualBarPositions() async throws {
        let scene = try await NativeDiagramRenderer().render("gantt\nA :a, 2026-10-01, 2d\nB :b, after a, 4d\nC :c, 2026-10-01, 2d").scene
        let a = try XCTUnwrap(scene.primitives.first { $0.id == "a" }), b = try XCTUnwrap(scene.primitives.first { $0.id == "b" }), c = try XCTUnwrap(scene.primitives.first { $0.id == "c" })
        XCTAssertEqual(a.bounds.minX, c.bounds.minX, accuracy: 0.001)
        XCTAssertEqual(a.bounds.maxX, b.bounds.minX, accuracy: 0.001)
        XCTAssertEqual(b.bounds.width, a.bounds.width * 2, accuracy: 0.001)
    }

    func testHierarchyFramesAreSeparatedWithLongChineseLabels() async throws {
        let scene = try await NativeDiagramRenderer().render("mindmap\n root[中心]\n  A[很长的中文标签需要自动换行并且保留足够的节点高度避免重叠]\n  B[第二个分支]\n  C[第三个分支]\n  D[第四个分支]").scene
        let nodes = scene.primitives.filter { $0.id != nil }
        for i in nodes.indices { for j in nodes.indices where i < j { XCTAssertFalse(nodes[i].bounds.intersects(nodes[j].bounds)) } }
    }

    func testArchitectureUsesRequestedPortsAndRejectsUnknownIcons() async throws {
        let scene = try await NativeDiagramRenderer().render("architecture-beta\nservice a(server)[A]\nservice b(database)[B]\na:B --> T:b").scene
        let a = try XCTUnwrap(scene.primitives.first { $0.id == "a" }), b = try XCTUnwrap(scene.primitives.first { $0.id == "b" })
        let routes = scene.primitives.compactMap { primitive -> [PathCommand]? in
            if case .path(let commands) = primitive.geometry, commands.count >= 2 { return commands }; return nil
        }
        XCTAssertTrue(routes.contains { commands in
            guard case .move(let start) = commands.first!, case .line(let end) = commands.last! else { return false }
            return abs(start.y - a.bounds.maxY) < 0.01 && abs(end.y - b.bounds.minY) < 0.01
        })
        do { _ = try await NativeDiagramRenderer().render("architecture-beta\nservice a(logos:swift)[A]"); XCTFail("Unsupported icon") }
        catch let error as DiagramRenderError { XCTAssertEqual(error.line, 2) }
    }

    func testRailroadNotationAliasesAndNestedBranches() async throws {
        for source in ["railroad-beta\nr = sequence(terminal(\"a\"), optional(nonTerminal(\"b\"))) ;", "railroad-ebnf-beta\nr = (\"a\" | \"b\") [\"c\"] { \"d\" };", "railroad-abnf-beta\nr = \"a\" / \"b\"", "railroad-peg-beta\nr <- \"a\"+ / \"b\"?"] {
            let artifact = try await NativeDiagramRenderer().render(source)
            XCTAssertEqual(artifact.type, "railroad")
            let boxes = artifact.scene.primitives.filter { if case .rectangle = $0.geometry { return true }; return false }
            for i in boxes.indices { for j in boxes.indices where i < j { XCTAssertFalse(boxes[i].bounds.intersects(boxes[j].bounds)) } }
        }
    }

    func testChartVariantsAndGitMessagesAreRetained() async throws {
        let sources = ["xychart-beta\nx-axis [A,B,C]\nbar [2,-1,4]\nline [0,3,2]", "pie title Single\n\"All\": 5", "packet-beta\n+32: \"Header\"\n+64: \"Payload\"", "venn-beta\nset A: 10\nset B: 10\nset C: 10\nunion A,B: 1\nunion A,C: 1\nunion B,C: 1", "treemap-beta\n\"Root\"\n  \"A\": 2\n  \"B\": 3", "block-beta\ncolumns 3\nA[Wide]:2 space\nB[Next]:3", "gitGraph TB\ncommit id: \"a\" msg: \"First message\"\nbranch dev\ncommit id: \"b\"\ncheckout main\ncherry-pick id: \"b\""]
        for source in sources { _ = try await NativeDiagramRenderer().render(source) }
        let git = try await NativeDiagramRenderer().render(sources.last!)
        XCTAssertTrue(git.svg.contains("First message"))
    }

    func testUnsupportedFeaturesAndInvalidParametersHaveExplicitErrors() async {
        for source in ["sequenceDiagram\ncreate participant A", "sequenceDiagram\nA->>B: hi\ndestroy B", "sequenceDiagram\nrect javascript:red\nA->>B: hi\nend", "block-beta\ncolumns 0\nA", "classDiagram\nclass A unexpected", "erDiagram\nA oo--{{ B: wrong", "swimlane-beta LR\nsubgraph X\nA\nend\nX --> A", "treeView-beta\n├── src/", "kanban\nA:::red", "sequenceDiagram\nA->>B: \u{0000}"] {
            do { _ = try await NativeDiagramRenderer().render(source); XCTFail("Unexpected acceptance: \(source)") }
            catch { XCTAssertTrue(error is DiagramRenderError) }
        }
    }
}
