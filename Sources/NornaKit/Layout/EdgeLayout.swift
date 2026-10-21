import Foundation

enum EdgeGeometry {
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
            for t: CGFloat in [0.5, 0.35, 0.65, 0.2, 0.8, 0.3, 0.7, 0.25, 0.75, 0.15, 0.85, 0.1, 0.9] {
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
                let outside = domain.map { $0.contains(r) ? 0 : 1 } ?? 0
                let clearance = min(length * t, length * (1 - t)) - extent / 2
                let shortage = max(0, 16 - clearance)
                let score: CGFloat = CGFloat(collisions) * 100_000 + CGFloat(crossings) * 20_000 + CGFloat(outside) * 10_000
                    + overlap * 10_000 + shortage * 100 + abs(t - 0.5) * 40 - min(length, 300) * 0.02
                if best == nil || score < best!.1 { best = (r, score) }
            }
        }
        return best?.0 ?? CGRect(origin: points.first ?? .zero, size: size)
    }
}
