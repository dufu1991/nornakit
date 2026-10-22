import Foundation

enum EdgeGeometry {
    static func sharedLength(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> CGFloat {
        if abs(a.x - b.x) < 0.001, abs(c.x - d.x) < 0.001, abs(a.x - c.x) < 0.001 {
            return max(0, min(max(a.y, b.y), max(c.y, d.y)) - max(min(a.y, b.y), min(c.y, d.y)))
        }
        if abs(a.y - b.y) < 0.001, abs(c.y - d.y) < 0.001, abs(a.y - c.y) < 0.001 {
            return max(0, min(max(a.x, b.x), max(c.x, d.x)) - max(min(a.x, b.x), min(c.x, d.x)))
        }
        return 0
    }

    static func sharesSegment(_ points: [CGPoint], routes: [[CGPoint]]) -> Bool {
        zip(points, points.dropFirst()).contains { a, b in
            routes.contains { route in
                zip(route, route.dropFirst()).contains { c, d in sharedLength(a, b, c, d) > 0.01 }
            }
        }
    }

    static func segments(_ commands: [PathCommand]) -> [(CGPoint, CGPoint)] {
        var result: [(CGPoint, CGPoint)] = []
        var cursor = CGPoint.zero
        for command in commands {
            switch command {
            case .move(let p): cursor = p
            case .line(let p): result.append((cursor, p)); cursor = p
            case .quad(let a, let p):
                let start = cursor
                for step in 1...24 {
                    let t = CGFloat(step) / 24, u = 1 - t
                    let end = CGPoint(x: u * u * start.x + 2 * u * t * a.x + t * t * p.x,
                                      y: u * u * start.y + 2 * u * t * a.y + t * t * p.y)
                    result.append((cursor, end)); cursor = end
                }
            case .cubic(let a, let b, let p):
                let start = cursor
                for step in 1...24 {
                    let t = CGFloat(step) / 24, u = 1 - t
                    let end = CGPoint(x: u * u * u * start.x + 3 * u * u * t * a.x + 3 * u * t * t * b.x + t * t * t * p.x,
                                      y: u * u * u * start.y + 3 * u * u * t * a.y + 3 * u * t * t * b.y + t * t * t * p.y)
                    result.append((cursor, end)); cursor = end
                }
            case .close: break
            }
        }
        return result
    }

    static func clear(_ a: CGPoint, _ b: CGPoint, obstacles: [CGRect]) -> Bool {
        for rect in obstacles where rect.width > 0 && rect.height > 0 {
            let r = rect.insetBy(dx: 0.01, dy: 0.01)
            var lower: CGFloat = 0, upper: CGFloat = 1
            var misses = false
            for (origin, delta, minimum, maximum) in [(a.x, b.x - a.x, r.minX, r.maxX), (a.y, b.y - a.y, r.minY, r.maxY)] {
                if abs(delta) < 0.00001 {
                    if origin <= minimum || origin >= maximum { misses = true; break }
                } else {
                    let first = (minimum - origin) / delta, last = (maximum - origin) / delta
                    lower = max(lower, min(first, last)); upper = min(upper, max(first, last))
                }
            }
            if !misses, upper - lower > 0.00001 { return false }
        }
        return true
    }


}

enum EdgeLabelLayout {
    static func lines(_ text: String) -> [String] { TextMeasurement.lines(text, maxWidth: 180, size: DiagramStyle.edgeFontSize) }

    static func size(_ lines: [String]) -> CGSize {
        CGSize(width: (lines.map { TextMeasurement.width($0, size: DiagramStyle.edgeFontSize) }.max() ?? 0) + 4,
               height: CGFloat(lines.count) * DiagramStyle.edgeLineHeight)
    }

    static func frame(size: CGSize, points: [CGPoint], obstacles: [CGRect], routes: [[CGPoint]], domain: CGRect? = nil) -> CGRect {
        let otherRoutes = routes.filter { $0 != points }.map { EdgeGeometry.segments(ScenePath.edge($0).commands) }
        var best: (CGRect, CGFloat)?
        var straightSegments: [(CGPoint, CGPoint)] = []
        var cursor = points.first ?? .zero
        for command in ScenePath.edge(points).commands {
            switch command {
            case .line(let end): straightSegments.append((cursor, end)); cursor = end
            case .move(let end), .quad(_, let end), .cubic(_, _, let end): cursor = end
            case .close: break
            }
        }
        for (a, b) in straightSegments {
            let length = hypot(b.x - a.x, b.y - a.y)
            guard length > 0.01 else { continue }
            let extent = abs(b.x - a.x) > abs(b.y - a.y) ? size.width : size.height
            var positions: [CGFloat] = [0.5, 0.35, 0.65, 0.2, 0.8, 0.3, 0.7, 0.25, 0.75, 0.15, 0.85, 0.1, 0.9]
            // Sample obstacle boundaries as well as percentages, so narrow free intervals are not missed.
            let horizontal = abs(b.x - a.x) > abs(b.y - a.y)
            let exclusions = obstacles + otherRoutes.flatMap { route in
                route.map { p, q in
                    CGRect(x: min(p.x, q.x), y: min(p.y, q.y), width: abs(p.x - q.x), height: abs(p.y - q.y)).insetBy(dx: -2, dy: -2)
                }
            }
            for obstacle in exclusions {
                let center = horizontal ? a.y : a.x
                let half = (horizontal ? size.height : size.width) / 2
                let minimum = horizontal ? obstacle.minY : obstacle.minX
                let maximum = horizontal ? obstacle.maxY : obstacle.maxX
                guard maximum >= center - half, minimum <= center + half else { continue }
                let values = horizontal ? [obstacle.minX - size.width / 2 - 0.1, obstacle.maxX + size.width / 2 + 0.1]
                    : [obstacle.minY - size.height / 2 - 0.1, obstacle.maxY + size.height / 2 + 0.1]
                let delta = horizontal ? b.x - a.x : b.y - a.y
                let origin = horizontal ? a.x : a.y
                positions += values.map { ($0 - origin) / delta }.filter { $0 > 0 && $0 < 1 }
            }
            for t in Set(positions).sorted() {
                let center = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                let r = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
                let collisions = obstacles.filter { $0.intersects(r) }.count
                let overlap = obstacles.reduce(CGFloat(0)) { area, obstacle in
                    let intersection = obstacle.intersection(r)
                    return area + (intersection.isNull ? 0 : intersection.width * intersection.height)
                } / max(1, r.width * r.height)
                let crossings = otherRoutes.reduce(0) { count, route in
                    count + (route.contains { !EdgeGeometry.clear($0.0, $0.1, obstacles: [r.insetBy(dx: -6, dy: -6)]) } ? 1 : 0)
                }
                let intersections = otherRoutes.reduce(0) { count, route in
                    count + (route.contains { !EdgeGeometry.clear($0.0, $0.1, obstacles: [r]) } ? 1 : 0)
                }
                let outside = domain.map { $0.contains(r) ? 0 : 1 } ?? 0
                let clearance = min(length * t, length * (1 - t)) - extent / 2
                let shortage = max(0, 16 - clearance)
                let score: CGFloat = CGFloat(collisions + intersections) * 1_000_000 + CGFloat(crossings) * 20_000 + CGFloat(outside) * 100_000
                    + overlap * 10_000 + shortage * 100 + abs(t - 0.5) * 40 - min(length, 300) * 0.02
                if best == nil || score < best!.1 { best = (r, score) }
            }
        }
        return best?.0 ?? CGRect(origin: points.first ?? .zero, size: size)
    }
}
