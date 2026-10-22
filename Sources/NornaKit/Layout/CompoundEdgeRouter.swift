import Foundation

/// Routes through a rectilinear visibility grid with rounded orthogonal corners.
/// Unrelated groups, nodes and titles are obstacles; shared edges stay inside their group.
enum CompoundEdgeRouter {
    private struct Port {
        let anchor: CGPoint
        let stub: CGPoint
        let penalty: CGFloat
        var side: Int = 0
    }

    private struct Channel {
        let coordinate: CGFloat
        let horizontal: Bool
        let range: ClosedRange<CGFloat>
    }

    static func route(_ graph: FlowchartModel, scene: DiagramScene, additionalObstacles: [CGRect] = [], separateConnections: Bool = false, allowCrossingGroups: Bool = false, projectSpanningPorts: Bool = false, avoidGroupBorders: Bool = false) throws -> DiagramScene {
        let nodes = Dictionary(uniqueKeysWithValues: scene.nodes.map { ($0.id, $0) })
        let groups = Dictionary(uniqueKeysWithValues: scene.groups.map { ($0.id, $0) })
        let modelGroups = Dictionary(uniqueKeysWithValues: graph.groups.map { ($0.id, $0) })
        let modelNodes = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0) })
        let parent: (String) -> String? = { id in modelGroups[id]?.parentID ?? modelNodes[id]?.parentID }
        let ancestors: (String) -> [String] = { id in
            var result: [String] = []
            var current = parent(id)
            while let value = current { result.append(value); current = parent(value) }
            return result
        }
        let frame: (String) -> CGRect = { id in nodes[id]?.frame ?? groups[id]!.frame }
        let direction: (String) -> FlowDirection = { id in
            var current = parent(id)
            while let value = current {
                if let local = modelGroups[value]?.direction { return local }
                current = parent(value)
            }
            return graph.direction
        }
        let forward: (FlowEdge) -> Bool = { edge in
            let a = frame(edge.from), b = frame(edge.to)
            switch direction(edge.from) {
            case .topDown: return a.maxY < b.minY
            case .bottomUp: return a.minY > b.maxY
            case .leftRight: return a.maxX < b.minX
            case .rightLeft: return a.minX > b.maxX
            }
        }
        // 先为回退线确定侧边端口，避免它参与正常入口的端口分散。
        let routingEdges = graph.edges.map { edge in
            guard edge.from != edge.to, edge.sourceSide == nil, edge.targetSide == nil,
                  parent(edge.from) == parent(edge.to) else { return edge }
            let a = frame(edge.from), b = frame(edge.to)
            let backward: Bool
            switch direction(edge.from) {
            case .topDown: backward = a.minY > b.maxY
            case .bottomUp: backward = a.maxY < b.minY
            case .leftRight: backward = a.minX > b.maxX
            case .rightLeft: backward = a.maxX < b.minX
            }
            guard backward else { return edge }
            var routed = edge
            routed.sourceSide = direction(edge.from).horizontal ? 2 : 1
            routed.targetSide = routed.sourceSide
            return routed
        }
        let tracks = parallelTracks(graph, frame: frame, parent: parent, direction: direction) { index, leaving in
            let edge = graph.edges[index], id = leaving ? edge.from : edge.to
            return ports(frame: frame(id), node: nodes[id], direction: direction(id), leaving: leaving,
                edgeIndex: index, edges: routingEdges, frameForNode: frame, minimumStub: 12,
                projectSpanningPorts: projectSpanningPorts).first { $0.penalty == 0 }!.anchor
        }
        var reservedPorts: [Int: [[CGPoint]]] = [:]
        if avoidGroupBorders {
            for (index, edge) in graph.edges.enumerated() where edge.style != .invisible && edge.from != edge.to && parent(edge.from) == parent(edge.to) && forward(edge) {
                reservedPorts[index] = [true, false].compactMap { leaving in
                    let id = leaving ? edge.from : edge.to
                    return ports(frame: frame(id), node: nodes[id], direction: direction(id), leaving: leaving,
                        edgeIndex: index, edges: routingEdges, frameForNode: frame, minimumStub: 12,
                        projectSpanningPorts: projectSpanningPorts).first { $0.penalty == 0 }.map { [$0.anchor, $0.stub] }
                }
            }
        }
        var routed: [SceneEdge] = []
        var labelDomains: [CGRect] = []
        for (index, edge) in graph.edges.enumerated() {
            let a = frame(edge.from), b = frame(edge.to)
            let sourceAncestors = ancestors(edge.from), targetAncestors = ancestors(edge.to)
            let common = sourceAncestors.first { targetAncestors.contains($0) }
            let sourceContainsTarget = targetAncestors.contains(edge.from)
            let targetContainsSource = sourceAncestors.contains(edge.to)
            let enclosure = sourceContainsTarget ? groups[edge.from] : targetContainsSource ? groups[edge.to] : common.flatMap { groups[$0] }
            let allowedGroups = Set(sourceAncestors + targetAncestors + [edge.from, edge.to])
            let borders = avoidGroupBorders ? scene.groups.filter { $0.id != edge.from && $0.id != edge.to }.map(\.frame) : []
            let inlineLabel = EdgeLabelLayout.size(EdgeLabelLayout.lines(edge.label))
            let horizontalPort = edge.sourceSide.map { !$0.isMultiple(of: 2) } ?? direction(edge.from).horizontal
            let labelClearance = projectSpanningPorts && !edge.label.isEmpty
            let obstacleX = labelClearance && !horizontalPort ? max(8, inlineLabel.width / 2 + 6) : 8
            let obstacleY = labelClearance && horizontalPort ? max(8, inlineLabel.height / 2 + 6) : 8
            let obstacles = scene.nodes.map { $0.frame.insetBy(dx: -obstacleX, dy: -obstacleY) }
                + scene.groups.filter { !allowCrossingGroups && !allowedGroups.contains($0.id) }.map { $0.frame.insetBy(dx: -8, dy: -8) }
                + scene.groups.filter { !$0.titleLines.allSatisfy(\.isEmpty) }.map { $0.titleFrame.insetBy(dx: -4, dy: -3) } + additionalObstacles
            let domain = enclosure.map { $0.frame.insetBy(dx: 3, dy: 3) }
                ?? CGRect(origin: .zero, size: scene.size).insetBy(dx: -40, dy: -40)
            var starts = ports(frame: a, node: nodes[edge.from], direction: direction(edge.from), leaving: true,
                               edgeIndex: index, edges: routingEdges, frameForNode: frame, minimumStub: separateConnections && !projectSpanningPorts ? 24 : 12, projectSpanningPorts: projectSpanningPorts)
            var ends = ports(frame: b, node: nodes[edge.to], direction: direction(edge.to), leaving: false,
                             edgeIndex: index, edges: routingEdges, frameForNode: frame, minimumStub: separateConnections && !projectSpanningPorts ? 24 : 12, projectSpanningPorts: projectSpanningPorts)
            if let side = edge.sourceSide { starts = starts.filter { $0.side == side } }
            if let side = edge.targetSide { ends = ends.filter { $0.side == side } }
            let inward: (Port) -> Port = { port in
                Port(anchor: port.anchor, stub: CGPoint(x: port.anchor.x * 2 - port.stub.x, y: port.anchor.y * 2 - port.stub.y), penalty: port.penalty, side: port.side)
            }
            if sourceContainsTarget { starts = starts.map(inward) }
            if targetContainsSource { ends = ends.map(inward) }
            if edge.from == edge.to {
                let shape = nodes[edge.from]?.shape ?? .rectangle
                starts = [Port(anchor: NodeGeometry.anchor(shape: shape, frame: a, side: 1, offset: -8), stub: CGPoint(x: a.maxX + 26, y: a.midY - 8), penalty: 0)]
                ends = [Port(anchor: NodeGeometry.anchor(shape: shape, frame: a, side: 1, offset: 8), stub: CGPoint(x: a.maxX + 26, y: a.midY + 8), penalty: 0)]
            }
            let otherNodeObstacles = scene.nodes.filter { $0.id != edge.from && $0.id != edge.to }.map { $0.frame.insetBy(dx: -5, dy: -5) }
            let portObstacles = otherNodeObstacles
                + scene.groups.filter { !allowCrossingGroups && !allowedGroups.contains($0.id) }.map(\.frame)
                + scene.groups.map { $0.titleFrame.insetBy(dx: -3, dy: -2) } + additionalObstacles
            // 密集网格中，缩短会撞到相邻卡片的端口引线，再由可见性网格寻找绕行。
            let trim: (Port, CGRect?) -> Port = { port, endpoint in
                let forbidden = portObstacles + (endpoint.map { [$0.insetBy(dx: -8, dy: -8)] } ?? [])
                if domain.contains(port.stub), clear(port.anchor, port.stub, obstacles: forbidden) { return port }
                let dx = port.stub.x - port.anchor.x, dy = port.stub.y - port.anchor.y, length = hypot(dx, dy)
                guard length > 0.01 else { return port }
                for distance: CGFloat in [12, 8] where distance < length {
                    let stub = CGPoint(x: port.anchor.x + dx / length * distance, y: port.anchor.y + dy / length * distance)
                    if domain.contains(stub), clear(port.anchor, stub, obstacles: forbidden) {
                        return Port(anchor: port.anchor, stub: stub, penalty: port.penalty, side: port.side)
                    }
                }
                return port
            }
            starts = starts.map { trim($0, sourceContainsTarget || targetContainsSource || edge.from == edge.to ? nil : b) }
            ends = ends.map { trim($0, sourceContainsTarget || targetContainsSource || edge.from == edge.to ? nil : a) }
            starts = starts.filter { domain.contains($0.stub) && clear($0.anchor, $0.stub, obstacles: portObstacles) && clearOfBorders($0.anchor, $0.stub, borders: borders) }
            ends = ends.filter { domain.contains($0.stub) && clear($0.anchor, $0.stub, obstacles: portObstacles) && clearOfBorders($0.anchor, $0.stub, borders: borders) }
            if parent(edge.from) == parent(edge.to), edge.from != edge.to {
                if forward(edge) {
                    let preferredStarts = starts.filter { $0.penalty == 0 }, preferredEnds = ends.filter { $0.penalty == 0 }
                    if edge.sourceSide == nil, !preferredStarts.isEmpty { starts = preferredStarts }
                    if edge.targetSide == nil, !preferredEnds.isEmpty { ends = preferredEnds }
                } else if edge.sourceSide == nil, edge.targetSide == nil,
                          graph.edges.contains(where: { $0.from == edge.to && $0.to == edge.from }) {
                    let horizontal = direction(edge.from).horizontal, side = horizontal ? 2 : 1
                    let own = EdgeLabelLayout.size(EdgeLabelLayout.lines(edge.label))
                    let other = graph.edges.first { $0.from == edge.to && $0.to == edge.from }!
                    let opposite = EdgeLabelLayout.size(EdgeLabelLayout.lines(other.label))
                    let clearance = max(32, ((horizontal ? own.height : own.width) + (horizontal ? opposite.height : opposite.width)) / 2 + 12 - (horizontal ? min(a.height, b.height) : min(a.width, b.width)) / 2)
                    let lane = horizontal ? max(a.maxY, b.maxY) + clearance : max(a.maxX, b.maxX) + clearance
                    let extend: (Port) -> Port = { port in
                        let stub = horizontal ? CGPoint(x: port.anchor.x, y: lane) : CGPoint(x: lane, y: port.anchor.y)
                        return Port(anchor: port.anchor, stub: stub, penalty: port.penalty, side: port.side)
                    }
                    let returnStarts = starts.filter { $0.side == side }.map(extend).filter { domain.contains($0.stub) && clear($0.anchor, $0.stub, obstacles: portObstacles) && clearOfBorders($0.anchor, $0.stub, borders: borders) }
                    let returnEnds = ends.filter { $0.side == side }.map(extend).filter { domain.contains($0.stub) && clear($0.anchor, $0.stub, obstacles: portObstacles) && clearOfBorders($0.anchor, $0.stub, borders: borders) }
                    if !returnStarts.isEmpty, !returnEnds.isEmpty { starts = returnStarts; ends = returnEnds }
                }
            }
            let fallbackStarts = starts, fallbackEnds = ends
            if separateConnections {
                let sides: (Int, Int)? = a.maxX < b.minX ? (1, 3) : a.minX > b.maxX ? (3, 1)
                    : a.maxY < b.minY ? (2, 0) : a.minY > b.maxY ? (0, 2) : nil
                if let sides {
                    let facingStarts = starts.filter { $0.side == sides.0 }, facingEnds = ends.filter { $0.side == sides.1 }
                    if edge.sourceSide == nil, !facingStarts.isEmpty { starts = facingStarts }
                    if edge.targetSide == nil, !facingEnds.isEmpty { ends = facingEnds }
                }
            }
            let local = a.union(b).insetBy(dx: -80, dy: -80).intersection(domain)
            // A cross-group edge must not occupy a later internal edge's entrance or exit.
            let reservations = parent(edge.from) == parent(edge.to) ? [] : reservedPorts.keys.sorted().filter { $0 > index }.flatMap { reservedPorts[$0]! }
            let siblings = routed.filter { $0.style != .invisible }.map(\.points) + reservations
            let fan = separateConnections ? fanRoute(edgeIndex: index, edges: graph.edges, starts: starts, ends: ends,
                frameForNode: frame, obstacles: obstacles, captions: additionalObstacles, domain: domain) : nil
            let plan = avoidGroupBorders ? tracks[index] : nil
            let forward = separateConnections ? nil : forwardRoute(starts: starts, ends: ends, obstacles: obstacles, borders: borders, channel: plan, domain: domain, routes: siblings)
            let independentFan = fan.flatMap { points in
                EdgeGeometry.sharesSegment(points, routes: siblings) || !zip(points, points.dropFirst()).allSatisfy({ clearOfBorders($0.0, $0.1, borders: borders) }) ? nil : points
            }
            let channel: [CGPoint]? = tracks[index].flatMap { plan in
                guard let start = starts.first(where: { $0.penalty == 0 }), let end = ends.first(where: { $0.penalty == 0 }) else { return nil }
                let vertical = start.side.isMultiple(of: 2)
                guard vertical != plan.horizontal, end.side == (start.side + 2) % 4 else { return nil }
                let track = plan.coordinate
                let elbowA = vertical ? CGPoint(x: start.anchor.x, y: track) : CGPoint(x: track, y: start.anchor.y)
                let elbowB = vertical ? CGPoint(x: end.anchor.x, y: track) : CGPoint(x: track, y: end.anchor.y)
                let stub: (Port, CGRect) -> CGPoint = { port, rect in
                    switch port.side {
                    case 0: return CGPoint(x: port.anchor.x, y: rect.minY - 8)
                    case 1: return CGPoint(x: rect.maxX + 8, y: port.anchor.y)
                    case 2: return CGPoint(x: port.anchor.x, y: rect.maxY + 8)
                    default: return CGPoint(x: rect.minX - 8, y: port.anchor.y)
                    }
                }
                let corridor = [stub(start, a), elbowA, elbowB, stub(end, b)]
                let points = LayeredLayoutEngine.simplify([start.anchor, elbowA, elbowB, end.anchor])
                guard points.allSatisfy(domain.contains), !EdgeGeometry.sharesSegment(points, routes: siblings),
                      zip(points, points.dropFirst()).allSatisfy({ clearOfBorders($0.0, $0.1, borders: borders) }),
                      zip(points, points.dropFirst()).allSatisfy({ clearChannel($0.0, $0.1, plan: plan, routes: siblings) }),
                      zip(corridor, corridor.dropFirst()).allSatisfy({ clear($0.0, $0.1, obstacles: obstacles) }) else { return nil }
                return points
            }
            let loop: [CGPoint]? = {
                guard edge.from == edge.to else { return nil }
                let loops = graph.edges.indices.filter { graph.edges[$0].from == edge.from && graph.edges[$0].to == edge.from }
                let path = LayeredLayoutEngine.selfLoop(frame: a, position: loops.firstIndex(of: index)!, count: loops.count,
                    anchor: { side, offset in NodeGeometry.anchor(shape: nodes[edge.from]?.shape ?? .rectangle, frame: a, side: side, offset: offset) },
                    obstacles: portObstacles, routes: routed.filter { $0.style != .invisible }.map(\.points), domain: domain)
                return path.isEmpty || !zip(path, path.dropFirst()).allSatisfy({ clearOfBorders($0.0, $0.1, borders: borders) }) ? nil : path
            }()
            let points = loop ?? independentFan ?? channel ?? forward ?? visibilityRoute(starts: starts, ends: ends, obstacles: obstacles, borders: borders, channel: plan, bounds: local, siblings: siblings)
                ?? visibilityRoute(starts: starts, ends: ends, obstacles: obstacles, borders: borders, channel: plan, bounds: domain, siblings: siblings)
                ?? (separateConnections ? visibilityRoute(starts: fallbackStarts, ends: fallbackEnds, obstacles: obstacles, borders: borders, channel: plan, bounds: domain, siblings: siblings) : nil)
            guard let points else {
                throw DiagramRenderError(message: "无法为 \(edge.from) 到 \(edge.to) 的连线找到不穿过节点的路径，请增加分组空间或简化连线。", code: "layout")
            }
            let labelLines = EdgeLabelLayout.lines(edge.label)
            let labelSize = EdgeLabelLayout.size(labelLines)
            labelDomains.append(domain)
            routed.append(SceneEdge(from: edge.from, to: edge.to, points: points, label: labelLines.joined(separator: "\n"),
                                    labelFrame: CGRect(origin: .zero, size: labelSize), style: edge.style, arrow: edge.arrow, startMarker: edge.startMarker, endMarker: edge.endMarker))
        }
        var labelObstacles = scene.nodes.map { $0.frame.insetBy(dx: -4, dy: -4) }
            + scene.groups.filter { !$0.titleLines.allSatisfy(\.isEmpty) }.map { $0.titleFrame.insetBy(dx: -4, dy: -4) } + additionalObstacles
        let paths = routed.filter { $0.style != .invisible }.map(\.points)
        for index in routed.indices where !routed[index].label.isEmpty && routed[index].style != .invisible {
            let label = EdgeLabelLayout.frame(size: routed[index].labelFrame.size, points: routed[index].points,
                obstacles: labelObstacles, routes: paths, domain: labelDomains[index])
            routed[index].labelFrame = label
            labelObstacles.append(label.insetBy(dx: -4, dy: -4))
        }
        var bounds = scene.nodes.reduce(CGRect.null) { $0.union($1.frame) }
        for group in scene.groups { bounds = bounds.union(group.frame) }
        for edge in routed {
            for point in edge.points { bounds = bounds.union(CGRect(origin: point, size: CGSize(width: 1, height: 1))) }
            if !edge.label.isEmpty { bounds = bounds.union(edge.labelFrame) }
        }
        let dx = DiagramStyle.scenePadding - bounds.minX, dy = DiagramStyle.scenePadding - bounds.minY
        let shiftedNodes = scene.nodes.map { node in
            var node = node; node.frame = node.frame.offsetBy(dx: dx, dy: dy); return node
        }
        let shiftedGroups = scene.groups.map { group in
            var group = group
            group.frame = group.frame.offsetBy(dx: dx, dy: dy)
            group.titleFrame = group.titleFrame.offsetBy(dx: dx, dy: dy)
            return group
        }
        for index in routed.indices {
            routed[index].points = routed[index].points.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
            routed[index].labelFrame = routed[index].labelFrame.offsetBy(dx: dx, dy: dy)
        }
        return DiagramScene(size: CGSize(width: bounds.maxX + dx + DiagramStyle.scenePadding, height: bounds.maxY + dy + DiagramStyle.scenePadding),
                            nodes: shiftedNodes, edges: routed, groups: shiftedGroups)
    }

    /// Order parallel group connections together instead of selecting each elbow independently.
    private static func parallelTracks(_ graph: FlowchartModel, frame: (String) -> CGRect, parent: @escaping (String) -> String?,
                                       direction: (String) -> FlowDirection, anchor: (Int, Bool) -> CGPoint) -> [Int: Channel] {
        let boundary: (String, String) -> String = { endpoint, other in
            var otherAncestors = Set<String>(), current = parent(other)
            while let id = current { otherAncestors.insert(id); current = parent(id) }
            var result = endpoint
            current = parent(endpoint)
            while let id = current, !otherAncestors.contains(id), id != other {
                result = id
                current = parent(id)
            }
            return result
        }
        let candidates = graph.edges.indices.filter { index in
            let edge = graph.edges[index]
            return edge.style != .invisible && edge.sourceSide == nil && edge.targetSide == nil && parent(edge.from) != parent(edge.to)
        }
        let pairs = Dictionary(grouping: candidates) { [boundary(graph.edges[$0].from, graph.edges[$0].to), boundary(graph.edges[$0].to, graph.edges[$0].from)] }
        var result: [Int: Channel] = [:]
        for (pair, indices) in pairs where indices.count >= 2 {
            let flow = direction(pair[0])
            let horizontal = flow.horizontal
            let positive = flow == .leftRight || flow == .topDown
            // Turns occupy the gap between group outlines, including nested ancestor outlines.
            let sources = indices.map { frame(boundary(graph.edges[$0].from, graph.edges[$0].to)) }
            let targets = indices.map { frame(boundary(graph.edges[$0].to, graph.edges[$0].from)) }
            let starts = sources.map { horizontal ? (positive ? $0.maxX : $0.minX) : (positive ? $0.maxY : $0.minY) }
            let ends = targets.map { horizontal ? (positive ? $0.minX : $0.maxX) : (positive ? $0.minY : $0.maxY) }
            let first = positive ? starts.max()! : starts.min()!, last = positive ? ends.min()! : ends.max()!
            let sign: CGFloat = positive ? 1 : -1
            let clearance = DiagramStyle.groupEdgeClearance
            let available = (last - first) * sign - 2 * clearance
            guard available >= CGFloat(indices.count - 1) * DiagramStyle.edgeLaneSeparation - 0.01 else { continue }
            let ordered = indices.sorted { a, b in
                let a0 = anchor(a, true), a1 = anchor(a, false), b0 = anchor(b, true), b1 = anchor(b, false)
                let startA = horizontal ? a0.y : a0.x, endA = horizontal ? a1.y : a1.x
                let startB = horizontal ? b0.y : b0.x, endB = horizontal ? b1.y : b1.x
                let beforeA = endA < startA, beforeB = endB < startB
                if beforeA != beforeB { return beforeA }
                if abs(startA + endA - startB - endB) > 0.001 {
                    return beforeA ? startA + endA < startB + endB : startA + endA > startB + endB
                }
                return a < b
            }
            for (position, index) in ordered.enumerated() {
                let coordinate = first + sign * (clearance + available * CGFloat(position) / CGFloat(ordered.count - 1))
                result[index] = Channel(coordinate: coordinate, horizontal: horizontal,
                    range: (min(first, last) + clearance)...(max(first, last) - clearance))
            }
        }
        return result
    }

    private static func forwardRoute(starts: [Port], ends: [Port], obstacles: [CGRect], borders: [CGRect], channel: Channel?, domain: CGRect, routes: [[CGPoint]]) -> [CGPoint]? {
        for start in starts where start.penalty == 0 {
            let vertical = start.side.isMultiple(of: 2), positive = start.side == 1 || start.side == 2
            for end in ends where end.penalty == 0 && end.side == (start.side + 2) % 4 {
                let first = vertical ? start.stub.y : start.stub.x, last = vertical ? end.stub.y : end.stub.x
                guard positive ? first <= last : first >= last else { continue }
                for offset: CGFloat in [0, -12, 12, -24, 24, -36, 36] {
                    let middle = (first + last) / 2 + offset
                    guard middle >= min(first, last), middle <= max(first, last) else { continue }
                    let a = vertical ? CGPoint(x: start.anchor.x, y: middle) : CGPoint(x: middle, y: start.anchor.y)
                    let b = vertical ? CGPoint(x: end.anchor.x, y: middle) : CGPoint(x: middle, y: end.anchor.y)
                    let corridor = [start.stub, a, b, end.stub]
                    let points = LayeredLayoutEngine.simplify([start.anchor, a, b, end.anchor])
                    guard corridor.allSatisfy({ domain.contains($0) }),
                          zip(points, points.dropFirst()).allSatisfy({ clearOfBorders($0.0, $0.1, borders: borders) }),
                          zip(points, points.dropFirst()).allSatisfy({ clearChannel($0.0, $0.1, plan: channel, routes: routes) }),
                          zip(corridor, corridor.dropFirst()).allSatisfy({ clear($0.0, $0.1, obstacles: obstacles) }),
                          !EdgeGeometry.sharesSegment(points, routes: routes) else { continue }
                    return points
                }
            }
        }
        return nil
    }

    private static func fanRoute(edgeIndex: Int, edges: [FlowEdge], starts: [Port], ends: [Port],
                                 frameForNode: (String) -> CGRect, obstacles: [CGRect], captions: [CGRect], domain: CGRect) -> [CGPoint]? {
        let edge = edges[edgeIndex], source = frameForNode(edge.from)
        for start in starts {
            let side = start.side, vertical = side.isMultiple(of: 2), positive = side == 1 || side == 2
            let peers = edges.indices.filter { index in
                let candidate = edges[index], target = frameForNode(candidate.to)
                guard candidate.from == edge.from, candidate.sourceSide == nil || candidate.sourceSide == side else { return false }
                switch side {
                case 0: return target.maxY < source.minY
                case 1: return target.minX > source.maxX
                case 2: return target.minY > source.maxY
                default: return target.maxX < source.minX
                }
            }.sorted {
                let a = frameForNode(edges[$0].to), b = frameForNode(edges[$1].to)
                let av = vertical ? a.midX : a.midY, bv = vertical ? b.midX : b.midY
                return av == bv ? $0 < $1 : av < bv
            }
            guard peers.count > 1, let position = peers.firstIndex(of: edgeIndex) else { continue }
            let target = frameForNode(edge.to)
            let before = vertical ? target.midX < source.midX : target.midY < source.midY
            let rank = before ? position : peers.count - position - 1
            let envelope = captions.filter { $0.intersects(source.insetBy(dx: -12, dy: -12)) }.reduce(source) { $0.union($1) }
            let boundary = vertical ? (positive ? envelope.maxY : envelope.minY) : (positive ? envelope.maxX : envelope.minX)
            let lane = boundary + (positive ? 1 : -1) * (12 + CGFloat(rank) * 12)
            for end in ends where end.side == (side + 2) % 4 {
                let startAxis = vertical ? start.stub.y : start.stub.x, endAxis = vertical ? end.stub.y : end.stub.x
                guard positive ? lane >= startAxis && lane <= endAxis : lane <= startAxis && lane >= endAxis else { continue }
                let a = vertical ? CGPoint(x: start.anchor.x, y: lane) : CGPoint(x: lane, y: start.anchor.y)
                let b = vertical ? CGPoint(x: end.anchor.x, y: lane) : CGPoint(x: lane, y: end.anchor.y)
                let corridor = [start.stub, a, b, end.stub]
                guard corridor.allSatisfy({ domain.contains($0) }),
                      zip(corridor, corridor.dropFirst()).allSatisfy({ clear($0.0, $0.1, obstacles: obstacles) }) else { continue }
                return LayeredLayoutEngine.simplify([start.anchor, a, b, end.anchor])
            }
        }
        return nil
    }

    private static func ports(frame r: CGRect, node: SceneNode?, direction: FlowDirection, leaving: Bool,
                              edgeIndex: Int, edges: [FlowEdge], frameForNode: (String) -> CGRect, minimumStub: CGFloat, projectSpanningPorts: Bool) -> [Port] {
        let preferred: Int
        switch direction {
        case .topDown: preferred = leaving ? 2 : 0
        case .bottomUp: preferred = leaving ? 0 : 2
        case .leftRight: preferred = leaving ? 1 : 3
        case .rightLeft: preferred = leaving ? 3 : 1
        }
        let edge = edges[edgeIndex], id = leaving ? edge.from : edge.to
        return (0..<4).compactMap { side in
            if let explicit = leaving ? edge.sourceSide : edge.targetSide, side != explicit { return nil }
            let vertical = side.isMultiple(of: 2)
            let peers = edges.indices.flatMap { index -> [(index: Int, leaving: Bool)] in
                let candidate = edges[index]
                guard candidate.from != candidate.to || index == edgeIndex else { return [] }
                var endpoints: [(index: Int, leaving: Bool)] = []
                if candidate.from == id, candidate.sourceSide == side || leaving && candidate.sourceSide == nil { endpoints.append((index, true)) }
                if candidate.to == id, candidate.targetSide == side || !leaving && candidate.targetSide == nil { endpoints.append((index, false)) }
                return endpoints
            }.sorted {
                let a = frameForNode($0.leaving ? edges[$0.index].to : edges[$0.index].from)
                let b = frameForNode($1.leaving ? edges[$1.index].to : edges[$1.index].from)
                let av = vertical ? a.midX : a.midY, bv = vertical ? b.midX : b.midY
                if av != bv { return av < bv }
                return $0.index == $1.index ? $0.leaving && !$1.leaving : $0.index < $1.index
            }
            let position = peers.firstIndex { $0.index == edgeIndex && $0.leaving == leaving }!, count = peers.count
            let half = (vertical ? r.width : r.height) / 2
            let separation: CGFloat = vertical ? 16 : max(16, peers.map { endpoint in
                let label = edges[endpoint.index].label
                return label.isEmpty ? 16 : EdgeLabelLayout.size(EdgeLabelLayout.lines(label)).height + 10
            }.max() ?? 16)
            var spread = (CGFloat(position) - CGFloat(count - 1) / 2) * min(separation, half / CGFloat(max(1, count - 1)))
            var projected = false
            if projectSpanningPorts, count > 1 {
                let coordinates = peers.map { endpoint -> CGFloat in
                    let other = frameForNode(endpoint.leaving ? edges[endpoint.index].to : edges[endpoint.index].from)
                    return vertical ? other.midX : other.midY
                }
                let center = vertical ? r.midX : r.midY
                if coordinates.allSatisfy({ abs($0 - center) <= half - 12 }),
                   zip(coordinates, coordinates.dropFirst()).allSatisfy({ $0.1 - $0.0 >= 12 }) {
                    spread = coordinates[position] - center
                    projected = true
                }
            }
            let normal = [CGPoint(x: 0, y: -1), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: -1, y: 0)][side]
            let anchor = NodeGeometry.anchor(shape: node?.shape ?? .rectangle, frame: r, side: side, offset: spread)
            let other = frameForNode(leaving ? edge.to : edge.from)
            // Outer branches turn first, leaving a separate corridor for the inner branches.
            let before = vertical ? other.midX < r.midX : other.midY < r.midY
            let lane = min(3, before ? position : count - position - 1)
            let distance = minimumStub + (projected ? 0 : CGFloat(lane) * 12)
            let stub = vertical ? CGPoint(x: anchor.x, y: r.midY + normal.y * (r.height / 2 + distance))
                : CGPoint(x: r.midX + normal.x * (r.width / 2 + distance), y: anchor.y)
            return Port(anchor: anchor, stub: stub, penalty: side == preferred ? 0 : 28, side: side)
        }
    }

    private static func clear(_ a: CGPoint, _ b: CGPoint, obstacles: [CGRect]) -> Bool {
        for r in obstacles {
            if abs(a.x - b.x) < 0.01 {
                if a.x > r.minX + 0.01 && a.x < r.maxX - 0.01 && max(min(a.y, b.y), r.minY) < min(max(a.y, b.y), r.maxY) - 0.01 { return false }
            } else if a.y > r.minY + 0.01 && a.y < r.maxY - 0.01 && max(min(a.x, b.x), r.minX) < min(max(a.x, b.x), r.maxX) - 0.01 { return false }
        }
        return true
    }

    /// Crossing a group outline is allowed; following it within the clearance band is not.
    private static func clearOfBorders(_ a: CGPoint, _ b: CGPoint, borders: [CGRect]) -> Bool {
        let clearance = DiagramStyle.groupEdgeClearance - 0.01
        for rect in borders {
            if abs(a.x - b.x) < 0.01,
               min(max(a.y, b.y), rect.maxY) - max(min(a.y, b.y), rect.minY) > 0.01,
               min(abs(a.x - rect.minX), abs(a.x - rect.maxX)) < clearance { return false }
            if abs(a.y - b.y) < 0.01,
               min(max(a.x, b.x), rect.maxX) - max(min(a.x, b.x), rect.minX) > 0.01,
               min(abs(a.y - rect.minY), abs(a.y - rect.maxY)) < clearance { return false }
        }
        return true
    }

    private static func clearChannel(_ a: CGPoint, _ b: CGPoint, plan: Channel?, routes: [[CGPoint]]) -> Bool {
        guard let plan else { return true }
        let axis: (CGPoint) -> CGFloat = { plan.horizontal ? $0.x : $0.y }
        let cross: (CGPoint) -> CGFloat = { plan.horizontal ? $0.y : $0.x }
        guard abs(axis(a) - axis(b)) < 0.01, axis(a) >= plan.range.lowerBound - 0.01,
              axis(a) <= plan.range.upperBound + 0.01 else { return true }
        return !routes.contains { route in zip(route, route.dropFirst()).contains { c, d in
            abs(axis(c) - axis(d)) < 0.01 && axis(c) >= plan.range.lowerBound - 0.01 && axis(c) <= plan.range.upperBound + 0.01
                && min(max(cross(a), cross(b)), max(cross(c), cross(d))) - max(min(cross(a), cross(b)), min(cross(c), cross(d))) > 0.01
                && abs(axis(a) - axis(c)) < DiagramStyle.edgeLaneSeparation - 0.01
        } }
    }

    private static func visibilityRoute(starts: [Port], ends: [Port], obstacles: [CGRect], borders: [CGRect], channel: Channel?, bounds: CGRect, siblings: [[CGPoint]]) -> [CGPoint]? {
        let starts = starts.filter { bounds.contains($0.stub) }, ends = ends.filter { bounds.contains($0.stub) }
        guard !starts.isEmpty, !ends.isEmpty else { return nil }
        let obstacles = obstacles.filter { $0.intersects(bounds) }
        let channelPadding: CGFloat = channel == nil ? 8 : DiagramStyle.edgeLaneSeparation
        let channels = siblings.flatMap { route in
            zip(route, route.dropFirst()).map { a, b in
                CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y)).insetBy(dx: -channelPadding, dy: -channelPadding)
            }
        }.filter { $0.intersects(bounds) }
        let congestion: (CGPoint, CGPoint) -> CGFloat = { a, b in
            CGFloat(channels.filter { !clear(a, b, obstacles: [$0]) }.count) * 160
        }
        let clearance = DiagramStyle.groupEdgeClearance
        let borderXs = borders.flatMap { [$0.minX - clearance, $0.minX + clearance, $0.maxX - clearance, $0.maxX + clearance] }.filter { $0 >= bounds.minX && $0 <= bounds.maxX }
        let borderYs = borders.flatMap { [$0.minY - clearance, $0.minY + clearance, $0.maxY - clearance, $0.maxY + clearance] }.filter { $0 >= bounds.minY && $0 <= bounds.maxY }
        let xs = Array(Set([bounds.minX, bounds.maxX] + borderXs + starts.map { $0.stub.x } + ends.map { $0.stub.x }
            + (obstacles + channels).flatMap { [$0.minX, $0.maxX] }.filter { $0 >= bounds.minX && $0 <= bounds.maxX })).sorted()
        let ys = Array(Set([bounds.minY, bounds.maxY] + borderYs + starts.map { $0.stub.y } + ends.map { $0.stub.y }
            + (obstacles + channels).flatMap { [$0.minY, $0.maxY] }.filter { $0 >= bounds.minY && $0 <= bounds.maxY })).sorted()
        let width = xs.count, cells = width * ys.count
        guard cells <= 200_000 else { return nil }
        let cell: (CGPoint) -> Int = { ys.firstIndex(of: $0.y)! * width + xs.firstIndex(of: $0.x)! }
        let point: (Int) -> CGPoint = { CGPoint(x: xs[$0 % width], y: ys[$0 / width]) }
        let heuristic: (CGPoint) -> CGFloat = { p in ends.map { abs($0.stub.x - p.x) + abs($0.stub.y - p.y) }.min()! }
        var costs = Array(repeating: CGFloat.infinity, count: cells * 3)
        var previous = Array(repeating: -1, count: cells * 3)
        var origin = previous
        var heap = RouteHeap()
        for (index, port) in starts.enumerated() {
            guard !EdgeGeometry.sharesSegment([port.anchor, port.stub], routes: siblings), clearChannel(port.anchor, port.stub, plan: channel, routes: siblings) else { continue }
            let axis = abs(port.anchor.x - port.stub.x) > 0.01 ? 1 : 2
            let state = cell(port.stub) * 3 + axis
            let cost = port.penalty + abs(port.anchor.x - port.stub.x) + abs(port.anchor.y - port.stub.y) + congestion(port.anchor, port.stub)
            if cost < costs[state] {
                costs[state] = cost; origin[state] = index
                heap.push(RouteVisit(state: state, cost: cost, estimate: cost + heuristic(port.stub)))
            }
        }
        var goal = -1, endPort = 0, best = CGFloat.infinity
        let endCells = ends.map { cell($0.stub) }
        while let visit = heap.pop() {
            guard visit.cost == costs[visit.state] else { continue }
            if visit.estimate >= best { break }
            let index = visit.state / 3, axis = visit.state % 3, p = point(index)
            for target in ends.indices where endCells[target] == index {
                let end = ends[target]
                guard !EdgeGeometry.sharesSegment([end.stub, end.anchor], routes: siblings), clearChannel(end.stub, end.anchor, plan: channel, routes: siblings) else { continue }
                let endAxis = abs(end.anchor.x - end.stub.x) > 0.01 ? 1 : 2
                let score = visit.cost + end.penalty + abs(end.anchor.x - end.stub.x) + abs(end.anchor.y - end.stub.y)
                    + (axis != endAxis ? 18 : 0) + congestion(end.stub, end.anchor)
                if score < best { best = score; goal = visit.state; endPort = target }
            }
            let x = index % width, y = index / width
            let neighbours = [(x - 1, y, 1), (x + 1, y, 1), (x, y - 1, 2), (x, y + 1, 2)]
            for (nx, ny, nextAxis) in neighbours where nx >= 0 && nx < width && ny >= 0 && ny < ys.count {
                let nextCell = ny * width + nx, q = point(nextCell)
                guard clear(p, q, obstacles: obstacles), clearOfBorders(p, q, borders: borders), clearChannel(p, q, plan: channel, routes: siblings), !EdgeGeometry.sharesSegment([p, q], routes: siblings) else { continue }
                let next = nextCell * 3 + nextAxis
                let cost = visit.cost + abs(q.x - p.x) + abs(q.y - p.y) + (axis != 0 && axis != nextAxis ? 18 : 0) + congestion(p, q)
                guard cost < costs[next] else { continue }
                costs[next] = cost; previous[next] = visit.state; origin[next] = origin[visit.state]
                heap.push(RouteVisit(state: next, cost: cost, estimate: cost + heuristic(q)))
            }
        }
        guard goal >= 0 else { return nil }
        var route: [CGPoint] = [ends[endPort].anchor]
        var cursor = goal
        while cursor >= 0 { route.append(point(cursor / 3)); cursor = previous[cursor] }
        route.append(starts[origin[goal]].anchor)
        return LayeredLayoutEngine.simplify(route.reversed())
    }


}

private struct RouteVisit {
    let state: Int
    let cost: CGFloat
    let estimate: CGFloat
}

private struct RouteHeap {
    var values: [RouteVisit] = []
    mutating func push(_ item: RouteVisit) {
        values.append(item)
        var i = values.count - 1
        while i > 0 {
            let parent = (i - 1) / 2
            guard values[i].estimate < values[parent].estimate else { break }
            values.swapAt(i, parent); i = parent
        }
    }
    mutating func pop() -> RouteVisit? {
        guard !values.isEmpty else { return nil }
        if values.count == 1 { return values.removeLast() }
        let result = values[0]
        values[0] = values.removeLast()
        var i = 0
        while i * 2 + 1 < values.count {
            var child = i * 2 + 1
            if child + 1 < values.count && values[child + 1].estimate < values[child].estimate { child += 1 }
            guard values[child].estimate < values[i].estimate else { break }
            values.swapAt(i, child); i = child
        }
        return result
    }
}
