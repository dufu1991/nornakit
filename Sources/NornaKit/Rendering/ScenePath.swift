import CoreGraphics
import Foundation

/// One path description is shared by the native painter and the SVG exporter.
public enum PathCommand: Equatable, Sendable {
    case move(CGPoint), line(CGPoint), quad(CGPoint, CGPoint), cubic(CGPoint, CGPoint, CGPoint), close
}

struct ScenePath {
    var commands: [PathCommand] = []

    var cgPath: CGPath {
        let result = CGMutablePath()
        for command in commands {
            switch command {
            case .move(let p): result.move(to: p)
            case .line(let p): result.addLine(to: p)
            case .quad(let control, let end): result.addQuadCurve(to: end, control: control)
            case .cubic(let a, let b, let end): result.addCurve(to: end, control1: a, control2: b)
            case .close: result.closeSubpath()
            }
        }
        return result
    }

    var svg: String {
        let point: (CGPoint) -> String = { "\(number($0.x)) \(number($0.y))" }
        return commands.map { command in
            switch command {
            case .move(let p): "M \(point(p))"
            case .line(let p): "L \(point(p))"
            case .quad(let c, let p): "Q \(point(c)) \(point(p))"
            case .cubic(let a, let b, let p): "C \(point(a)) \(point(b)) \(point(p))"
            case .close: "Z"
            }
        }.joined(separator: " ")
    }

    static func roundedRectangle(_ r: CGRect, radius: CGFloat) -> ScenePath {
        let k = min(radius, min(r.width, r.height) / 2)
        let handle = k * 0.55228475
        return ScenePath(commands: [
            .move(CGPoint(x: r.minX + k, y: r.minY)), .line(CGPoint(x: r.maxX - k, y: r.minY)),
            .cubic(CGPoint(x: r.maxX - k + handle, y: r.minY), CGPoint(x: r.maxX, y: r.minY + k - handle), CGPoint(x: r.maxX, y: r.minY + k)),
            .line(CGPoint(x: r.maxX, y: r.maxY - k)),
            .cubic(CGPoint(x: r.maxX, y: r.maxY - k + handle), CGPoint(x: r.maxX - k + handle, y: r.maxY), CGPoint(x: r.maxX - k, y: r.maxY)),
            .line(CGPoint(x: r.minX + k, y: r.maxY)),
            .cubic(CGPoint(x: r.minX + k - handle, y: r.maxY), CGPoint(x: r.minX, y: r.maxY - k + handle), CGPoint(x: r.minX, y: r.maxY - k)),
            .line(CGPoint(x: r.minX, y: r.minY + k)),
            .cubic(CGPoint(x: r.minX, y: r.minY + k - handle), CGPoint(x: r.minX + k - handle, y: r.minY), CGPoint(x: r.minX + k, y: r.minY)), .close
        ])
    }

    static func node(_ node: SceneNode) -> ScenePath {
        let r = node.frame
        if let vertices = polygon(node.shape, frame: r) {
            return ScenePath(commands: [.move(vertices[0])] + vertices.dropFirst().map(PathCommand.line) + [.close])
        }
        switch node.shape {
        case .diamond:
            return ScenePath(commands: [.move(CGPoint(x: r.midX, y: r.minY)), .line(CGPoint(x: r.maxX, y: r.midY)),
                                        .line(CGPoint(x: r.midX, y: r.maxY)), .line(CGPoint(x: r.minX, y: r.midY)), .close])
        case .circle, .doubleCircle, .ellipse:
            let k: CGFloat = 0.55228475
            let rx = r.width / 2, ry = r.height / 2
            return ScenePath(commands: [
                .move(CGPoint(x: r.midX, y: r.minY)),
                .cubic(CGPoint(x: r.midX + rx * k, y: r.minY), CGPoint(x: r.maxX, y: r.midY - ry * k), CGPoint(x: r.maxX, y: r.midY)),
                .cubic(CGPoint(x: r.maxX, y: r.midY + ry * k), CGPoint(x: r.midX + rx * k, y: r.maxY), CGPoint(x: r.midX, y: r.maxY)),
                .cubic(CGPoint(x: r.midX - rx * k, y: r.maxY), CGPoint(x: r.minX, y: r.midY + ry * k), CGPoint(x: r.minX, y: r.midY)),
                .cubic(CGPoint(x: r.minX, y: r.midY - ry * k), CGPoint(x: r.midX - rx * k, y: r.minY), CGPoint(x: r.midX, y: r.minY)), .close
            ])
        case .cylinder:
            let ry = min(12, max(6, r.width / 14))
            return ScenePath(commands: [
                .move(CGPoint(x: r.minX, y: r.minY + ry)),
                .cubic(CGPoint(x: r.minX, y: r.minY - ry / 3), CGPoint(x: r.maxX, y: r.minY - ry / 3), CGPoint(x: r.maxX, y: r.minY + ry)),
                .line(CGPoint(x: r.maxX, y: r.maxY - ry)),
                .cubic(CGPoint(x: r.maxX, y: r.maxY + ry / 3), CGPoint(x: r.minX, y: r.maxY + ry / 3), CGPoint(x: r.minX, y: r.maxY - ry)), .close
            ])
        case .stadium: return roundedRectangle(r, radius: r.height / 2)
        case .rounded: return roundedRectangle(r, radius: 12)
        default: return roundedRectangle(r, radius: DiagramStyle.cornerRadius)
        }
    }

