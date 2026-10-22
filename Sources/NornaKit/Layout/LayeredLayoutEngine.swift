import Foundation

public enum LayeredLayoutEngine {
    public static func layout(_ graph: FlowchartModel, options: DiagramLayoutOptions = .init()) throws -> DiagramScene {
        if !graph.groups.isEmpty { return try CompoundLayoutEngine.layout(graph, options: options) }
        return try layoutFlat(graph, options: options)
    }

    static func layoutFlat(_ graph: FlowchartModel, imposedSizes: [String: CGSize] = [:], padding: CGFloat = DiagramStyle.scenePadding, options: DiagramLayoutOptions = .init()) throws -> DiagramScene {
        guard graph.edges.allSatisfy({ (1...10).contains($0.minimumRankSpan) }) else {
            throw DiagramRenderError(message: "连线跨度必须介于 1 到 10 层之间。", code: "limit")
        }
        guard !graph.nodes.isEmpty else { return DiagramScene(size: .zero, nodes: [], edges: []) }
        let horizontal = graph.direction.horizontal
        let lines = graph.nodes.map { TextMeasurement.lines($0.label, maxWidth: options.labelWidth) }
        let measured = zip(graph.nodes, lines).map { imposedSizes[$0.id] ?? TextMeasurement.nodeSize(lines: $1, shape: $0.shape) }
        var sizes = measured.map { horizontal ? CGSize(width: $0.height, height: $0.width) : $0 }
        let lookup = Dictionary(uniqueKeysWithValues: graph.nodes.enumerated().map { ($1.id, $0) })
        let n = graph.nodes.count
        var outgoing = Array(repeating: [Int](), count: n)
        for (index, edge) in graph.edges.enumerated() { outgoing[lookup[edge.from]!].append(index) }
        var state = Array(repeating: 0, count: n)
        var feedback = Set<Int>()
        func visit(_ node: Int) {
            state[node] = 1
            for index in outgoing[node] {
                let next = lookup[graph.edges[index].to]!
                if state[next] == 1 { feedback.insert(index) }
                else if state[next] == 0 { visit(next) }
            }
            state[node] = 2
        }
        for index in 0..<n where state[index] == 0 { visit(index) }
        var indegree = Array(repeating: 0, count: n)
        for (index, edge) in graph.edges.enumerated() where !feedback.contains(index) { indegree[lookup[edge.to]!] += 1 }
        var queue = (0..<n).filter { indegree[$0] == 0 }
        var ranks = Array(repeating: 0, count: n)
        var cursor = 0
        while cursor < queue.count {
            let node = queue[cursor]
            cursor += 1
            for index in outgoing[node] where !feedback.contains(index) {
                let next = lookup[graph.edges[index].to]!
                ranks[next] = max(ranks[next], ranks[node] + graph.edges[index].minimumRankSpan)
                indegree[next] -= 1
                if indegree[next] == 0 { queue.append(next) }
            }
        }
        var chains: [[Int]] = []
        for (index, edge) in graph.edges.enumerated() {
            let from = lookup[edge.from]!, to = lookup[edge.to]!
            var chain = [from]
            if !feedback.contains(index), ranks[to] > ranks[from] + 1 {
                for rank in (ranks[from] + 1)..<ranks[to] {
                    guard sizes.count < 5_000 else {
                        throw DiagramRenderError(message: "图表的跨层连线过于复杂，请减少节点或连线。", code: "limit")
                    }
                    chain.append(sizes.count)
                    sizes.append(CGSize(width: 36, height: 0))
                    ranks.append(rank)
                }
            }
            chain.append(to)
            chains.append(chain)
        }
        // Virtual vertices reserve corridors for edges that span several layers.
        var layers = Array(repeating: [Int](), count: (ranks.max() ?? 0) + 1)
        for index in ranks.indices { layers[ranks[index]].append(index) }
        var previous = Array(repeating: [Int](), count: sizes.count)
        var next = previous
        for (index, chain) in chains.enumerated() where !feedback.contains(index) {
            for (a, b) in zip(chain, chain.dropFirst()) { next[a].append(b); previous[b].append(a) }
        }
        for sweep in 0..<8 {
            let order = sweep.isMultiple(of: 2) ? Array(layers.indices.dropFirst()) : Array(layers.indices.dropLast().reversed())
            for layer in order {
                var positions: [Int: Double] = [:]
                for row in layers {
                    for (position, node) in row.enumerated() { positions[node] = Double(position) }
                }
                let neighbours = sweep.isMultiple(of: 2) ? previous : next
                let score: (Int) -> Double = { node in
                    let adjacent = neighbours[node]
                    return adjacent.isEmpty ? positions[node]! : adjacent.map { positions[$0]! }.reduce(0, +) / Double(adjacent.count)
                }
                layers[layer].sort {
                    let a = score($0), b = score($1)
                    return a == b ? positions[$0]! < positions[$1]! : a < b
                }
            }
        }
        let gap = options.compact ? 28 : DiagramStyle.nodeSeparation
        let layerWidths = layers.map { row in row.reduce(CGFloat(0)) { $0 + sizes[$1].width } + CGFloat(max(0, row.count - 1)) * gap }
        var totalWidth = layerWidths.max() ?? 0
        var frames = Array(repeating: CGRect.zero, count: sizes.count)
        var y: CGFloat = 0
        for (layer, row) in layers.enumerated() {
            let height = row.map { sizes[$0].height }.max() ?? 0
            var x = (totalWidth - layerWidths[layer]) / 2
            for node in row {
                frames[node] = CGRect(x: x, y: y + (height - sizes[node].height) / 2, width: sizes[node].width, height: sizes[node].height)
                x += sizes[node].width + gap
            }
            let labelRoom = graph.edges.filter { ranks[lookup[$0.from]!] == layer }.map { edge -> CGFloat in
                guard !edge.label.isEmpty else { return 0 }
                let label = EdgeLabelLayout.lines(edge.label)
                return horizontal ? (label.map { TextMeasurement.width($0, size: DiagramStyle.edgeFontSize) }.max() ?? 0) + 64
                    : CGFloat(label.count) * DiagramStyle.edgeLineHeight + 64
            }.max() ?? 0
            y += height + max(DiagramStyle.rankSeparation, labelRoom)
        }
        // 按完整串行链对齐真实节点及跨层虚拟节点，同时保留各层的节点顺序和间距。
        var chainParents = Array(frames.indices)
        func chainRoot(_ vertex: Int) -> Int {
            var root = vertex
            while chainParents[root] != root { root = chainParents[root] }
            var current = vertex
            while chainParents[current] != current {
                let parent = chainParents[current]; chainParents[current] = root; current = parent
            }
            return root
        }
        for vertex in frames.indices where next[vertex].count == 1 {
            let target = next[vertex][0]
            guard previous[target].count == 1,
                  vertex >= n || imposedSizes[graph.nodes[vertex].id] == nil,
                  target >= n || imposedSizes[graph.nodes[target].id] == nil else { continue }
            let a = chainRoot(vertex), b = chainRoot(target)
            chainParents[max(a, b)] = min(a, b)
        }
        let chainMembers = Dictionary(grouping: Array(frames.indices), by: chainRoot)
        for sweep in 0..<4 {
            let roots = sweep.isMultiple(of: 2) ? chainMembers.keys.sorted() : chainMembers.keys.sorted(by: >)
            for root in roots {
                let members = chainMembers[root]!
                guard members.count > 1 else { continue }
                var lower: CGFloat = -.infinity, upper: CGFloat = .infinity
                for vertex in members {
                    let row = layers[ranks[vertex]], position = row.firstIndex(of: vertex)!, half = frames[vertex].width / 2
                    let left = position == 0 ? 0 : frames[row[position - 1]].maxX + gap
                    let right = position == row.count - 1 ? totalWidth : frames[row[position + 1]].minX - gap
                    lower = max(lower, left + half); upper = min(upper, right - half)
                }
                guard lower <= upper + 0.001 else { continue }
                let average = members.map { frames[$0].midX }.reduce(0, +) / CGFloat(members.count)
                let center = max(lower, min(upper, average))
                for vertex in members { frames[vertex].origin.x = center - frames[vertex].width / 2 }
            }
        }
        // 整条链无法放入原画布时扩展列间距，避免只因相邻节点略宽就保留折弯。
        let roots = chainMembers.keys.sorted()
        var constraints: [Int: [Int: CGFloat]] = [:]
        var degrees = Dictionary(uniqueKeysWithValues: roots.map { ($0, 0) })
        for row in layers {
            for (left, right) in zip(row, row.dropFirst()) {
                let a = chainRoot(left), b = chainRoot(right)
                guard a != b else { continue }
                if constraints[a]?[b] == nil { degrees[b, default: 0] += 1 }
                constraints[a, default: [:]][b] = max(constraints[a]?[b] ?? 0, (frames[left].width + frames[right].width) / 2 + gap)
            }
        }
        var order = roots.filter { degrees[$0] == 0 }, head = 0
        while head < order.count {
            let root = order[head]; head += 1
            for target in (constraints[root] ?? [:]).keys.sorted() {
                degrees[target]! -= 1
                if degrees[target] == 0 { order.append(target) }
            }
        }
        if order.count == roots.count {
            var centers = Dictionary(uniqueKeysWithValues: roots.map { root in
                (root, chainMembers[root]!.map { frames[$0].midX }.reduce(0, +) / CGFloat(chainMembers[root]!.count))
            })
            for root in order {
                for (target, distance) in constraints[root] ?? [:] { centers[target] = max(centers[target]!, centers[root]! + distance) }
            }
            for root in roots { for vertex in chainMembers[root]! { frames[vertex].origin.x = centers[root]! - frames[vertex].width / 2 } }
            totalWidth = max(totalWidth, frames.map(\.maxX).max() ?? 0)
        }
        let totalHeight = frames.map(\.maxY).max() ?? 0
        let anchor: (Int, Int, CGFloat) -> CGPoint = { node, side, offset in
            let r = frames[node]
            let shape = imposedSizes[graph.nodes[node].id] == nil ? graph.nodes[node].shape : .rectangle
            if horizontal {
                let realFrame = CGRect(x: r.minY, y: r.minX, width: r.height, height: r.width)
                let point = NodeGeometry.anchor(shape: shape, frame: realFrame, side: [3, 2, 1, 0][side], offset: offset)
                return CGPoint(x: point.y, y: point.x)
            }
            return NodeGeometry.anchor(shape: shape, frame: r, side: side, offset: offset)
        }
        let port: (Int, Int, Bool) -> CGPoint = { node, edgeIndex, leaving in
            let r = frames[node]
            let relevant = graph.edges.indices.filter {
                !feedback.contains($0) && (leaving ? lookup[graph.edges[$0].from] == node : lookup[graph.edges[$0].to] == node)
            }.sorted {
                let a = lookup[leaving ? graph.edges[$0].to : graph.edges[$0].from]!
                let b = lookup[leaving ? graph.edges[$1].to : graph.edges[$1].from]!
                return frames[a].midX == frames[b].midX ? $0 < $1 : frames[a].midX < frames[b].midX
            }
            let position = relevant.firstIndex(of: edgeIndex) ?? 0
            let step = min(16, r.width / 2 / CGFloat(max(1, relevant.count - 1)))
            let dx = (CGFloat(position) - CGFloat(relevant.count - 1) / 2) * step
            return anchor(node, leaving ? 2 : 0, dx)
        }
        // 分支中接近直行的节点对齐其独立端口，避免端口分散后又立即折回。
        for index in graph.edges.indices where !feedback.contains(index) {
            let edge = graph.edges[index], from = lookup[edge.from]!, to = lookup[edge.to]!
            guard outgoing[from].count > 1, previous[to].count == 1, outgoing[to].count == 1,
                  ranks[to] == ranks[from] + 1,
                  imposedSizes[edge.from] == nil, imposedSizes[edge.to] == nil else { continue }
            let dx = port(from, index, true).x - frames[to].midX
            guard abs(dx) > 0.01, abs(dx) <= max(20, gap) else { continue }
            let members = chainMembers[chainRoot(to)]!, memberIDs = Set(members)
            guard members.allSatisfy({ vertex in
                let aligned = frames[vertex].offsetBy(dx: dx, dy: 0)
                return !frames.indices.contains { !memberIDs.contains($0) && frames[$0].insetBy(dx: -8, dy: -8).intersects(aligned) }
            }) else { continue }
            for vertex in members { frames[vertex].origin.x += dx }
        }
        totalWidth = max(totalWidth, frames.map(\.maxX).max() ?? 0)
        let rankStarts = layers.map { row in row.map { frames[$0].minY }.min() ?? 0 }
        let rankEnds = layers.map { row in row.map { frames[$0].maxY }.max() ?? 0 }
        let forwardRoutes = Dictionary(uniqueKeysWithValues: graph.edges.indices.filter { !feedback.contains($0) }.map { index in
            let chain = chains[index]
            var points: [CGPoint] = []
            for (step, pair) in Array(zip(chain, chain.dropFirst())).enumerated() {
                let source = frames[pair.0], target = frames[pair.1]
                let start = pair.0 < n ? port(pair.0, index, true) : CGPoint(x: source.midX, y: source.maxY)
                let end = pair.1 < n ? port(pair.1, index, false) : CGPoint(x: target.midX, y: target.minY)
                let middle = (rankEnds[ranks[pair.0]] + rankStarts[ranks[pair.1]]) / 2
                if step == 0 { points.append(start) }
                if abs(start.x - end.x) < 0.001 { points.append(end) }
                else { points += [CGPoint(x: start.x, y: middle), CGPoint(x: end.x, y: middle), end] }
            }
            return (index, simplify(points))
        })
        var routed: [SceneEdge] = []
        var feedbackRoutes: [[CGPoint]] = []
        var previousLane = totalWidth
        var previousLabelExtent: CGFloat = 0
        for (index, edge) in graph.edges.enumerated() {
            let from = lookup[edge.from]!, to = lookup[edge.to]!
            let a = frames[from], b = frames[to]
            var points: [CGPoint] = []
            if feedback.contains(index) {
                // Feedback and self edges travel outside the node columns.
                let labelSize = EdgeLabelLayout.size(EdgeLabelLayout.lines(edge.label))
                let labelExtent = edge.label.isEmpty ? 0 : (horizontal ? labelSize.height : labelSize.width)
                let lane = previousLane + max(48, (previousLabelExtent + labelExtent) / 2 + 12)
                previousLane = lane
                previousLabelExtent = labelExtent
                let peers = graph.edges.indices.filter { feedback.contains($0) && graph.edges[$0].to == edge.to }
                let spread = (CGFloat(peers.firstIndex(of: index)!) - CGFloat(peers.count - 1) / 2)
                    * min(16, b.height * 0.6 / CGFloat(max(1, peers.count - 1)))
                let end = anchor(to, 1, spread)
                let sideEntry = CGPoint(x: lane, y: end.y)
                let otherNodes = graph.nodes.indices.filter { $0 != to }.map { frames[$0].insetBy(dx: -8, dy: -8) }
                if from == to {
                    let loops = graph.edges.indices.filter { graph.edges[$0].from == edge.from && graph.edges[$0].to == edge.from }
                    points = selfLoop(frame: a, position: loops.firstIndex(of: index)!, count: loops.count,
                        anchor: { side, offset in anchor(from, side, offset) }, obstacles: otherNodes,
                        routes: Array(forwardRoutes.values) + feedbackRoutes)
                } else if EdgeGeometry.clear(sideEntry, end, obstacles: otherNodes) {
                    // Keep return arrows on a separate face from the normal incoming transitions.
                    let start = anchor(from, 2, 0)
                    points = [start, CGPoint(x: start.x, y: a.maxY + 28),
                              CGPoint(x: lane, y: a.maxY + 28), sideEntry, end]
                } else {
                    let start = anchor(from, 2, 0), end = anchor(to, 0, 0)
                    points = [start, CGPoint(x: start.x, y: a.maxY + 28),
                              CGPoint(x: lane, y: a.maxY + 28), CGPoint(x: lane, y: b.minY - 28),
                              CGPoint(x: end.x, y: b.minY - 28), end]
                }
                feedbackRoutes.append(points)
            } else { points = forwardRoutes[index]! }
            points = simplify(points)
            let labelLines = EdgeLabelLayout.lines(edge.label)
            let label = labelLines.joined(separator: "\n")
            let labelSize = EdgeLabelLayout.size(labelLines), labelWidth = labelSize.width, labelHeight = labelSize.height
            let segments = Array(zip(points, points.dropFirst()))
            let segment = segments.max { hypot($0.1.x - $0.0.x, $0.1.y - $0.0.y) < hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }
            let center = segment.map { CGPoint(x: ($0.0.x + $0.1.x) / 2, y: ($0.0.y + $0.1.y) / 2) } ?? .zero
            routed.append(SceneEdge(from: edge.from, to: edge.to, points: points, label: label,
                                    labelFrame: CGRect(x: center.x - labelWidth / 2, y: center.y - labelHeight / 2, width: labelWidth, height: labelHeight),
                                    style: edge.style, arrow: edge.arrow, startMarker: edge.startMarker, endMarker: edge.endMarker))
        }
        let transform: (CGPoint) -> CGPoint = { point in
            switch graph.direction {
            case .topDown: point
            case .bottomUp: CGPoint(x: point.x, y: totalHeight - point.y)
            case .leftRight: CGPoint(x: point.y, y: point.x)
            case .rightLeft: CGPoint(x: totalHeight - point.y, y: point.x)
            }
        }
        let transformFrame: (CGRect) -> CGRect = { frame in
            let p = transform(CGPoint(x: frame.minX, y: frame.minY))
            let q = transform(CGPoint(x: frame.maxX, y: frame.maxY))
            return CGRect(x: min(p.x, q.x), y: min(p.y, q.y), width: abs(q.x - p.x), height: abs(q.y - p.y))
        }
        var nodes = graph.nodes.enumerated().map { index, node in
            SceneNode(id: node.id, label: node.label, shape: node.shape, frame: transformFrame(frames[index]), lines: lines[index], appearance: node.appearance)
        }
        for index in routed.indices {
            routed[index].points = routed[index].points.map(transform)
            let labelCenter = transform(CGPoint(x: routed[index].labelFrame.midX, y: routed[index].labelFrame.midY))
            routed[index].labelFrame.origin = CGPoint(x: labelCenter.x - routed[index].labelFrame.width / 2, y: labelCenter.y - routed[index].labelFrame.height / 2)

        }
        var labelObstacles = nodes.map { $0.frame.insetBy(dx: -4, dy: -4) }
        let paths = routed.filter { $0.style != .invisible }.map(\.points)
        for index in routed.indices where !routed[index].label.isEmpty && routed[index].style != .invisible {
            let r = EdgeLabelLayout.frame(size: routed[index].labelFrame.size, points: routed[index].points, obstacles: labelObstacles, routes: paths)
            routed[index].labelFrame = r
            labelObstacles.append(r.insetBy(dx: -4, dy: -4))
        }
        var bounds = nodes.reduce(CGRect.null) { $0.union($1.frame) }
        for edge in routed {
            for point in edge.points { bounds = bounds.union(CGRect(origin: point, size: CGSize(width: 1, height: 1))) }
            if !edge.label.isEmpty { bounds = bounds.union(edge.labelFrame) }
        }
        let offset = CGPoint(x: padding - bounds.minX, y: padding - bounds.minY)
        for index in nodes.indices { nodes[index].frame = nodes[index].frame.offsetBy(dx: offset.x, dy: offset.y) }
        for index in routed.indices {
            routed[index].points = routed[index].points.map { CGPoint(x: $0.x + offset.x, y: $0.y + offset.y) }
            routed[index].labelFrame = routed[index].labelFrame.offsetBy(dx: offset.x, dy: offset.y)
        }
        return DiagramScene(size: CGSize(width: bounds.width + padding * 2, height: bounds.height + padding * 2), nodes: nodes, edges: routed)
    }

