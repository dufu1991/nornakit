import Foundation

struct GraphEntity {
    let id: String
    var title: String
    var members: [String] = []
    var shape: NodeShape = .rectangle
    var parent: String? = nil
    var stereotype: String = ""
    var actor: Bool = false
    var stateMarker: Int = 0
    var synchronization = false
}

struct GraphRelation {
    let from: String
    let to: String
    var label: String = ""
    var start: String = ""
    var end: String = "arrow"
    var dashed: Bool = false
    var fromMultiplicity = ""
    var toMultiplicity = ""
}

struct GraphNote {
    let target: String?
    let text: String
    var side = "right"
}

struct RelationshipModel {
    var kind: DiagramKind
    var direction: FlowDirection = .topDown
    var entities: [GraphEntity] = []
    var relations: [GraphRelation] = []
    var groups: [FlowGroup] = []
    var title = ""
    var notes: [GraphNote] = []
    var regionGroups = Set<String>()

    mutating func register(_ id: String, title: String? = nil, parent: String? = nil) {
        if let i = entities.firstIndex(where: { $0.id == id }) {
            if let title { entities[i].title = title }
            if entities[i].parent == nil { entities[i].parent = parent }
        } else { entities.append(GraphEntity(id: id, title: title ?? id, parent: parent)) }
    }