    static func detail(_ node: SceneNode) -> ScenePath {
        let r = node.frame
        switch node.shape {
        case .doubleCircle:
            return self.node(SceneNode(id: node.id, label: "", shape: .circle, frame: r.insetBy(dx: 5, dy: 5), lines: []))
        case .cylinder:
            let ry = min(12, max(6, r.width / 14))
            return ScenePath(commands: [.move(CGPoint(x: r.minX, y: r.minY + ry)),
                .cubic(CGPoint(x: r.minX, y: r.minY + ry * 7 / 3), CGPoint(x: r.maxX, y: r.minY + ry * 7 / 3), CGPoint(x: r.maxX, y: r.minY + ry))])
        case .subroutine:
            return ScenePath(commands: [.move(CGPoint(x: r.minX + 8, y: r.minY)), .line(CGPoint(x: r.minX + 8, y: r.maxY)),
                .move(CGPoint(x: r.maxX - 8, y: r.minY)), .line(CGPoint(x: r.maxX - 8, y: r.maxY))])
        default: return ScenePath()
        }
    }

    static func polygon(_ shape: NodeShape, frame r: CGRect) -> [CGPoint]? {
        let vertices: [(CGFloat, CGFloat)]
        switch shape {
        case .hexagon: vertices = [(0.2, 0), (0.8, 0), (1, 0.5), (0.8, 1), (0.2, 1), (0, 0.5)]
        case .asymmetric: vertices = [(0, 0), (0.8, 0), (1, 0.5), (0.8, 1), (0, 1), (0.2, 0.5)]
        case .parallelogram: vertices = [(0.2, 0), (1, 0), (0.8, 1), (0, 1)]
        case .parallelogramAlt: vertices = [(0, 0), (0.8, 0), (1, 1), (0.2, 1)]
        case .trapezoid: vertices = [(0.2, 0), (0.8, 0), (1, 1), (0, 1)]
        case .trapezoidAlt: vertices = [(0, 0), (1, 0), (0.8, 1), (0.2, 1)]
        default: return nil
        }
        return vertices.map { CGPoint(x: r.minX + $0.0 * r.width, y: r.minY + $0.1 * r.height) }
    }

    static func marker(_ marker: EdgeMarker, points: [CGPoint]) -> ScenePath {
        guard let tip = points.last else { return ScenePath() }
        let previous = points.dropLast().last ?? tip
        let length = max(0.001, hypot(tip.x - previous.x, tip.y - previous.y))
        let back: (CGFloat) -> CGPoint = { CGPoint(x: tip.x - (tip.x - previous.x) / length * $0, y: tip.y - (tip.y - previous.y) / length * $0) }
        switch marker {
        case .none: return ScenePath()
        case .arrow: return arrow(points)
        case .circle:
            let center = back(3.5)
            return node(SceneNode(id: "", label: "", shape: .circle, frame: CGRect(x: center.x - 3.5, y: center.y - 3.5, width: 7, height: 7), lines: []))
        case .cross:
            let center = back(6)
            return ScenePath(commands: [.move(CGPoint(x: center.x - 4, y: center.y - 4)), .line(CGPoint(x: center.x + 4, y: center.y + 4)), .move(CGPoint(x: center.x + 4, y: center.y - 4)), .line(CGPoint(x: center.x - 4, y: center.y + 4))])
        }
    }

    static func edge(_ points: [CGPoint]) -> ScenePath {
        guard let first = points.first else { return ScenePath() }
        var commands: [PathCommand] = [.move(first)]
        if points.count > 2 {
            for i in 1..<(points.count - 1) {
                let a = points[i - 1], b = points[i], c = points[i + 1]
                let ab = hypot(b.x - a.x, b.y - a.y), bc = hypot(c.x - b.x, c.y - b.y)
                let radius = min(20, min(ab, bc) / 2)
                guard ab > 0, bc > 0 else { continue }
                let start = CGPoint(x: b.x + (a.x - b.x) * radius / ab, y: b.y + (a.y - b.y) * radius / ab)
                let end = CGPoint(x: b.x + (c.x - b.x) * radius / bc, y: b.y + (c.y - b.y) * radius / bc)
                let first = CGPoint(x: start.x + (b.x - start.x) * 0.62, y: start.y + (b.y - start.y) * 0.62)
                let second = CGPoint(x: end.x + (b.x - end.x) * 0.62, y: end.y + (b.y - end.y) * 0.62)
                commands += [.line(start), .cubic(first, second, end)]
            }
        }
        if let last = points.last { commands.append(.line(last)) }
        return ScenePath(commands: commands)
    }

    static func arrow(_ points: [CGPoint]) -> ScenePath {
        guard points.count >= 2 else { return ScenePath() }
        let tip = points[points.count - 1], previous = points[points.count - 2]
        let length = hypot(tip.x - previous.x, tip.y - previous.y)
        guard length > 0 else { return ScenePath() }
        let ux = (tip.x - previous.x) / length, uy = (tip.y - previous.y) / length
        return ScenePath(commands: [.move(tip),
            .line(CGPoint(x: tip.x - ux * 8 - uy * 3.36, y: tip.y - uy * 8 + ux * 3.36)),
            .line(CGPoint(x: tip.x - ux * 8 + uy * 3.36, y: tip.y - uy * 8 - ux * 3.36)), .close])
    }
}

func number(_ value: CGFloat) -> String {
    String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), Double(value))
}
