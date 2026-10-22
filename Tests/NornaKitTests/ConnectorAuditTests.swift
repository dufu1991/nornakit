import AppKit
import XCTest
@testable import NornaKit

final class ConnectorAuditTests: XCTestCase {
    @MainActor
    func testEveryCuratedExampleAtThreeWidths() async throws {
        let renderer = NativeDiagramRenderer()
        let directory = ProcessInfo.processInfo.environment["NORNA_CONNECTOR_AUDIT_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        if let directory { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        var entries: [[String: Any]] = []
        for example in DiagramExample.all {
            for width: CGFloat in [320, 640, 1200] {
                let artifact = try await renderer.render(example.source, options: .init(maxWidth: width))
                let scene = artifact.scene
                XCTAssertTrue(scene.size.width.isFinite && scene.size.height.isFinite, example.id)
                XCTAssertTrue(XMLParser(data: Data(artifact.svg.utf8)).parse(), example.id)
                let audit = Self.auditConnections(scene)
                XCTAssertTrue(audit.issues.isEmpty, "\(example.id), \(Int(width)): \(audit.issues.joined(separator: "; "))")
                guard let directory else { continue }
                let point: (CGPoint) -> [CGFloat] = { [$0.x, $0.y] }
                let rect: (CGRect) -> [CGFloat] = { [$0.minX, $0.minY, $0.width, $0.height] }
                let paths: [[String: Any]] = scene.primitives.compactMap { primitive in
                    guard case .path(let commands) = primitive.geometry, primitive.style.fill == .none,
                          !commands.contains(.close) else { return nil }
                    let encoded: [[Any]] = commands.map { command in
                        switch command {
                        case .move(let p): return ["M"] + point(p)
                        case .line(let p): return ["L"] + point(p)
                        case .quad(let a, let p): return ["Q"] + point(a) + point(p)
                        case .cubic(let a, let b, let p): return ["C"] + point(a) + point(b) + point(p)
                        case .close: return ["Z"]
                        }
                    }
                    return ["id": primitive.id ?? "", "commands": encoded, "stroke": String(describing: primitive.style.stroke)]
                }
                let nodes = scene.nodes.map { ["id": $0.id, "frame": rect($0.frame)] as [String: Any] }
                    + scene.primitives.filter { $0.id != nil && $0.style.fill != .none }.map { ["id": $0.id!, "frame": rect($0.bounds)] }
                let edges = scene.edges.map { ["from": $0.from, "to": $0.to, "points": $0.points.map(point), "label": $0.label, "labelFrame": rect($0.labelFrame)] as [String: Any] }
                let texts = scene.primitives.compactMap { primitive -> [String: Any]? in
                    guard case .text(let t) = primitive.geometry else { return nil }
                    return ["text": t.text, "frame": rect(t.frame), "size": t.size]
                }
                entries.append(["id": example.id, "title": example.title, "kind": example.kind.rawValue, "width": width,
                                "connections": audit.count, "issues": audit.issues, "size": [scene.size.width, scene.size.height], "nodes": nodes, "edges": edges, "paths": paths, "texts": texts])
                let fixtureDirectory = directory.appendingPathComponent(String(Int(width)), isDirectory: true)
                try FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)
                try artifact.themedSVG(.appleLight).write(to: fixtureDirectory.appendingPathComponent(example.id + ".svg"), atomically: true, encoding: .utf8)
                try example.source.write(to: fixtureDirectory.appendingPathComponent(example.id + ".mmd"), atomically: true, encoding: .utf8)
                let scale = min(1.5, 2400 / max(scene.size.width, scene.size.height))
                let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(ceil(scene.size.width * scale)),
                    pixelsHigh: Int(ceil(scene.size.height * scale)), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
                let graphics = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
                NSGraphicsContext.saveGraphicsState()
                graphics.cgContext.translateBy(x: 0, y: CGFloat(bitmap.pixelsHigh))
                graphics.cgContext.scaleBy(x: scale, y: -scale)
                NSGraphicsContext.current = NSGraphicsContext(cgContext: graphics.cgContext, flipped: true)
                CoreGraphicsDiagramPainter.color(DiagramTheme.appleLight.background).setFill()
                CGRect(origin: .zero, size: scene.size).fill()
                CoreGraphicsDiagramPainter.draw(scene, theme: .appleLight)
                NSGraphicsContext.restoreGraphicsState()
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: fixtureDirectory.appendingPathComponent(example.id + ".png"))
            }
        }
        XCTAssertEqual(entries.count, directory == nil ? 0 : DiagramExample.all.count * 3)
        if let directory {
            try JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("geometry.json"))
        }
    }

    func testFixedGridSkipEdgesAndBackwardReferencesAvoidNodes() async throws {
        let block = """
        block-beta
        columns 3
        A[输入] B[处理中] C[输出]
        D[下一行] E[中间节点] F[归档]
        A -->|跳过中间节点| C
        C --> A
        F --> D
        D --> A
        A --> A
        """
        let events = """
        eventmodeling
        rf A ui 起始页面 ->> C
        rf B cmd 中间命令
        rf C evt 后续事件
        """
        for source in [block, events] {
            let scene = try await NativeDiagramRenderer().render(source).scene
            XCTAssertTrue(Self.auditConnections(scene).issues.isEmpty, Self.auditConnections(scene).issues.joined(separator: "; "))
            if scene.kind == .eventmodeling {
                let route = try XCTUnwrap(scene.primitives.first { $0.id == "event-edge-0" })
                guard case .path(let commands) = route.geometry else { return XCTFail("Expected event dependency") }
                let segments = EdgeGeometry.segments(commands)
                let source = try XCTUnwrap(scene.primitives.first { $0.id == "C" })
                let target = try XCTUnwrap(scene.primitives.first { $0.id == "A" })
                XCTAssertTrue(source.bounds.insetBy(dx: -0.01, dy: -0.01).contains(try XCTUnwrap(segments.first?.0)))
                XCTAssertTrue(target.bounds.insetBy(dx: -0.01, dy: -0.01).contains(try XCTUnwrap(segments.last?.1)))
            }
        }
    }

    func testSequenceSelfMessageLabelsStayInsideTheirRoundedLoops() async throws {
        let source = """
        sequenceDiagram
        autonumber
        participant API as 订单服务
        participant DB as 数据库
        API->>API: 验证订单并检查所有必要字段与重复提交状态
        API->>DB: 保存订单
        DB-->>API: 返回订单编号
        """
        for width: CGFloat in [320, 640, 1200] {
            let scene = try await NativeDiagramRenderer().render(source, options: .init(maxWidth: width)).scene
            XCTAssertTrue(Self.auditConnections(scene).issues.isEmpty, Self.auditConnections(scene).issues.joined(separator: "; "))
            let loop = try XCTUnwrap(scene.primitives.first { $0.id == "message-0" })
            guard case .path(let commands) = loop.geometry else { return XCTFail("Expected self message") }
            XCTAssertEqual(commands.filter { if case .cubic = $0 { return true }; return false }.count, 2)
            let label = try XCTUnwrap(scene.primitives.first { $0.id == "edge-label-message-0" })
            XCTAssertLessThan(label.bounds.maxX, loop.bounds.maxX - 12)
            let lifeline = try XCTUnwrap(scene.primitives.first { $0.id == "lifeline-DB" })
            XCTAssertLessThan(loop.bounds.maxX, lifeline.bounds.minX)
        }
    }

    private struct Route {
        let id: String
        let commands: [PathCommand]
        let label: CGRect?
        let loop: Bool
        var segments: [(CGPoint, CGPoint)] { EdgeGeometry.segments(commands) }
    }

    static func auditConnections(_ scene: DiagramScene) -> (count: Int, issues: [String]) {
        let prefixes = ["relation-", "lane-edge-", "block-edge-", "architecture-edge-", "event-edge-", "message-"]
        let masks = Dictionary(uniqueKeysWithValues: scene.primitives.compactMap { primitive -> (String, CGRect)? in
            guard let id = primitive.id, id.contains("-label-") else { return nil }
            return (id, primitive.bounds)
        })
        var routes = scene.edges.filter { $0.style != .invisible }.enumerated().map { index, edge in
            Route(id: "\(index):\(edge.from)->\(edge.to)", commands: ScenePath.edge(edge.points).commands,
                  label: edge.label.isEmpty ? nil : edge.labelFrame, loop: edge.from == edge.to)
        }
        if routes.isEmpty {
            routes = scene.primitives.compactMap { primitive -> Route? in
                guard let id = primitive.id, prefixes.contains(where: id.hasPrefix), !id.contains("-label-"),
                      case .path(let commands) = primitive.geometry else { return nil }
                let labelID = "edge-label-" + id
                let curvedMessage = id.hasPrefix("message-") && commands.contains { if case .cubic = $0 { return true }; return false }
                return Route(id: id, commands: commands, label: masks[labelID], loop: curvedMessage)
            }
        }
        let frames = scene.nodes.map(\.frame) + scene.primitives.filter { primitive in
            guard let id = primitive.id, primitive.style.fill != .none else { return false }
            return !id.contains("-label-") && !id.hasPrefix("multiplicity-")
        }.map(\.bounds)
        let segments = routes.map(\.segments)
        var issues: [String] = []
        for (index, route) in routes.enumerated() {
            guard let start = segments[index].first?.0, let end = segments[index].last?.1 else { issues.append("empty route \(route.id)"); continue }
            let obstacles = frames.filter { !$0.insetBy(dx: -1, dy: -1).contains(start) && !$0.insetBy(dx: -1, dy: -1).contains(end) }
            if segments[index].contains(where: { !EdgeGeometry.clear($0.0, $0.1, obstacles: obstacles) }) { issues.append("node collision \(route.id)") }
            let aligned = abs(start.x - end.x) < 0.01 || abs(start.y - end.y) < 0.01
            if !route.loop, !frames.contains(where: { $0.insetBy(dx: -1, dy: -1).contains(start) && $0.insetBy(dx: -1, dy: -1).contains(end) }), aligned, hypot(start.x - end.x, start.y - end.y) > 1,
               EdgeGeometry.clear(start, end, obstacles: frames), route.commands.count > 2 {
                issues.append("avoidable aligned bend \(route.id)")
            }
            if let label = route.label {
                let center = CGPoint(x: label.midX, y: label.midY)
                var cursor = CGPoint.zero
                var inline = false
                for command in route.commands {
                    switch command {
                    case .line(let end):
                        let distance = hypot(end.x - cursor.x, end.y - cursor.y)
                        if distance > 0.01 {
                            let deviation = abs((center.x - cursor.x) * (end.y - cursor.y) - (center.y - cursor.y) * (end.x - cursor.x)) / distance
                            if deviation < 0.01 && CGRect(x: min(cursor.x, end.x), y: min(cursor.y, end.y), width: abs(end.x - cursor.x), height: abs(end.y - cursor.y)).insetBy(dx: -0.01, dy: -0.01).contains(center) { inline = true }
                        }
                        cursor = end
                    case .move(let p), .quad(_, let p), .cubic(_, _, let p): cursor = p
                    case .close: break
                    }
                }
                if !inline { issues.append("label outside route \(route.id)") }
                if frames.contains(where: { $0.intersects(label) }) { issues.append("label on node \(route.id)") }
                for other in routes.indices where other != index {
                    if segments[other].contains(where: { !EdgeGeometry.clear($0.0, $0.1, obstacles: [label]) }) { issues.append("label crosses \(route.id) / \(routes[other].id)") }
                }
            }
            for other in routes.indices where other > index {
                let overlap = segments[index].reduce(CGFloat(0)) { total, pair in
                    total + segments[other].reduce(CGFloat(0)) { sum, second in
                        for axis in 0...1 {
                            let p = axis == 0 ? [pair.0.x, pair.1.x, second.0.x, second.1.x] : [pair.0.y, pair.1.y, second.0.y, second.1.y]
                            let q = axis == 0 ? [pair.0.y, pair.1.y, second.0.y, second.1.y] : [pair.0.x, pair.1.x, second.0.x, second.1.x]
                            if abs(q[0] - q[1]) < 0.001 && abs(q[2] - q[3]) < 0.001 && abs(q[0] - q[2]) < 0.001 {
                                return sum + max(0, min(max(p[0], p[1]), max(p[2], p[3])) - max(min(p[0], p[1]), min(p[2], p[3])))
                            }
                        }
                        return sum
                    }
                }
                if overlap > 1 { issues.append("shared segment \(route.id) / \(routes[other].id)") }
            }
        }
        return (routes.count, issues)
    }

}