    func scene(options: DiagramLayoutOptions = .init()) throws -> DiagramScene {
        try DiagramSyntax.nonempty(entities.count + groups.count + notes.count, kind: kind)
        let visibleEntities = entities.filter { entity in !groups.contains(where: { $0.id == entity.id }) }
        let nodes = visibleEntities.enumerated().map { index, entity in
            let label = entity.synchronization ? "" : (entity.actor ? ["", "", entity.title] + entity.members : [entity.stereotype, entity.title].filter { !$0.isEmpty } + entity.members).joined(separator: "\n")
            return FlowNode(id: entity.id, label: label, shape: entity.shape, parentID: entity.parent, sequence: index + groups.count)
        }
        let edges = relations.map { FlowEdge(from: $0.from, to: $0.to, label: $0.label, style: $0.dashed ? .dashed : .solid, arrow: false) }
        let model = FlowchartModel(direction: direction, nodes: nodes, edges: edges, groups: groups)
        var placed = try AdaptiveFlowLayout.layout(model, options: options)
        if kind == .usecase {
            placed = DiagramScene(size: placed.size, nodes: alignedUsecaseActors(in: placed), edges: placed.edges, groups: placed.groups)
        }
        if kind == .usecase || entities.contains(where: \.actor) {
            let original = Dictionary(uniqueKeysWithValues: placed.nodes.map { ($0.id, $0) })
            let actors = Set(entities.filter(\.actor).map(\.id))
            let glyphs = placed.nodes.map { node -> SceneNode in
                var node = node
                if actors.contains(node.id) { node.frame = CGRect(x: node.frame.midX - 18, y: node.frame.minY, width: 36, height: 52) }
                return node
            }
            let captions = placed.nodes.filter { actors.contains($0.id) }.map { CGRect(x: $0.frame.minX - 12, y: $0.frame.minY + 54, width: $0.frame.width + 24, height: max(24, $0.frame.height - 54)) }
            let routed = try CompoundEdgeRouter.route(model, scene: DiagramScene(size: placed.size, nodes: glyphs, edges: [], groups: placed.groups), additionalObstacles: captions, separateConnections: true)
            let restored = routed.nodes.map { node -> SceneNode in
                guard actors.contains(node.id) else { return node }
                var value = original[node.id]!
                value.frame = value.frame.offsetBy(dx: node.frame.midX - value.frame.midX, dy: node.frame.minY - value.frame.minY)
                return value
            }
            placed = DiagramScene(size: routed.size, nodes: restored, edges: routed.edges, groups: routed.groups)
        }
        let builder = SceneBuilder(kind)
        let offset: CGFloat = title.isEmpty ? 0 : 44
        let shift: (CGPoint) -> CGPoint = { CGPoint(x: $0.x, y: $0.y + offset) }
        let barDirections = Dictionary(uniqueKeysWithValues: placed.nodes.map { node -> (String, Bool) in
            let edge = placed.edges.first { $0.from == node.id || $0.to == node.id }
            let point = edge.flatMap { $0.from == node.id ? $0.points.first : $0.points.last }
            return (node.id, point.map { abs($0.x - node.frame.midX) >= node.frame.width / 2 - 1 } ?? direction.horizontal)
        })
        var occupied = placed.nodes.map { $0.frame.offsetBy(dx: 0, dy: offset).insetBy(dx: -3, dy: -3) }
            + placed.groups.map { $0.titleFrame.offsetBy(dx: 0, dy: offset).insetBy(dx: -3, dy: -3) }
            + placed.edges.filter { !$0.label.isEmpty }.map { $0.labelFrame.offsetBy(dx: 0, dy: offset).insetBy(dx: -3, dy: -3) }
        for group in placed.groups {
            let r = group.frame.offsetBy(dx: 0, dy: offset)
            let region = regionGroups.contains(group.id)
            builder.rect(r, fill: region ? .none : .surfaceAlt, opacity: region ? 1 : 0.5, dash: region ? [5, 5] : [])
            builder.text(group.titleLines.joined(separator: "\n"), group.titleFrame.offsetBy(dx: 0, dy: offset), color: .muted)
        }
        for (index, edge) in placed.edges.enumerated() {
            let relation = relations[index]
            var points = edge.points.map(shift)
            for (id, atStart) in [(relation.from, true), (relation.to, false)] {
                if let entity = entities.first(where: { $0.id == id }), entity.stateMarker > 0 || entity.synchronization,
                   let node = placed.nodes.first(where: { $0.id == id }), points.count >= 2 {
                    let center = CGPoint(x: node.frame.midX, y: node.frame.midY + offset)
                    let i = atStart ? 0 : points.count - 1, other = points[atStart ? 1 : points.count - 2]
                    let length = max(0.001, hypot(other.x - center.x, other.y - center.y))
                    if entity.synchronization {
                        let bar = synchronizationFrame(node.frame.offsetBy(dx: 0, dy: offset), horizontal: barDirections[node.id]!)
                        let scale = min(abs(other.x - center.x) > 0.001 ? bar.width / 2 / abs(other.x - center.x) : .infinity,
                                        abs(other.y - center.y) > 0.001 ? bar.height / 2 / abs(other.y - center.y) : .infinity)
                        points[i] = CGPoint(x: center.x + (other.x - center.x) * scale, y: center.y + (other.y - center.y) * scale)
                    } else { points[i] = CGPoint(x: center.x + (other.x - center.x) / length * 9, y: center.y + (other.y - center.y) / length * 9) }
                }
            }
            builder.line(points, dash: relation.dashed ? [4, 4] : [], id: "relation-\(index)")
            marker(relation.end, points: points, builder: builder)
            marker(relation.start, points: points.reversed(), builder: builder)
            for (text, route, suffix) in [(relation.fromMultiplicity, points, "from"), (relation.toMultiplicity, Array(points.reversed()), "to")] where !text.isEmpty {
                let frame = multiplicityFrame(text, points: route, occupied: occupied)
                occupied.append(frame.insetBy(dx: -3, dy: -3))
                builder.rect(frame, fill: .background, stroke: .none, radius: 3, id: "multiplicity-\(index)-\(suffix)", label: text)
                builder.text(text, frame, size: 11)
            }
            if !edge.label.isEmpty {
                let r = edge.labelFrame.offsetBy(dx: 0, dy: offset)
                builder.rect(r, fill: .background, stroke: .none, radius: 3, id: "edge-label-relation-\(index)")
                builder.text(edge.label, r, size: DiagramStyle.edgeFontSize)
            }
        }
        for node in placed.nodes {
            let entity = entities.first { $0.id == node.id }!, r = node.frame.offsetBy(dx: 0, dy: offset)
            if entity.synchronization {
                builder.rect(synchronizationFrame(r, horizontal: barDirections[node.id]!), fill: .foreground, stroke: .none, radius: 2, id: entity.id, label: entity.stereotype)
            } else if entity.stateMarker != 0 {
                let circle = CGRect(x: r.midX - 9, y: r.midY - 9, width: 18, height: 18)
                builder.ellipse(circle, fill: entity.stateMarker == 1 ? .foreground : .background, stroke: .foreground, id: entity.id, label: entity.title)
                if entity.stateMarker == 2 { builder.ellipse(circle.insetBy(dx: 4, dy: 4), fill: .foreground, stroke: .none) }
            } else if entity.actor {
                let x = r.midX, y = r.minY
                builder.ellipse(CGRect(x: x - 8, y: y, width: 16, height: 16), fill: .none, stroke: .foreground)
                builder.line([CGPoint(x: x, y: y + 16), CGPoint(x: x, y: y + 38)])
                builder.line([CGPoint(x: x - 16, y: y + 24), CGPoint(x: x + 16, y: y + 24)])
                builder.line([CGPoint(x: x - 12, y: y + 52), CGPoint(x: x, y: y + 38), CGPoint(x: x + 12, y: y + 52)])
                builder.text(([entity.title] + entity.members).joined(separator: "\n"), CGRect(x: r.minX - 12, y: y + 54, width: r.width + 24, height: max(24, r.height - 54)), size: 14)
            } else if kind == .classDiagram || kind == .er || kind == .requirement || kind == .c4 {
                builder.rect(r, id: entity.id, label: entity.title)
                let heading = [entity.stereotype, entity.title].filter { !$0.isEmpty }.joined(separator: "\n")
                let headerHeight: CGFloat = entity.stereotype.isEmpty ? 34 : 54
                builder.text(heading, CGRect(x: r.minX + 6, y: r.minY + 4, width: r.width - 12, height: min(headerHeight, r.height - 8)), size: 15, bold: true)
                if !entity.members.isEmpty {
                    let separator = r.minY + headerHeight + 4
                    builder.line([CGPoint(x: r.minX, y: separator), CGPoint(x: r.maxX, y: separator)], color: .border)
                    let sections = kind == .classDiagram ? [entity.members.filter { !$0.contains("(") }, entity.members.filter { $0.contains("(") }].filter { !$0.isEmpty } : [entity.members]
                    var bodyY = separator + 4
                    for (index, section) in sections.enumerated() {
                        let lines = section.flatMap { TextMeasurement.lines($0, maxWidth: r.width - 20) }
                        let h = min(CGFloat(lines.count) * 20, max(20, r.maxY - bodyY - 4))
                        builder.text(lines.joined(separator: "\n"), CGRect(x: r.minX + 10, y: bodyY, width: r.width - 20, height: h), size: 14, align: .leading, mono: kind == .er)
                        bodyY += h + 4
                        if index < sections.count - 1 { builder.line([CGPoint(x: r.minX, y: bodyY), CGPoint(x: r.maxX, y: bodyY)], color: .border); bodyY += 4 }
                    }
                }
            } else if entity.shape == .circle || entity.shape == .ellipse {
                builder.ellipse(r, id: entity.id, label: entity.title); builder.text(entity.title, r.insetBy(dx: 8, dy: 6))
            } else if entity.shape == .diamond {
                var copy = node; copy.frame = r
                builder.path(ScenePath.node(copy).commands, fill: .surface, stroke: .border, id: entity.id)
                builder.text(entity.title, r.insetBy(dx: 12, dy: 12))
            } else { builder.box(entity.title, r, radius: kind == .state ? 10 : DiagramStyle.cornerRadius, id: entity.id) }
        }
        var noteBottom: [String: CGFloat] = [:]
        for (index, note) in notes.enumerated() {
            let lines = TextMeasurement.lines(note.text, maxWidth: options.compact ? 160 : 220)
            let w = max(120, (lines.map { TextMeasurement.width($0) }.max() ?? 0) + 24), h = CGFloat(lines.count) * 22 + 24
            let target = placed.nodes.first { $0.id == note.target }?.frame.offsetBy(dx: 0, dy: offset)
                ?? placed.groups.first { $0.id == note.target }?.frame.offsetBy(dx: 0, dy: offset)
            let y = max(8, max((target?.midY ?? 8) - h / 2, noteBottom[note.side] ?? 8))
            let x = note.side == "left" ? -w - 24 : placed.size.width + 24
            let r = CGRect(x: x, y: y, width: w, height: h)
            if let target {
                let start = CGPoint(x: note.side == "left" ? r.maxX : r.minX, y: r.midY)
                let end = CGPoint(x: note.side == "left" ? target.minX : target.maxX, y: target.midY)
                builder.line([start, end], color: .border, dash: [3, 4])
            }
            builder.rect(r, fill: .surfaceAlt, id: "note-\(index)", label: note.text)
            builder.text(lines.joined(separator: "\n"), r.insetBy(dx: 12, dy: 12), size: 14, align: .leading)
            noteBottom[note.side] = r.maxY + 16
        }
        if !title.isEmpty { builder.text(title, CGRect(x: 8, y: 4, width: placed.size.width - 16, height: 32), size: 20, bold: true) }
        return builder.scene(width: placed.size.width, height: placed.size.height + offset)
    }

