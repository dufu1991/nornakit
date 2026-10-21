import Foundation

public enum SceneColor: Equatable, Sendable {
    case none, background, foreground, muted, line, surface, surfaceAlt, border, accent
    case series(Int), onSeries(Int), literal(String)

    func hex(_ theme: DiagramTheme, colorStyle: DiagramColorStyle = .neutral, customAccent: DiagramAccentColor = .norna) -> String? {
        let c = theme.colors(for: colorStyle, customAccent: customAccent)
        switch self {
        case .none: return nil
        case .background: return c.background
        case .foreground: return c.foreground
        case .muted: return c.muted
        case .line: return c.line
        case .surface: return c.surface
        case .surfaceAlt: return c.surfaceAlt
        case .border: return c.border
        case .accent: return c.accent
        case .literal(let value): return value
        case .series(let index):
            let colors = c.series
            return colors[((index % colors.count) + colors.count) % colors.count]
        case .onSeries(let index):
            let value = UInt32(SceneColor.series(index).hex(theme, colorStyle: colorStyle, customAccent: customAccent)!.dropFirst(), radix: 16)!
            let linear: (UInt32) -> Double = {
                let channel = Double($0 & 255) / 255
                return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
            }
            let luminance = 0.2126 * linear(value >> 16) + 0.7152 * linear(value >> 8) + 0.0722 * linear(value)
            return (luminance + 0.05) / 0.05 >= 1.05 / (luminance + 0.05) ? "#000000" : "#ffffff"
        }
    }
}

public struct VectorStyle: Equatable, Sendable {
    public var fill: SceneColor = .none
    public var stroke: SceneColor = .border
    public var lineWidth: CGFloat = 1
    public var dash: [CGFloat] = []
    public var opacity: CGFloat = 1
}

public enum TextAlignment: Equatable, Sendable { case leading, center, trailing }

public struct SceneText: Equatable, Sendable {
    public let text: String
    public let frame: CGRect
    public var size: CGFloat = 16
    public var color: SceneColor = .foreground
    public var alignment: TextAlignment = .center
    public var bold: Bool = false
    public var mono: Bool = false
}

public enum VectorGeometry: Equatable, Sendable {
    case rectangle(CGRect, CGFloat), ellipse(CGRect), path([PathCommand]), text(SceneText)
}

public struct ScenePrimitive: Equatable, Sendable {
    public let geometry: VectorGeometry
    public var style: VectorStyle = VectorStyle()
    public var id: String? = nil
    public var label: String = ""

    public var bounds: CGRect {
        switch geometry {
        case .rectangle(let r, _), .ellipse(let r): return r
        case .text(let text): return text.frame
        case .path(let commands): return ScenePath(commands: commands).cgPath.boundingBoxOfPath
        }
    }
}

final class SceneBuilder {
    var primitives: [ScenePrimitive] = []
    let kind: DiagramKind
    init(_ kind: DiagramKind) { self.kind = kind }

    func rect(_ r: CGRect, fill: SceneColor = .surface, stroke: SceneColor = .border, radius: CGFloat = DiagramStyle.cornerRadius,
              opacity: CGFloat = 1, dash: [CGFloat] = [], id: String? = nil, label: String = "") {
        primitives.append(ScenePrimitive(geometry: .rectangle(r, radius), style: VectorStyle(fill: fill, stroke: stroke, dash: dash, opacity: opacity), id: id, label: label))
    }

    func ellipse(_ r: CGRect, fill: SceneColor = .surface, stroke: SceneColor = .border, opacity: CGFloat = 1, id: String? = nil, label: String = "") {
        primitives.append(ScenePrimitive(geometry: .ellipse(r), style: VectorStyle(fill: fill, stroke: stroke, opacity: opacity), id: id, label: label))
    }

    func path(_ commands: [PathCommand], fill: SceneColor = .none, stroke: SceneColor = .line,
              width: CGFloat = 1, dash: [CGFloat] = [], opacity: CGFloat = 1, id: String? = nil) {
        primitives.append(ScenePrimitive(geometry: .path(commands), style: VectorStyle(fill: fill, stroke: stroke, lineWidth: width, dash: dash, opacity: opacity), id: id))
    }

