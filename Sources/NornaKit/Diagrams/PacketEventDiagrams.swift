import Foundation

enum PacketEventDiagrams {
    static func packet(_ source: String) throws -> DiagramScene {
        let lines = DiagramSyntax.lines(source), b = SceneBuilder(.packet)
        var blocks: [(Int, Int, String)] = [], lastEnd = -1
        for line in lines.dropFirst() {
            if line.text.hasPrefix("title ") { continue }
            guard let m = DiagramSyntax.match(#"^(\+?\d+)(?:-(\d+))?\s*:\s*"([^"]+)"$"#, line.text) else { throw line.error("数据包字段应写作起止比特范围和双引号标签。", code: "syntax") }
            let start: Int, end: Int
            if m[1].hasPrefix("+") {
                guard let length = Int(m[1].dropFirst()), length > 0, length <= 65_536 else { throw line.error("字段长度无效。", code: "semantic") }
                start = lastEnd + 1; end = start + length - 1
            } else {
                guard let a = Int(m[1]), let z = Int(m[2].isEmpty ? m[1] : m[2]), a >= 0, z >= a, z <= 65_535 else { throw line.error("字段范围无效。", code: "semantic") }
                start = a; end = z
            }
            guard start > lastEnd, end <= 65_535 else { throw line.error("数据包字段不能重叠或倒序。", code: "semantic") }
            blocks.append((start, end, m[3])); lastEnd = end
        }
        try DiagramSyntax.nonempty(blocks.count, kind: .packet)
        let width: CGFloat = 800, bit: CGFloat = 24, top = b.title(DiagramSyntax.title(lines), width: width)
        let rows = lastEnd / 32 + 1
        guard rows <= 256 else { throw DiagramRenderError(message: "数据包最多显示 256 行。", code: "limit") }
        for row in 0..<rows {
            for index in 0..<32 { b.text(String(row * 32 + index), CGRect(x: 16 + CGFloat(index) * bit, y: top + CGFloat(row) * 74, width: bit, height: 20), size: 9, color: .muted) }
        }
        for (start, end, label) in blocks {
            var cursor = start
            while cursor <= end {
                let row = cursor / 32, tail = min(end, row * 32 + 31), w = CGFloat(tail - cursor + 1) * bit - 2
                let r = CGRect(x: 16 + CGFloat(cursor % 32) * bit, y: top + CGFloat(row) * 74 + 22, width: w, height: 42)
                b.rect(r, id: "packet-\(start)-\(cursor)", label: label)
                let size = min(14, max(8, w / max(1, TextMeasurement.width(label)) * 14))
                if w > 18 { b.text(label, r.insetBy(dx: 3, dy: 4), size: size) }
                cursor = tail + 1
            }
        }
        return b.scene(width: width, height: top + CGFloat(rows) * 74 + 12)
    }

    static func events(_ source: String) throws -> DiagramScene {
        struct Frame { let id: String; let label: String; let kind: String; let reset: Bool; let refs: [String] }
        let lines = DiagramSyntax.lines(source), b = SceneBuilder(.eventmodeling)
        var frames: [Frame] = []
        for line in lines.dropFirst() {
            if line.text.hasPrefix("title ") { continue }
            guard let m = DiagramSyntax.match(#"^(tf|rf)\s+(\w+)\s+(ui|cmd|evt|rmo|pcr)\s+(.+?)(?:\s+->>\s+(.+))?$"#, line.text) else { throw line.error("事件建模当前支持 tf、rf 帧和显式来源引用。") }
            guard !frames.contains(where: { $0.id == m[2] }), !m[4].contains("{") && !m[4].contains("[[") else { throw line.error("帧标识符重复，或使用了尚未支持的数据块。", code: "unsupported-syntax") }
            let refs = m[5].isEmpty ? [] : m[5].components(separatedBy: "->>").map { $0.trimmingCharacters(in: .whitespaces) }
            frames.append(Frame(id: m[2], label: m[4], kind: m[3], reset: m[1] == "rf", refs: refs))
        }
        try DiagramSyntax.nonempty(frames.count, kind: .eventmodeling)
        let lane: (String) -> Int = { $0 == "ui" || $0 == "pcr" ? 0 : $0 == "evt" ? 2 : 1 }
        let width = max(600, CGFloat(frames.count) * 190 + 170), top = b.title(DiagramSyntax.title(lines), width: width)
        for (i, title) in ["UI / Automation", "Command / Read Model", "Events"].enumerated() {
            let y = top + CGFloat(i) * 140
            b.rect(CGRect(x: 12, y: y, width: width - 24, height: 128), fill: .surfaceAlt, stroke: .border, opacity: 0.35)
            b.text(title, CGRect(x: 22, y: y + 4, width: 240, height: 24), size: 13, color: .muted, align: .leading)
        }
        let rects = frames.enumerated().map { index, frame in CGRect(x: 150 + CGFloat(index) * 190, y: top + CGFloat(lane(frame.kind)) * 140 + 38, width: 168, height: 72) }
        let ids = Dictionary(uniqueKeysWithValues: frames.enumerated().map { ($1.id, $0) })
        var connections: [FlowEdge] = []
        for (i, frame) in frames.enumerated() {
            var sources: [Int] = []
            if !frame.refs.isEmpty {
                sources = try frame.refs.map { id in guard let index = ids[id] else { throw DiagramRenderError(message: "帧引用 \(id) 不存在。", code: "semantic") }; return index }
            } else if !frame.reset, let previous = frames[..<i].lastIndex(where: { lane($0.kind) != lane(frame.kind) }) { sources = [previous] }
            for from in sources {
                guard from != i else { throw DiagramRenderError(message: "帧不能引用自身。", code: "semantic") }
                connections.append(FlowEdge(from: frames[from].id, to: frame.id, label: "", style: .solid, arrow: true))
            }
        }
        let nodes = frames.enumerated().map { index, frame in SceneNode(id: frame.id, label: frame.label, shape: .rectangle, frame: rects[index], lines: [frame.label]) }
        let graph = FlowchartModel(direction: .leftRight, nodes: frames.map { FlowNode(id: $0.id, label: $0.label, shape: .rectangle) }, edges: connections)
        let routed = try CompoundEdgeRouter.route(graph, scene: DiagramScene(size: CGSize(width: width, height: top + 438), nodes: nodes, edges: []), separateConnections: true)
        // 泳道背景保持固定，连线与节点还原至原始时间坐标。
        let dx = rects[0].minX - routed.nodes[0].frame.minX, dy = rects[0].minY - routed.nodes[0].frame.minY
        for (index, edge) in routed.edges.enumerated() {
            b.line(edge.points.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }, arrow: edge.arrow, id: "event-edge-\(index)")
        }
        for (i, frame) in frames.enumerated() {
            let color = ["ui": -1, "cmd": 0, "evt": 1, "rmo": 2, "pcr": 6][frame.kind]!
            b.rect(rects[i], fill: color < 0 ? .surface : .series(color), opacity: color < 0 ? 1 : 0.22, id: frame.id, label: frame.label)
            b.text(frame.label, rects[i].insetBy(dx: 8, dy: 8), size: 14)
            b.text(frame.id, CGRect(x: rects[i].minX, y: rects[i].maxY + 2, width: rects[i].width, height: 18), size: 10, color: .muted)
        }
        return b.scene(width: width, height: top + 438)
    }
}