    private func alignedUsecaseActors(in scene: DiagramScene) -> [SceneNode] {
        var nodes = scene.nodes
        let actors = Set(entities.filter(\.actor).map(\.id))
        let footprint: (SceneNode) -> CGRect = { node in
            actors.contains(node.id)
                ? CGRect(x: node.frame.minX - 12, y: node.frame.minY, width: node.frame.width + 24, height: max(78, node.frame.height))
                : node.frame
        }
        for index in nodes.indices where actors.contains(nodes[index].id) {
            let actor = nodes[index]
            let adjacent = Set(relations.compactMap { relation -> String? in
                if relation.from == actor.id { return relation.to }
                if relation.to == actor.id { return relation.from }
                return nil
            })
            let targets = nodes.filter { adjacent.contains($0.id) && !actors.contains($0.id) }
            guard !targets.isEmpty, targets.count == adjacent.count,
                  targets.allSatisfy({ $0.frame.minX > actor.frame.maxX })
                    || targets.allSatisfy({ $0.frame.maxX < actor.frame.minX }) else { continue }
            let centers = targets.map { $0.frame.midY }.sorted()
            let middle = centers.count / 2
            let center = centers.count.isMultiple(of: 2) ? (centers[middle - 1] + centers[middle]) / 2 : centers[middle]
            var aligned = actor
            // 人物图形高 52 点，名称位于下方，应使用图形中心对齐关联用例。
            aligned.frame.origin.y = center - 26
            let bounds = footprint(aligned)
            guard !nodes.indices.contains(where: { $0 != index && footprint(nodes[$0]).insetBy(dx: -8, dy: -8).intersects(bounds) }) else { continue }
            if let parent = entities.first(where: { $0.id == actor.id })?.parent,
               let group = scene.groups.first(where: { $0.id == parent }) {
                guard group.frame.insetBy(dx: 8, dy: 8).contains(bounds), bounds.minY >= group.titleFrame.maxY + 8 else { continue }
            }
            nodes[index] = aligned
        }
        return nodes
    }