    func line(_ points: [CGPoint], color: SceneColor = .line, width: CGFloat = 1, dash: [CGFloat] = [], arrow: Bool = false, open: Bool = false, id: String? = nil) {
        path(ScenePath.edge(points).commands, stroke: color, width: width, dash: dash, id: id)
        if arrow {
            if open, points.count >= 2 {
                let triangle = ScenePath.arrow(points).commands
                if case .line(let a) = triangle[1], case .line(let b) = triangle[2], let tip = points.last {
                    path([.move(a), .line(tip), .line(b)], stroke: color)
                }
            } else { path(ScenePath.arrow(points).commands, fill: color, stroke: .none) }
        }
    }

    func text(_ text: String, _ r: CGRect, size: CGFloat = 16, color: SceneColor = .foreground,
              align: TextAlignment = .center, bold: Bool = false, mono: Bool = false) {
        let label = DiagramSyntax.label(text)
        let lines = TextMeasurement.lines(label, maxWidth: max(8, r.width), size: size, bold: bold, mono: mono)
        let font = min(size, max(8, r.height / max(1, CGFloat(lines.count)) / 1.4))
        primitives.append(ScenePrimitive(geometry: .text(SceneText(text: lines.joined(separator: "\n"), frame: r, size: font, color: color, alignment: align, bold: bold, mono: mono))))
    }

    func box(_ text: String, _ r: CGRect, fill: SceneColor = .surface, radius: CGFloat = DiagramStyle.cornerRadius, id: String? = nil, size: CGFloat = 16) {
        rect(r, fill: fill, radius: radius, id: id, label: text)
        self.text(text, r.insetBy(dx: 8, dy: 6), size: size)
    }

    func title(_ text: String, width: CGFloat) -> CGFloat {
        guard !text.isEmpty else { return 16 }
        self.text(text, CGRect(x: 16, y: 12, width: width - 32, height: 32), size: 20, bold: true)
        return 60
    }

    func scene(width: CGFloat, height: CGFloat) -> DiagramScene {
        let bounds = primitives.reduce(CGRect.null) { $1.bounds.isNull ? $0 : $0.union($1.bounds) }
        let dx = bounds.isNull ? 0 : max(0, 8 - bounds.minX), dy = bounds.isNull ? 0 : max(0, 8 - bounds.minY)
        let shifted = primitives.map { primitive -> ScenePrimitive in
            let geometry: VectorGeometry
            let shift: (CGPoint) -> CGPoint = { CGPoint(x: $0.x + dx, y: $0.y + dy) }
            switch primitive.geometry {
            case .rectangle(let r, let radius): geometry = .rectangle(r.offsetBy(dx: dx, dy: dy), radius)
            case .ellipse(let r): geometry = .ellipse(r.offsetBy(dx: dx, dy: dy))
            case .text(let value): geometry = .text(SceneText(text: value.text, frame: value.frame.offsetBy(dx: dx, dy: dy), size: value.size, color: value.color, alignment: value.alignment, bold: value.bold, mono: value.mono))
            case .path(let commands): geometry = .path(commands.map { command in
                switch command {
                case .move(let p): return .move(shift(p))
                case .line(let p): return .line(shift(p))
                case .quad(let a, let z): return .quad(shift(a), shift(z))
                case .cubic(let a, let c, let z): return .cubic(shift(a), shift(c), shift(z))
                case .close: return .close
                }
            })
            }
            return ScenePrimitive(geometry: geometry, style: primitive.style, id: primitive.id, label: primitive.label)
        }
        return DiagramScene(size: CGSize(width: max(32, max(width, bounds.isNull ? 0 : bounds.maxX + 8) + dx), height: max(32, max(height, bounds.isNull ? 0 : bounds.maxY + 8) + dy)), nodes: [], edges: [], primitives: shifted, kind: kind)
    }
}
