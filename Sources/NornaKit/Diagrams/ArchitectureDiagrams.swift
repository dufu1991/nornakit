import Foundation

enum ArchitectureDiagrams {
    static func requirement(_ source: String, options: DiagramLayoutOptions = .init()) throws -> DiagramScene {
        var graph = RelationshipModel(kind: .requirement), current: String?
        for line in DiagramSyntax.lines(source).dropFirst() {
            let s = line.text
            if let id = current {
                if s == "}" { current = nil; continue }
                guard let m = DiagramSyntax.match(#"^(id|text|risk|verifymethod|type|docRef)\s*:\s*(.+)$"#, s) else { throw line.error("暂不支持这条需求属性。") }
                graph.entities[graph.entities.firstIndex { $0.id == id }!].members.append("\(m[1]): \(DiagramSyntax.label(m[2]))")
            } else if let m = DiagramSyntax.match(#"^(requirement|functionalRequirement|performanceRequirement|interfaceRequirement|physicalRequirement|designConstraint|element)\s+(\w+)\s*\{$"#, s) {
                graph.register(m[2]); graph.entities[graph.entities.firstIndex { $0.id == m[2] }!].stereotype = "«\(m[1])»"; current = m[2]
            } else if let m = DiagramSyntax.match(#"^(\w+)\s*-\s*(contains|copies|derives|satisfies|verifies|refines|traces)\s*->\s*(\w+)$"#, s) {
                graph.relations.append(GraphRelation(from: m[1], to: m[3], label: "«\(m[2])»", dashed: m[2] != "contains"))
            } else if let m = DiagramSyntax.match(#"^direction\s+(LR|RL|TB|TD|BT)$"#, s) { graph.direction = FlowDirection(rawValue: m[1] == "TB" ? "TD" : m[1])!
            } else { throw line.error("暂不支持这条需求图语法。") }
        }
        guard current == nil else { throw DiagramRenderError(message: "需求定义缺少结束花括号。", code: "syntax") }
        try validate(graph)
        return try graph.scene(options: options)
    }

    static func c4(_ source: String, options: DiagramLayoutOptions = .init()) throws -> DiagramScene {
        var graph = RelationshipModel(kind: .c4, direction: .leftRight), stack: [String] = []
        for line in DiagramSyntax.lines(source).dropFirst() {
            let s = line.text
            if s.hasPrefix("title ") { graph.title = String(s.dropFirst(6)); continue }
            if s == "}" { guard !stack.isEmpty else { throw line.error("多余的边界结束符。", code: "syntax") }; stack.removeLast(); continue }
            guard let m = DiagramSyntax.match(#"^(\w+)\((.*)\)\s*(\{)?$"#, s) else { throw line.error("C4 图需要宏形式的元素或关系声明。", code: "syntax") }
            let name = m[1], args = DiagramSyntax.split(m[2]).map(DiagramSyntax.label)
            guard args.count >= 2 else { throw line.error("C4 声明至少需要标识符和标签或目标。", code: "syntax") }
            if ["Rel", "BiRel", "Rel_Back"].contains(name) {
                guard args.count >= 3 else { throw line.error("关系缺少标签。", code: "syntax") }
                graph.relations.append(GraphRelation(from: name == "Rel_Back" ? args[1] : args[0], to: name == "Rel_Back" ? args[0] : args[1], label: args[2] + (args.count > 3 ? "\n[\(args[3])]" : ""), start: name == "BiRel" ? "arrow" : ""))
            } else if ["Boundary", "Enterprise_Boundary", "System_Boundary", "Container_Boundary", "Deployment_Node", "Node"].contains(name) {
                guard !m[3].isEmpty, !graph.groups.contains(where: { $0.id == args[0] }), stack.count < 16 else { throw line.error("边界重复、缺少花括号或嵌套过深。", code: "syntax") }
                graph.groups.append(FlowGroup(id: args[0], label: args[1], parentID: stack.last, direction: nil, sequence: graph.groups.count)); stack.append(args[0])
            } else if ["Person", "Person_Ext", "System", "System_Ext", "SystemDb", "SystemDb_Ext", "SystemQueue", "SystemQueue_Ext", "Container", "Container_Ext", "ContainerDb", "ContainerDb_Ext", "ContainerQueue", "Component", "Component_Ext", "ComponentDb"].contains(name) {
                guard !graph.entities.contains(where: { $0.id == args[0] }) else { throw line.error("元素标识符重复。", code: "semantic") }
                graph.register(args[0], title: args[1], parent: stack.last)
                let i = graph.entities.count - 1
                graph.entities[i].actor = name.hasPrefix("Person")
                graph.entities[i].stereotype = "[\(name)]"
                graph.entities[i].members = Array(args.dropFirst(2)).filter { !$0.isEmpty }
            } else { throw line.error("暂不支持 C4 宏 \(name)。") }
        }
        guard stack.isEmpty else { throw DiagramRenderError(message: "C4 边界缺少结束花括号。", code: "syntax") }
        try validate(graph)
        return try graph.scene(options: options)
    }

    static func usecase(_ source: String, options: DiagramLayoutOptions = .init()) throws -> DiagramScene {
        var graph = RelationshipModel(kind: .usecase, direction: .leftRight), stack: [String] = []
        var rectangles = Set<String>()
        for line in DiagramSyntax.lines(source).dropFirst() {
            let s = line.text
            if s == "end" { guard !stack.isEmpty else { throw line.error("end 没有对应的系统边界。", code: "syntax") }; stack.removeLast(); continue }
            if let m = DiagramSyntax.match(#"^direction\s+(LR|RL|TD|TB|BT)$"#, s) { graph.direction = FlowDirection(rawValue: m[1] == "TB" ? "TD" : m[1])!; continue }
            if let m = DiagramSyntax.match(#"^systemBoundary\s+(\w+)(?:\[([^\]]+)\])?$"#, s) {
                guard !graph.groups.contains(where: { $0.id == m[1] }), stack.count < 16 else { throw line.error("边界重复或嵌套过深。", code: "semantic") }
                graph.groups.append(FlowGroup(id: m[1], label: m[2].isEmpty ? m[1] : DiagramSyntax.label(m[2]), parentID: stack.last, direction: nil, sequence: graph.groups.count)); stack.append(m[1]); continue
            }
            if let m = DiagramSyntax.match(#"^actor\s+(\w+)(?:\[([^\]]+)\])?$"#, s) {
                graph.register(m[1], title: m[2].isEmpty ? nil : DiagramSyntax.label(m[2]), parent: stack.last)
                graph.entities[graph.entities.firstIndex { $0.id == m[1] }!].actor = true; continue
            }
            if let m = DiagramSyntax.match(#"^(\w+)\s*(-->|--|\.\.>|<\|--)\s*(\w+)(?:\s*:\s*(.*))?$"#, s) {
                graph.register(m[1], parent: stack.last); graph.register(m[3], parent: stack.last)
                graph.relations.append(GraphRelation(from: m[1], to: m[3], label: m[4], start: m[2] == "<|--" ? "triangle" : "", end: m[2] == "-->" || m[2] == "..>" ? "arrow" : "", dashed: m[2] == "..>")); continue
            }
            if let m = DiagramSyntax.match(#"^(\w+)(?:\((.+)\)|\[(.+)\])?$"#, s) { if !m[3].isEmpty { rectangles.insert(m[1]) }; graph.register(m[1], title: m[2].isEmpty ? (m[3].isEmpty ? nil : DiagramSyntax.label(m[3])) : DiagramSyntax.label(m[2]), parent: stack.last); continue }
            throw line.error("暂不支持这条用例图语法。")
        }
        guard stack.isEmpty else { throw DiagramRenderError(message: "系统边界缺少 end。", code: "syntax") }
        for i in graph.entities.indices where !graph.entities[i].actor && !rectangles.contains(graph.entities[i].id) { graph.entities[i].shape = .ellipse }
        return try graph.scene(options: options)
    }

    private static func validate(_ graph: RelationshipModel) throws {
        let ids = Set(graph.entities.map(\.id) + graph.groups.map(\.id))
        for relation in graph.relations where !ids.contains(relation.from) || !ids.contains(relation.to) {
            throw DiagramRenderError(message: "关系引用了未定义的元素。", code: "semantic")
        }
    }

    static func architecture(_ source: String, options: DiagramLayoutOptions = .init()) throws -> DiagramScene {
        struct Service { let id: String; let title: String; let icon: String; let parent: String?; let junction: Bool }
        var services: [Service] = [], groups: [FlowGroup] = [], edges: [FlowEdge] = []
        let sides = ["T": 0, "R": 1, "B": 2, "L": 3]
        for line in DiagramSyntax.lines(source).dropFirst() {
            let s = line.text
            if let m = DiagramSyntax.match(#"^(group|service|junction)\s+(\w+)(?:\(([^)]+)\))?(?:\[([^\]]*)\])?(?:\s+in\s+(\w+))?$"#, s) {
                if m[1] == "group" { groups.append(FlowGroup(id: m[2], label: m[4].isEmpty ? m[2] : m[4], parentID: m[5].isEmpty ? nil : m[5], direction: nil, sequence: groups.count)) }
                else {
                    guard ["", "server", "database", "disk", "cloud", "internet"].contains(m[3]) else { throw line.error("暂不支持这个架构图图标。") }
                    services.append(Service(id: m[2], title: m[4].isEmpty ? m[2] : m[4], icon: m[3], parent: m[5].isEmpty ? nil : m[5], junction: m[1] == "junction")) }
            } else if let m = DiagramSyntax.match(#"^(\w+):([TRBL])\s*(<)?--(>)?\s*([TRBL]):(\w+)$"#, s) {
                guard m[3].isEmpty else { throw line.error("架构图暂不支持起点箭头。") }
                edges.append(FlowEdge(from: m[1], to: m[6], label: "", style: .solid, arrow: !m[4].isEmpty, sourceSide: sides[m[2]], targetSide: sides[m[5]]))
            } else { throw line.error("暂不支持这条架构图语法。") }
        }
        try DiagramSyntax.nonempty(services.count, kind: .architecture)
        let ids = services.map(\.id), groupIDs = groups.map(\.id)
        guard Set(ids + groupIDs).count == ids.count + groupIDs.count,
              services.allSatisfy({ $0.parent == nil || groupIDs.contains($0.parent!) }),
              edges.allSatisfy({ ids.contains($0.from) && ids.contains($0.to) }) else { throw DiagramRenderError(message: "架构图存在重复标识符或未定义的引用。", code: "semantic") }
        for group in groups {
            var seen = Set([group.id]), parent = group.parentID
            while let id = parent {
                guard seen.insert(id).inserted, let next = groups.first(where: { $0.id == id }) else { throw DiagramRenderError(message: "架构分组存在循环或未知父组。", code: "semantic") }
                parent = next.parentID
            }
        }
        let graph = FlowchartModel(direction: .leftRight, nodes: services.enumerated().map { FlowNode(id: $0.element.id, label: "\n\n\($0.element.title)\n", shape: .rectangle, parentID: $0.element.parent, sequence: $0.offset + groups.count) }, edges: edges, groups: groups)
        let placementEdges = edges.map { var edge = $0; edge.sourceSide = nil; edge.targetSide = nil; return edge }
        let placementGraph = FlowchartModel(direction: graph.direction, nodes: graph.nodes, edges: placementEdges, groups: graph.groups)
        // 显式端口保留其方位，窄画布通过平移浏览，避免横向端口被竖向排布迫使折返。
        var placementOptions = options
        placementOptions.autoDirection = false
        let placed = try AdaptiveFlowLayout.layout(placementGraph, options: placementOptions)
        let routedNodes = alignedServiceNodes(placed, graph: graph)
        let routed = try CompoundEdgeRouter.route(graph, scene: DiagramScene(size: placed.size, nodes: routedNodes, edges: [], groups: placed.groups), separateConnections: true)
        let b = SceneBuilder(.architecture)
        for group in routed.groups { b.rect(group.frame, fill: .surfaceAlt, opacity: 0.4); b.text(group.label, group.titleFrame, size: 16, color: .muted) }
        for (index, edge) in routed.edges.enumerated() { b.line(edge.points, arrow: edge.arrow, id: "architecture-edge-\(index)") }
        for node in routed.nodes {
            let service = services.first { $0.id == node.id }!, r = node.frame
            if service.junction { b.ellipse(r.insetBy(dx: 17, dy: 17), fill: .foreground, stroke: .none, id: node.id); continue }
            b.rect(r, fill: .surface, id: node.id, label: service.title)
            let icon = r.insetBy(dx: 10, dy: 10)
            if service.icon == "database" || service.icon == "disk" {
                let shape = SceneNode(id: node.id, label: "", shape: .cylinder, frame: icon, lines: [])
                b.path(ScenePath.node(shape).commands, fill: .none, stroke: .foreground); b.path(ScenePath.detail(shape).commands, stroke: .foreground)
            } else if service.icon == "cloud" || service.icon == "internet" {
                b.ellipse(icon.insetBy(dx: 0, dy: 6), fill: .none, stroke: .foreground)
                b.line([CGPoint(x: icon.midX, y: icon.minY + 6), CGPoint(x: icon.midX, y: icon.maxY - 6)], color: .foreground)
                b.line([CGPoint(x: icon.minX, y: icon.midY), CGPoint(x: icon.maxX, y: icon.midY)], color: .foreground)
            } else {
                for i in 0..<3 { b.rect(CGRect(x: icon.minX, y: icon.minY + CGFloat(i) * 9, width: icon.width, height: 7), fill: .none, stroke: .foreground, radius: 1) }
            }
            let bottomLinked = edges.contains { ($0.from == node.id && $0.sourceSide == 2) || ($0.to == node.id && $0.targetSide == 2) }
            b.text(service.title, CGRect(x: r.midX - 90, y: bottomLinked ? r.minY - 30 : r.maxY + 6, width: 180, height: 24), size: 14)
        }
        return b.scene(width: routed.size.width, height: routed.size.height + 32)
    }

    private static func alignedServiceNodes(_ scene: DiagramScene, graph: FlowchartModel) -> [SceneNode] {
        let reserved = Dictionary(uniqueKeysWithValues: scene.nodes.map { ($0.id, $0.frame) })
        let model = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0) })
        let groups = Dictionary(uniqueKeysWithValues: graph.groups.map { ($0.id, $0) })
        let lookup = Dictionary(uniqueKeysWithValues: scene.nodes.enumerated().map { ($1.id, $0) })
        let depth: (String) -> Int = { id in
            var parent = model[id]?.parentID, result = 0
            while let current = parent { result += 1; parent = groups[current]?.parentID }
            return result
        }
        let degree: (String) -> Int = { id in graph.edges.filter { $0.from == id || $0.to == id }.count }
        var nodes = scene.nodes.map { node in
            var node = node
            node.frame = CGRect(x: node.frame.midX - 24, y: node.frame.midY - 24, width: 48, height: 48)
            return node
        }
        // Correct small offsets introduced by group headers or wrapped service labels.
        // Every glyph stays inside the space reserved by the layered layout.
        for horizontal in [true, false] {
            var adjacent = Array(repeating: [Int](), count: nodes.count)
            for edge in graph.edges {
                let opposite = horizontal ? [(1, 3), (3, 1)] : [(0, 2), (2, 0)]
                guard opposite.contains(where: { edge.sourceSide == $0.0 && edge.targetSide == $0.1 }),
                      let from = lookup[edge.from], let to = lookup[edge.to], from != to else { continue }
                adjacent[from].append(to); adjacent[to].append(from)
            }
            let center: (Int) -> CGFloat = { horizontal ? nodes[$0].frame.midY : nodes[$0].frame.midX }
            var visited = Set<Int>()
            for seed in nodes.indices where !visited.contains(seed) {
                var members = [seed], low = center(seed), high = low, cursor = 0
                visited.insert(seed)
                while cursor < members.count {
                    let node = members[cursor]; cursor += 1
                    for next in adjacent[node] where !visited.contains(next) {
                        let value = center(next)
                        guard max(high, value) - min(low, value) <= 12 else { continue }
                        low = min(low, value); high = max(high, value)
                        members.append(next); visited.insert(next)
                    }
                }
                guard members.count > 1 else { continue }
                let reference = members.sorted {
                    let a = nodes[$0].id, b = nodes[$1].id
                    if depth(a) != depth(b) { return depth(a) > depth(b) }
                    if degree(a) != degree(b) { return degree(a) > degree(b) }
                    return $0 < $1
                }[0]
                let baseline = center(reference)
                let frames = members.map { index in
                    nodes[index].frame.offsetBy(dx: horizontal ? 0 : baseline - center(index), dy: horizontal ? baseline - center(index) : 0)
                }
                guard zip(members, frames).allSatisfy({ reserved[nodes[$0.0].id]!.contains($0.1) }) else { continue }
                for (index, frame) in zip(members, frames) { nodes[index].frame = frame }
            }
        }
        return nodes
    }
}