    private func synchronizationFrame(_ r: CGRect, horizontal: Bool) -> CGRect {
        horizontal ? CGRect(x: r.midX - 4, y: r.minY, width: 8, height: max(40, r.height))
            : CGRect(x: r.minX, y: r.midY - 4, width: max(48, r.width), height: 8)
    }

    private func multiplicityFrame(_ text: String, points: [CGPoint], occupied: [CGRect]) -> CGRect {
        let size = CGSize(width: TextMeasurement.width(text, size: 11) + 4, height: 16)
        var candidates: [CGRect] = []
        var traversed: CGFloat = 0
        for (a, b) in zip(points, points.dropFirst()) {
            let length = hypot(b.x - a.x, b.y - a.y)
            guard length > 0.001 else { continue }
            let dx = (b.x - a.x) / length, dy = (b.y - a.y) / length
            for distance: CGFloat in [18, 28, 40, 54] where distance >= traversed && distance <= traversed + length {
                let base = abs(dx) > abs(dy) ? size.height / 2 + 5 : size.width / 2 + 5
                for normal in [base, base + 16, base + 32, base + 64] {
                    for sign: CGFloat in [1, -1] {
                    let center = CGPoint(x: a.x + dx * (distance - traversed) - dy * normal * sign,
                                         y: a.y + dy * (distance - traversed) + dx * normal * sign)
                    let r = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
                    if !occupied.contains(where: { $0.intersects(r) }) { return r }
                    candidates.append(r)
                    }
                }
            }
            traversed += length
        }
        return candidates.first ?? CGRect(origin: points.first ?? .zero, size: size)
    }

