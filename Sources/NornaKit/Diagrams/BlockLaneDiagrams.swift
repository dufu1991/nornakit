import Foundation

enum BlockLaneDiagrams {
    static func agent(_ source: String, options: DiagramLayoutOptions = .init()) throws -> DiagramScene {
        let lines = source.components(separatedBy: .newlines)
        guard let first = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty && !$0.trimmingCharacters(in: .whitespaces).hasPrefix("%%") }) else { throw DiagramRenderError(message: "缺少图表声明。", code: "syntax") }
        var copy = lines
        let parts = lines[first].split(whereSeparator: \.isWhitespace)
        copy[first] = "flowchart \(parts.count > 1 ? parts[1] : "TD")"
        var scene = try AdaptiveFlowLayout.layout(MermaidFlowchartParser.parse(copy.joined(separator: "\n")), options: options)
        scene.kind = .agentflow
        return scene
    }

    static func block(_ source: String) throws -> DiagramScene {
        struct Block { let node: FlowNode?; let span: Int }
        let lines = DiagramSyntax.lines(source), b = SceneBuilder(.block)
        var columns: Int?, blocks: [Block] = [], edges: [FlowEdge] = []
        let tokenPattern = #"(?:\w+(?:\[\[.*?\]\]|\[\(.*?\)\]|\(\[.*?\]\)|\(\(.*?\)\)|\[.*?\]|\(.*?\)|\{.*?\})?)(?::\d+)?"#
        let tokenRegex = try! NSRegularExpression(pattern: tokenPattern)
        for line in lines.dropFirst() {
            let s = line.text
            if let m = DiagramSyntax.match(#"^columns\s+(\d+)$"#, s), let value = Int(m[1]), (1...50).contains(value) { columns = value; continue }
            if s.hasPrefix("columns") { throw line.error("列数需要是 1 到 50 的整数。", code: "semantic") }
            if s.contains("-->") || s.contains("---") || s.contains("-.->") {
                let parsed = try MermaidFlowchartParser.parse("flowchart LR\n" + s); edges += parsed.edges
                for node in parsed.nodes where !blocks.contains(where: { $0.node?.id == node.id }) { blocks.append(Block(node: node, span: 1)) }
                continue
            }
            let matches = tokenRegex.matches(in: s, range: NSRange(s.startIndex..., in: s))
            let remainder = tokenRegex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "").trimmingCharacters(in: .whitespaces)
            guard !matches.isEmpty, remainder.isEmpty else { throw line.error("块图暂不支持嵌套块或这条布局指令。") }
            for match in matches {
                var token = String(s[Range(match.range, in: s)!]), span = 1
                if let m = DiagramSyntax.match(#"^(.*):(\d+)$"#, token), let value = Int(m[2]), value > 0, value <= 50 { token = m[1]; span = value }
                if token == "space" { blocks.append(Block(node: nil, span: span)); continue }
                let parsed = try MermaidFlowchartParser.parse("flowchart LR\n" + token), node = parsed.nodes[0]
                guard !blocks.contains(where: { $0.node?.id == node.id }) else { throw line.error("块标识符重复。", code: "semantic") }
                blocks.append(Block(node: node, span: span))
            }
        }
        try DiagramSyntax.nonempty(blocks.count, kind: .block)
        let count = columns ?? blocks.reduce(0) { $0 + $1.span }, columnWidth: CGFloat = 148, gap: CGFloat = 24, rowHeight: CGFloat = 80
        var row = 0, column = 0, placed: [SceneNode] = []
        for block in blocks {
            guard block.span <= count else { throw DiagramRenderError(message: "块跨度超过列数。", code: "semantic") }
            if column + block.span > count { row += 1; column = 0 }
            if let node = block.node {
                let rect = CGRect(x: 16 + CGFloat(column) * (columnWidth + gap), y: 16 + CGFloat(row) * (rowHeight + gap), width: CGFloat(block.span) * columnWidth + CGFloat(block.span - 1) * gap, height: rowHeight)
                placed.append(SceneNode(id: node.id, label: node.label, shape: node.shape, frame: rect, lines: TextMeasurement.lines(node.label, maxWidth: rect.width - 24)))
            }
            column += block.span
        }
        let frames = Dictionary(uniqueKeysWithValues: placed.map { ($0.id, $0.frame) })
        let connections = try edges.map { edge -> FlowEdge in
            guard let a = frames[edge.from], let z = frames[edge.to] else { throw DiagramRenderError(message: "块图连线引用未知节点。", code: "semantic") }
            var edge = edge
            if edge.from != edge.to {
                if a.maxY <= z.minY { edge.sourceSide = 2; edge.targetSide = 0 }
                else if z.maxY <= a.minY { edge.sourceSide = 0; edge.targetSide = 2 }
                else if a.maxX <= z.minX { edge.sourceSide = 1; edge.targetSide = 3 }
                else { edge.sourceSide = 3; edge.targetSide = 1 }
            }
            return edge
        }
        let model = FlowchartModel(direction: .topDown, nodes: blocks.compactMap(\.node), edges: connections)
        let routed = try CompoundEdgeRouter.route(model, scene: DiagramScene(size: CGSize(width: CGFloat(count) * (columnWidth + gap) + 8,
            height: CGFloat(row + 1) * (rowHeight + gap) + 8), nodes: placed, edges: []), separateConnections: true, projectSpanningPorts: true)
        for (index, edge) in routed.edges.enumerated() {
            b.line(edge.points, dash: edge.style == .dashed ? [4, 4] : [], arrow: edge.arrow, id: "block-edge-\(index)")
            if !edge.label.isEmpty {
                b.rect(edge.labelFrame, fill: .background, stroke: .none, radius: 3, id: "edge-label-block-edge-\(index)")
                b.text(edge.label, edge.labelFrame, size: DiagramStyle.edgeFontSize)
            }
        }
        for node in routed.nodes { b.path(ScenePath.node(node).commands, fill: .surface, stroke: .border, id: node.id); b.text(node.lines.joined(separator: "\n"), node.frame.insetBy(dx: 12, dy: 10), size: 14) }
        return b.scene(width: routed.size.width, height: routed.size.height)
    }

    static func swimlane(_ source: String, options: DiagramLayoutOptions = .init()) throws -> DiagramScene {
        var lines = source.components(separatedBy: .newlines)
        guard let first = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("swimlane-beta") }) else { throw DiagramRenderError(message: "缺少泳道声明。", code: "syntax") }
        lines[first] = lines[first].replacingOccurrences(of: "swimlane-beta", with: "flowchart")
        if lines[first].split(whereSeparator: \.isWhitespace).count == 1 { lines[first] += " LR" }
        let model = try MermaidFlowchartParser.parse(lines.joined(separator: "\n"))
        guard !model.groups.isEmpty, model.groups.allSatisfy({ $0.parentID == nil }), model.direction == .leftRight || model.direction == .topDown else { throw DiagramRenderError(message: "泳道图当前支持顶级分组和 LR、TD 方向。", code: "unsupported-syntax") }
        let nodeIDs = Set(model.nodes.map(\.id))
        guard model.edges.allSatisfy({ nodeIDs.contains($0.from) && nodeIDs.contains($0.to) }) else { throw DiagramRenderError(message: "泳道连线当前需要连接具体节点。", code: "unsupported-syntax") }
        if model.direction == .leftRight, options.compact, options.autoDirection {
            let horizontal = try swimlane(source, options: DiagramLayoutOptions(maxWidth: options.maxWidth, autoDirection: false, directionBreakpoint: options.directionBreakpoint))
            if horizontal.size.width > options.maxWidth! {
                lines[first] = "flowchart TD"
                let verticalSource = lines.enumerated().map { $0.offset == first ? "swimlane-beta TD" : $0.element }.joined(separator: "\n")
                let vertical = try swimlane(verticalSource, options: DiagramLayoutOptions(maxWidth: options.maxWidth, autoDirection: false, directionBreakpoint: options.directionBreakpoint))
                return vertical.size.width < horizontal.size.width ? vertical : horizontal
            }
            return horizontal
        }
        let flat = try LayeredLayoutEngine.layoutFlat(FlowchartModel(direction: model.direction, nodes: model.nodes, edges: model.edges), options: options)
        let horizontal = model.direction == .leftRight
        var lanes = model.groups
        if model.nodes.contains(where: { $0.parentID == nil }) { lanes.append(FlowGroup(id: "@unassigned", label: "未分组", parentID: nil, direction: nil, sequence: lanes.count)) }
        let laneWidth: CGFloat = 200, extent = horizontal ? flat.size.width + 174 : flat.size.height + 80
        var sceneNodes: [SceneNode] = [], sceneGroups: [SceneGroup] = []
        var bandOffset: CGFloat = 16
        for lane in lanes {
            let members = model.nodes.filter { ($0.parentID ?? "@unassigned") == lane.id }
            let frames = members.compactMap { node in flat.nodes.first { $0.id == node.id } }
            let columns = Dictionary(grouping: frames) { horizontal ? $0.frame.midX : $0.frame.midY }
            let spacing: CGFloat = options.compact ? 28 : DiagramStyle.nodeSeparation
            let stackSize: ([SceneNode]) -> CGFloat = { column in
                column.reduce(0) { $0 + (horizontal ? $1.frame.height : $1.frame.width) } + CGFloat(max(0, column.count - 1)) * spacing
            }
            let band = max(laneWidth, (columns.values.map(stackSize).max() ?? 0) + 80)
            let rect = horizontal ? CGRect(x: 16, y: bandOffset, width: extent, height: band) : CGRect(x: bandOffset, y: 16, width: band, height: extent)
            let titleRect = horizontal ? CGRect(x: 24, y: bandOffset + 8, width: 126, height: band - 16) : CGRect(x: bandOffset + 8, y: 24, width: band - 16, height: 36)
            sceneGroups.append(SceneGroup(id: lane.id, label: lane.label, parentID: nil, frame: rect, titleFrame: titleRect, titleLines: TextMeasurement.lines(lane.label, maxWidth: 110), depth: 0))
            for key in columns.keys.sorted() {
                let column = columns[key]!.sorted { horizontal ? $0.frame.midY < $1.frame.midY : $0.frame.midX < $1.frame.midX }
                var cross = bandOffset + (band - stackSize(column)) / 2
                for var node in column {
                    if horizontal { node.frame.origin.x += 166; node.frame.origin.y = cross }
                    else { node.frame.origin.x = cross; node.frame.origin.y += 70 }
                    cross += (horizontal ? node.frame.height : node.frame.width) + spacing
                    sceneNodes.append(node)
                }
            }
            bandOffset += band + 12
        }
        let width = horizontal ? extent + 32 : bandOffset + 16, height = horizontal ? bandOffset + 16 : extent + 32
        let members = model.nodes.map { node in
            var node = node
            if node.parentID == nil { node.parentID = "@unassigned" }
            return node
        }
        let parents = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.parentID!) })
        let frames = Dictionary(uniqueKeysWithValues: sceneNodes.map { ($0.id, $0.frame) })
        let connections = model.edges.map { edge in
            var edge = edge
            guard edge.from != edge.to else { return edge }
            let a = frames[edge.from]!, b = frames[edge.to]!
            if parents[edge.from] == parents[edge.to] {
                let forward = horizontal ? b.midX > a.midX : b.midY > a.midY
                edge.sourceSide = forward ? (horizontal ? 1 : 2) : (horizontal ? 2 : 1)
                edge.targetSide = forward ? (horizontal ? 3 : 0) : edge.sourceSide
            } else {
                let positive = horizontal ? b.midY > a.midY : b.midX > a.midX
                edge.sourceSide = horizontal ? (positive ? 2 : 0) : (positive ? 1 : 3)
                edge.targetSide = (edge.sourceSide! + 2) % 4
            }
            return edge
        }
        let routedModel = FlowchartModel(direction: model.direction, nodes: members, edges: connections, groups: lanes)
        let routed = try CompoundEdgeRouter.route(routedModel, scene: DiagramScene(size: CGSize(width: width, height: height), nodes: sceneNodes, edges: [], groups: sceneGroups), allowCrossingGroups: true)
        let b = SceneBuilder(.swimlane)
        for (i, lane) in routed.groups.enumerated() {
            b.rect(lane.frame, fill: .surfaceAlt, opacity: 0.4)
            b.rect(lane.titleFrame, fill: .series(i), stroke: .none, opacity: 0.12)
            b.text(lane.label, lane.titleFrame.insetBy(dx: 6, dy: 6), size: 14, bold: true)
        }
        for (index, edge) in routed.edges.enumerated() {
            b.line(edge.points, dash: edge.style == .dashed ? [4, 4] : [], arrow: edge.arrow, id: "lane-edge-\(index)")
            if !edge.label.isEmpty {
                b.rect(edge.labelFrame, fill: .background, stroke: .none, radius: 3, id: "edge-label-lane-edge-\(index)")
                b.text(edge.label, edge.labelFrame, size: DiagramStyle.edgeFontSize)
            }
        }
        for node in routed.nodes { b.path(ScenePath.node(node).commands, fill: .surface, stroke: .border, id: node.id); b.text(node.lines.joined(separator: "\n"), node.frame.insetBy(dx: 8, dy: 6), size: 16) }
        return b.scene(width: routed.size.width, height: routed.size.height)
    }
}