    static func selfLoop(frame: CGRect, position: Int, count: Int, anchor: (Int, CGFloat) -> CGPoint,
                         obstacles: [CGRect], routes: [[CGPoint]], domain: CGRect? = nil) -> [CGPoint] {
        let channels = routes.flatMap { route in
            zip(route, route.dropFirst()).map { a, b in
                CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y)).insetBy(dx: -6, dy: -6)
            }
        }
        var best: [CGPoint] = [], bestScore = CGFloat.infinity
        for side in [3, 1, 2, 0] {
            let vertical = side.isMultiple(of: 2)
            let spread = min(12, (vertical ? frame.width : frame.height) / CGFloat(2 * count + 2)) * CGFloat(position + 1)
            let start = anchor(side, spread), end = anchor(side, -spread)
            for clearance: CGFloat in [28, 44, 64, 88] {
                let distance = clearance + CGFloat(position) * 16
                let lane = side == 3 ? frame.minX - distance : side == 1 ? frame.maxX + distance
                    : side == 0 ? frame.minY - distance : frame.maxY + distance
                let a = vertical ? CGPoint(x: start.x, y: lane) : CGPoint(x: lane, y: start.y)
                let b = vertical ? CGPoint(x: end.x, y: lane) : CGPoint(x: lane, y: end.y)
                let points = [start, a, b, end], segments = Array(zip(points, points.dropFirst()))
                if let domain, !points.allSatisfy(domain.contains) { continue }
                let blocked = segments.filter { !EdgeGeometry.clear($0.0, $0.1, obstacles: obstacles) }.count
                let crowded = segments.reduce(0) { sum, segment in sum + channels.filter { !EdgeGeometry.clear(segment.0, segment.1, obstacles: [$0]) }.count }
                if blocked == 0, crowded == 0 { return points }
                let score = CGFloat(blocked) * 100_000 + CGFloat(crowded) * 10_000 + distance
                if score < bestScore { best = points; bestScore = score }
            }
        }
        return best
    }

    static func simplify(_ points: [CGPoint]) -> [CGPoint] {
        var result: [CGPoint] = []
        for point in points {
            if result.last == point { continue }
            while result.count >= 2 {
                let a = result[result.count - 2], b = result[result.count - 1]
                guard (abs(a.x - b.x) < 0.001 && abs(b.x - point.x) < 0.001)
                    || (abs(a.y - b.y) < 0.001 && abs(b.y - point.y) < 0.001) else { break }
                result.removeLast()
            }
            if result.last != point { result.append(point) }
        }
        return result
    }
}