    private func marker(_ symbol: String, points: [CGPoint], builder: SceneBuilder) {
        guard !symbol.isEmpty, points.count >= 2 else { return }
        let tip = points.last!, previous = points[points.count - 2]
        let length = max(0.01, hypot(tip.x - previous.x, tip.y - previous.y))
        let dx = (tip.x - previous.x) / length, dy = (tip.y - previous.y) / length
        let p: (CGFloat, CGFloat) -> CGPoint = { along, across in CGPoint(x: tip.x - dx * along - dy * across, y: tip.y - dy * along + dx * across) }
        switch symbol {
        case "arrow": builder.path(ScenePath.arrow(points).commands, fill: .line, stroke: .none)
        case "triangle": builder.path([.move(tip), .line(p(14, 7)), .line(p(14, -7)), .close], fill: .background, stroke: .line)
        case "diamond", "filledDiamond": builder.path([.move(tip), .line(p(7, 5)), .line(p(14, 0)), .line(p(7, -5)), .close], fill: symbol == "diamond" ? .background : .line, stroke: .line)
        case "interface": let center = p(6, 0); builder.ellipse(CGRect(x: center.x - 6, y: center.y - 6, width: 12, height: 12), fill: .background, stroke: .line)
        default:
            if symbol.contains("many") {
                builder.line([p(0, -6), p(12, 0), p(0, 6)]); builder.line([p(0, 0), p(12, 0)])
            } else { builder.line([p(4, -6), p(4, 6)]) }
            if symbol.contains("optional") { let center = p(18, 0); builder.ellipse(CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8), fill: .background, stroke: .line) }
            else { builder.line([p(14, -6), p(14, 6)]) }
        }
    }
}

enum ClassDiagram {
    static func render(_ source: String, options: DiagramLayoutOptions = .init()) throws -> DiagramScene {
        try parse(source).scene(options: options)
    }

