import Foundation

/// Children are measured first. Each group then participates in its parent's layered layout
/// as one rectangle; an independent routing pass connects the actual descendant endpoints.
enum CompoundLayoutEngine {
    static func layout(_ graph: FlowchartModel, options: DiagramLayoutOptions = .init()) throws -> DiagramScene {
        // Edge declaration order must not decide who occupies a port, lane or label slot first.
        let sequences = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0.sequence) } + graph.groups.map { ($0.id, $0.sequence) })
        let order = graph.edges.indices.sorted { a, b in
            let first = graph.edges[a], second = graph.edges[b]
            for (lhs, rhs) in [(first.from, second.from), (first.to, second.to)] {
                if sequences[lhs] != sequences[rhs] { return sequences[lhs]! < sequences[rhs]! }
                if lhs != rhs { return lhs < rhs }
            }
            if first.label != second.label { return first.label < second.label }
            if first.style != second.style { return first.style.rawValue < second.style.rawValue }
            if first.sourceSide != second.sourceSide { return (first.sourceSide ?? -1) < (second.sourceSide ?? -1) }
            if first.targetSide != second.targetSide { return (first.targetSide ?? -1) < (second.targetSide ?? -1) }
            if first.minimumRankSpan != second.minimumRankSpan { return first.minimumRankSpan < second.minimumRankSpan }
            if first.arrow != second.arrow { return !first.arrow }
            if first.startMarker != second.startMarker { return first.startMarker.rawValue < second.startMarker.rawValue }
            if first.endMarker != second.endMarker { return (first.endMarker?.rawValue ?? "") < (second.endMarker?.rawValue ?? "") }
            return a < b
        }
        let ordered = FlowchartModel(direction: graph.direction, nodes: graph.nodes, edges: order.map { graph.edges[$0] }, groups: graph.groups)
        let placed = try place(ordered, options: options)
        var edges = placed.edges
        for (index, original) in order.enumerated() { edges[original] = placed.edges[index] }
        return DiagramScene(size: placed.size, nodes: placed.nodes, edges: edges, groups: placed.groups)
    }

    private static func place(_ graph: FlowchartModel, options: DiagramLayoutOptions) throws -> DiagramScene {
        let groupByID = Dictionary(uniqueKeysWithValues: graph.groups.map { ($0.id, $0) })
        let nodeByID = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0) })
        let parent: (String) -> String? = { id in
            if let group = groupByID[id] { return group.parentID }
            return nodeByID[id]?.parentID
        }
        let childIn: (String, String?) -> String? = { endpoint, container in
            guard endpoint != container else { return nil }
            var id = endpoint
            while parent(id) != container {
                guard let next = parent(id) else { return nil }
                id = next
            }
            return id
        }

        func build(_ container: String?, inheritedDirection: FlowDirection, depth: Int, groupPadding: CGFloat) throws -> DiagramScene {
            let group = container.flatMap { groupByID[$0] }
            let direction = group?.direction ?? inheritedDirection
            let childGroups = graph.groups.filter { $0.parentID == container }
            var subtrees: [String: DiagramScene] = [:]
            for child in childGroups { subtrees[child.id] = try build(child.id, inheritedDirection: direction, depth: depth + 1, groupPadding: groupPadding) }
            var items = graph.nodes.filter { $0.parentID == container }
            for child in childGroups { items.append(FlowNode(id: child.id, label: child.label, shape: .rectangle, sequence: child.sequence)) }
            items.sort { $0.sequence < $1.sequence }
            var edges: [FlowEdge] = []
            var pairs = Set<[String]>()
            var connectionCounts: [[String]: Int] = [:]
            for edge in graph.edges {
                if let from = childIn(edge.from, container), let to = childIn(edge.to, container), from != to {
                    connectionCounts[[from, to], default: 0] += 1
                }
            }
            for edge in graph.edges {
                guard let from = childIn(edge.from, container), let to = childIn(edge.to, container), from != to,
                      pairs.insert([from, to]).inserted else { continue }
                edges.append(FlowEdge(from: from, to: to, label: edge.label, style: edge.style, arrow: edge.arrow, minimumRankSpan: edge.minimumRankSpan))
            }
            // Preserve self loops in the sizing pass, so their corridor fits inside the group.
            for edge in graph.edges where edge.from == edge.to && items.contains(where: { $0.id == edge.from }) {
                edges.append(edge)
            }
            let sizes = subtrees.mapValues(\.size)
            let lanes = max(0, (connectionCounts.values.max() ?? 0) - 1)
            let channelWidth = 2 * DiagramStyle.groupEdgeClearance + CGFloat(lanes) * DiagramStyle.edgeLaneSeparation
            let flat = try LayeredLayoutEngine.layoutFlat(FlowchartModel(direction: direction, nodes: items, edges: edges), imposedSizes: sizes, padding: 0, rankSeparation: max(DiagramStyle.rankSeparation, channelWidth), options: options)
            let titleLines = group.map { $0.label.isEmpty ? [] : TextMeasurement.lines($0.label, maxWidth: min(400, options.maxWidth.map { max(80, $0 - 80) } ?? 400)) } ?? []
            let titleWidth = titleLines.map { TextMeasurement.width($0) }.max() ?? 0
            let headerHeight = group == nil ? DiagramStyle.scenePadding : titleLines.isEmpty ? groupPadding : CGFloat(titleLines.count) * DiagramStyle.lineHeight + 16
            let reciprocalLabels = edges.filter { edge in
                !edge.label.isEmpty && edges.contains { $0.from == edge.to && $0.to == edge.from }
            }
            let returnRoom = reciprocalLabels.map { EdgeLabelLayout.size(EdgeLabelLayout.lines($0.label)).width / 2 + 44 }.max() ?? 0
            let side = group == nil ? DiagramStyle.scenePadding : max(groupPadding, returnRoom)
            let width = max(flat.size.width + 2 * side, group == nil ? 0 : max(80, titleWidth + 2 * side))
            let height = max(flat.size.height, items.isEmpty ? 32 : 0) + headerHeight + side
            let offset = CGPoint(x: (width - flat.size.width) / 2, y: headerHeight)
            var nodes: [SceneNode] = []
            var groups: [SceneGroup] = []
            if let group {
                groups.append(SceneGroup(id: group.id, label: group.label, parentID: group.parentID,
                                         frame: CGRect(x: 0, y: 0, width: width, height: height),
                                         titleFrame: CGRect(x: (width - titleWidth) / 2, y: 8, width: titleWidth, height: CGFloat(titleLines.count) * DiagramStyle.lineHeight),
                                         titleLines: titleLines, depth: depth - 1))
            }
            for item in flat.nodes {
                if let subtree = subtrees[item.id] {
                    let dx = item.frame.minX + offset.x, dy = item.frame.minY + offset.y
                    nodes += subtree.nodes.map { value in
                        var value = value
                        value.frame = value.frame.offsetBy(dx: dx, dy: dy)
                        return value
                    }
                    groups += subtree.groups.map { value in
                        var value = value
                        value.frame = value.frame.offsetBy(dx: dx, dy: dy)
                        value.titleFrame = value.titleFrame.offsetBy(dx: dx, dy: dy)
                        return value
                    }
                } else {
                    var item = item
                    item.frame = item.frame.offsetBy(dx: offset.x, dy: offset.y)
                    nodes.append(item)
                }
            }
            return DiagramScene(size: CGSize(width: width, height: height), nodes: nodes, edges: [], groups: groups)
        }
        var groupPadding = DiagramStyle.groupPadding
        while true {
            let placed = try build(nil, inheritedDirection: graph.direction, depth: 0, groupPadding: groupPadding)
            do {
                return try CompoundEdgeRouter.route(graph, scene: placed, avoidGroupBorders: true)
            } catch let error as DiagramRenderError where error.code == "layout" && groupPadding < DiagramStyle.groupPadding + 2 * DiagramStyle.groupEdgeClearance {
                // Nested outlines can leave no safe lane. Enlarge the groups before routing again.
                groupPadding += DiagramStyle.groupEdgeClearance
            }
        }
    }
}