    static func parse(_ source: String) throws -> RelationshipModel {
        var graph = RelationshipModel(kind: .classDiagram)
        let lines = DiagramSyntax.lines(source)
        let identifier = #"(`[^`]+`|[\p{L}\p{N}_~.,]+)"#
        let clean: (String) -> String = { $0.hasPrefix("`") ? String($0.dropFirst().dropLast()) : $0 }
        var current: String?, namespaces: [String] = []
        let member: (String, String, inout RelationshipModel) -> Void = { id, value, graph in
            let index = graph.entities.firstIndex { $0.id == id }!
            if let annotation = DiagramSyntax.match(#"^<<([^<>]+)>>$"#, value) { graph.entities[index].stereotype = "«\(annotation[1])»" }
            else { graph.entities[index].members.append(DiagramSyntax.label(value)) }
        }
        for line in lines.dropFirst() {
            let s = line.text
            if let id = current {
                if s == "}" { current = nil }
                else { member(id, s, &graph) }
                continue
            }
            if s.hasPrefix("title ") { graph.title = DiagramSyntax.label(String(s.dropFirst(6))); continue }
            if let m = DiagramSyntax.match(#"^direction\s+(LR|RL|TD|TB|BT)$"#, s) { graph.direction = FlowDirection(rawValue: m[1] == "TB" ? "TD" : m[1])!; continue }
            if s == "}" { guard !namespaces.isEmpty else { throw line.error("多余的命名空间结束符。", code: "syntax") }; namespaces.removeLast(); continue }
            if let m = DiagramSyntax.match(#"^namespace\s+([\w.]+)(?:\["([^"\n]+)"\])?\s*\{$"#, s) {
                guard !graph.groups.contains(where: { $0.id == m[1] }), namespaces.count < 16 else { throw line.error("命名空间重复或嵌套超过 16 层。", code: "semantic") }
                graph.groups.append(FlowGroup(id: m[1], label: m[2].isEmpty ? m[1] : m[2], parentID: namespaces.last, direction: nil, sequence: graph.groups.count)); namespaces.append(m[1]); continue
            }
            if let m = DiagramSyntax.match(#"^note\s+(?:for\s+"# + identifier + #"\s+)?"([\s\S]*)"$"#, s) {
                let target = m[1].isEmpty ? nil : clean(m[1])
                if let target { graph.register(target, parent: namespaces.last) }
                graph.notes.append(GraphNote(target: target, text: DiagramSyntax.label(m[2]))); continue
            }
            if let m = DiagramSyntax.match(#"^<<([^<>]+)>>\s+"# + identifier + #"$"#, s) {
                let id = clean(m[2]); graph.register(id, parent: namespaces.last); member(id, "<<\(m[1])>>", &graph); continue
            }
            if let m = DiagramSyntax.match(#"^class\s+"# + identifier + #"(?:\["([^"]+)"\])?\s*(?:<<([^<>]+)>>)?\s*(\{)?\s*(.*?)\s*(\})?$"#, s) {
                guard !m[4].isEmpty || m[5].isEmpty && m[6].isEmpty else { throw line.error("类声明包含未识别的内容。", code: "syntax") }
                let id = clean(m[1]); graph.register(id, title: m[2].isEmpty ? nil : m[2], parent: namespaces.last)
                if !m[3].isEmpty { member(id, "<<\(m[3])>>", &graph) }
                if !m[4].isEmpty {
                    if m[6].isEmpty { current = id }
                    for value in m[5].split(separator: ";").map({ $0.trimmingCharacters(in: .whitespaces) }) where !value.isEmpty { member(id, value, &graph) }
                }
            } else if let m = DiagramSyntax.match(#"^"# + identifier + #"\s*(?:"([^"]*)")?\s*(<\||\*|o|<|\(\))?(--|\.\.)(\|>|\*|o|>|\(\))?\s*(?:"([^"]*)"\s*)?"# + identifier + #"(?:\s*:\s*(.*))?$"#, s) {
                let from = clean(m[1]), to = clean(m[7])
                graph.register(from, parent: namespaces.last); graph.register(to, parent: namespaces.last)
                let marker: (String) -> String = { ["<|": "triangle", "|>": "triangle", "*": "filledDiamond", "o": "diamond", "<": "arrow", ">": "arrow", "()": "interface", "": ""][$0]! }
                graph.relations.append(GraphRelation(from: from, to: to, label: DiagramSyntax.label(m[8]), start: marker(m[3]), end: marker(m[5]),
                    dashed: m[4] == "..", fromMultiplicity: m[2], toMultiplicity: m[6]))
            } else if let m = DiagramSyntax.match(#"^"# + identifier + #"\s*:\s*(.+)$"#, s) {
                let id = clean(m[1]); graph.register(id, parent: namespaces.last); member(id, m[2], &graph)
            } else { throw line.error("暂不支持这条类图语法：\(s)") }
        }
        guard current == nil, namespaces.isEmpty else { throw DiagramRenderError(message: "类或命名空间缺少结束花括号。", code: "syntax") }
        return graph
    }
}

enum StateDiagram {
    static func render(_ source: String, options: DiagramLayoutOptions = .init()) throws -> DiagramScene {
        try parse(source).scene(options: options)
    }

    static func parse(_ source: String) throws -> RelationshipModel {
        struct Scope { let id: String; var region: Int? }
        var graph = RelationshipModel(kind: .state), stack: [Scope] = []
        let lines = DiagramSyntax.lines(source)
        let regionID: (String, Int) -> String = { "@region_\($0)_\($1)" }
        var cursor = 1
        while cursor < lines.count {
            let line = lines[cursor]; cursor += 1
            let s = line.text
            let parent = stack.last.map { scope in scope.region.map { regionID(scope.id, $0) } ?? scope.id }
            if s.hasPrefix("title ") { graph.title = DiagramSyntax.label(String(s.dropFirst(6))); continue }
            if let m = DiagramSyntax.match(#"^direction\s+(TD|TB|BT|LR|RL)$"#, s) {
                let direction = FlowDirection(rawValue: m[1] == "TB" ? "TD" : m[1])!
                if let parent { graph.groups[graph.groups.firstIndex { $0.id == parent }!].direction = direction }
                else { graph.direction = direction }
                continue
            }
            if s == "}" { guard !stack.isEmpty else { throw line.error("多余的状态结束符。", code: "syntax") }; stack.removeLast(); continue }
            if s == "--" {
                guard let scope = stack.last else { throw line.error("并发分隔符必须位于复合状态中。", code: "syntax") }
                let groupIndex = graph.groups.firstIndex { $0.id == scope.id }!
                if scope.region == nil {
                    let id = regionID(scope.id, 0)
                    var original = graph.direction, ancestor: String? = scope.id
                    while let value = ancestor {
                        let group = graph.groups.first { $0.id == value }!
                        if let direction = group.direction { original = direction; break }
                        ancestor = group.parentID
                    }
                    graph.groups[groupIndex].direction = original.horizontal ? .topDown : .leftRight
                    for i in graph.entities.indices where graph.entities[i].parent == scope.id { graph.entities[i].parent = id }
                    graph.groups = graph.groups.map { group in
                        FlowGroup(id: group.id, label: group.label, parentID: group.parentID == scope.id ? id : group.parentID, direction: group.direction, sequence: group.sequence)
                    }
                    graph.groups.append(FlowGroup(id: id, label: "", parentID: scope.id, direction: original, sequence: graph.groups.count))
                    graph.regionGroups.insert(id)
                }
                let number = (scope.region ?? 0) + 1, id = regionID(scope.id, number)
                let inherited = graph.groups.first { $0.id == regionID(scope.id, 0) }!.direction
                graph.groups.append(FlowGroup(id: id, label: "", parentID: scope.id, direction: inherited, sequence: graph.groups.count))
                graph.regionGroups.insert(id); stack[stack.count - 1].region = number
                guard number < 16 else { throw line.error("一个复合状态最多支持 16 个并发区域。", code: "limit") }
                continue
            }
            if let m = DiagramSyntax.match(#"^state\s+(?:"([^"\n]+)"\s+as\s+)?(\w+)\s*\{$"#, s) {
                guard !graph.groups.contains(where: { $0.id == m[2] }), stack.count < 16 else { throw line.error("复合状态重复或嵌套超过 16 层。", code: "semantic") }
                graph.groups.append(FlowGroup(id: m[2], label: m[1].isEmpty ? m[2] : m[1], parentID: parent, direction: nil, sequence: graph.groups.count)); stack.append(Scope(id: m[2])); continue
            }
            if let m = DiagramSyntax.match(#"^(?i:note)\s+(left|right)\s+of\s+(\w+)(?:\s*:\s*(.*))?$"#, s) {
                var text = m[3]
                if !s.contains(":") {
                    var body: [String] = []
                    while cursor < lines.count, lines[cursor].text.lowercased() != "end note" { body.append(lines[cursor].text); cursor += 1 }
                    guard cursor < lines.count else { throw line.error("状态注释缺少 end note。", code: "syntax") }
                    cursor += 1; text = body.joined(separator: "\n")
                }
                if !graph.groups.contains(where: { $0.id == m[2] }) { graph.register(m[2], parent: parent) }
                graph.notes.append(GraphNote(target: m[2], text: DiagramSyntax.label(text), side: m[1])); continue
            }
            if let m = DiagramSyntax.match(#"^state\s+"([^"]+)"\s+as\s+(\w+)$"#, s) { graph.register(m[2], title: m[1], parent: parent); continue }
            if let m = DiagramSyntax.match(#"^state\s+(\w+)(?:\s+<<(choice|fork|join)>>)?$"#, s) {
                graph.register(m[1], parent: parent)
                let index = graph.entities.firstIndex { $0.id == m[1] }!
                if m[2] == "choice" { graph.entities[index].shape = .diamond }
                else if !m[2].isEmpty { graph.entities[index].synchronization = true; graph.entities[index].stereotype = m[2] }
                continue
            }
            if let m = DiagramSyntax.match(#"^(\[\*\]|\w+)\s*-->\s*(\[\*\]|\w+)(?:\s*:\s*(.*))?$"#, s) {
                let scope = stack.last.map { "\($0.id)_\($0.region ?? 0)" } ?? "root"
                let a = m[1] == "[*]" ? "@initial_\(scope)" : m[1]
                let b = m[2] == "[*]" ? "@final_\(scope)" : m[2]
                for (id, marker) in [(a, m[1] == "[*]" ? 1 : 0), (b, m[2] == "[*]" ? 2 : 0)] {
                    if !graph.groups.contains(where: { $0.id == id }) {
                        graph.register(id, parent: parent)
                        if marker > 0 { let i = graph.entities.firstIndex { $0.id == id }!; graph.entities[i].shape = .circle; graph.entities[i].title = ""; graph.entities[i].stateMarker = marker }
                    }
                }
                graph.relations.append(GraphRelation(from: a, to: b, label: DiagramSyntax.label(m[3]))); continue
            }
            if let m = DiagramSyntax.match(#"^(\w+)\s*:\s*(.+)$"#, s) {
                graph.register(m[1], parent: parent)
                let index = graph.entities.firstIndex { $0.id == m[1] }!, text = DiagramSyntax.label(m[2])
                graph.entities[index].title = graph.entities[index].title == m[1] ? text : graph.entities[index].title + "\n" + text
                continue
            }
            if DiagramSyntax.match(#"^\w+$"#, s) != nil { graph.register(s, parent: parent); continue }
            throw line.error("暂不支持这条状态图语法：\(s)")
        }
        guard stack.isEmpty else { throw DiagramRenderError(message: "复合状态缺少结束花括号。", code: "syntax") }
        return graph
    }
}

enum ERDiagram {
    static func render(_ source: String, options: DiagramLayoutOptions = .init()) throws -> DiagramScene {
        var graph = RelationshipModel(kind: .er), current: String?
        let cardinality: (String) -> String = { value in
            (value.contains("o") ? "optional" : "required") + (value.contains("{") || value.contains("}") ? "many" : "one")
        }
        for line in DiagramSyntax.lines(source).dropFirst() {
            let s = line.text
            if let id = current {
                if s == "}" { current = nil }
                else {
                    guard DiagramSyntax.match(#"^\S+\s+\S+"#, s) != nil else { throw line.error("实体属性需要类型与名称。", code: "syntax") }
                    graph.entities[graph.entities.firstIndex { $0.id == id }!].members.append(s)
                }
            } else if let m = DiagramSyntax.match(#"^(\w+)\s*([|o}{]{2})(--|\.\.)([|o}{]{2})\s*(\w+)\s*:\s*(.+)$"#, s) {
                guard ["||", "o|", "}|", "}o"].contains(m[2]), ["||", "|o", "|{", "o{"].contains(m[4]) else { throw line.error("实体关系基数标记无效。", code: "syntax") }
                graph.register(m[1]); graph.register(m[5]); graph.relations.append(GraphRelation(from: m[1], to: m[5], label: DiagramSyntax.label(m[6]), start: cardinality(m[2]), end: cardinality(m[4]), dashed: m[3] == ".."))
            } else if let m = DiagramSyntax.match(#"^(\w+)(?:\[([^\]]+)\])?\s*\{$"#, s) { graph.register(m[1], title: m[2].isEmpty ? nil : DiagramSyntax.label(m[2])); current = m[1]
            } else if let m = DiagramSyntax.match(#"^direction\s+(LR|RL|TB|TD|BT)$"#, s) { graph.direction = FlowDirection(rawValue: m[1] == "TB" ? "TD" : m[1])!
            } else { throw line.error("暂不支持这条实体关系图语法：\(s)") }
        }
        guard current == nil else { throw DiagramRenderError(message: "实体属性块缺少结束花括号。", code: "syntax") }
        return try graph.scene(options: options)
    }
}
