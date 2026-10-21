import Foundation

public enum SVGExporter {
    public static func export(_ scene: DiagramScene, theme: DiagramTheme, colorStyle: DiagramColorStyle = .neutral,
                              customAccent: DiagramAccentColor = .norna, background: DiagramExportBackground = .theme,
                              padding: CGFloat = 0) -> String {
        let c = theme.colors(for: colorStyle, customAccent: customAccent)
        var elements: [String] = []
        let path: (ScenePath, String) -> String = { "<path d=\"\($0.svg)\" \($1)/>" }
        elements += scene.primitives.map { VectorSceneRenderer.svg($0, theme: theme, colorStyle: colorStyle, customAccent: customAccent) }
        for group in scene.groups {
            elements.append("<g class=\"norna-cluster\" data-id=\"\(escape(group.id))\"><title>\(escape(group.label))</title>")
            elements.append(path(.roundedRectangle(group.frame, radius: DiagramStyle.cornerRadius), "fill=\"\(c.surfaceAlt)\" fill-opacity=\"0.5\" stroke=\"\(c.border)\" stroke-width=\"1\""))
            elements.append("</g>")
        }
        for edge in scene.edges where edge.style != .invisible {
            let dash = edge.style == .dashed ? " stroke-dasharray=\"3 4\"" : ""
            elements.append(path(.edge(edge.points), "fill=\"none\" stroke=\"\(c.line)\" stroke-width=\"\(edge.style == .thick ? 2.5 : 1)\" stroke-linecap=\"round\" stroke-linejoin=\"round\"\(dash)"))
            for (marker, points) in [(edge.startMarker, Array(edge.points.reversed())), (edge.endMarker ?? (edge.arrow ? .arrow : .none), edge.points)] where marker != .none {
                elements.append(path(.marker(marker, points: points), "fill=\"\(marker == .cross ? "none" : marker == .circle ? c.background : c.line)\" stroke=\"\(c.line)\" stroke-width=\"1\""))
            }
        }
        for group in scene.groups {
            elements.append(text(group.titleLines, center: CGPoint(x: group.titleFrame.midX, y: group.titleFrame.midY), size: DiagramStyle.fontSize, lineHeight: DiagramStyle.lineHeight, color: c.muted))
        }
        for node in scene.nodes {
            elements.append("<g><title>\(escape(node.id))</title>")
            elements.append(path(.node(node), "fill=\"\(c.surface)\" stroke=\"\(c.border)\" stroke-width=\"1\""))
            elements.append(path(.detail(node), "fill=\"none\" stroke=\"\(c.border)\" stroke-width=\"1\""))
            let dy = node.shape == .cylinder ? min(12, max(6, node.frame.width / 14)) / 2 : 0
            elements.append(text(node.lines, center: CGPoint(x: node.frame.midX, y: node.frame.midY + dy), size: DiagramStyle.fontSize, lineHeight: DiagramStyle.lineHeight, color: c.foreground))
            elements.append("</g>")
        }
        for edge in scene.edges where !edge.label.isEmpty && edge.style != .invisible {
            elements.append(path(.roundedRectangle(edge.labelFrame, radius: 3), "fill=\"\(c.background)\""))
            elements.append(text(edge.label.components(separatedBy: "\n"), center: CGPoint(x: edge.labelFrame.midX, y: edge.labelFrame.midY), size: DiagramStyle.edgeFontSize, lineHeight: DiagramStyle.edgeLineHeight, color: c.foreground))
        }
        let width = scene.size.width + padding * 2, height = scene.size.height + padding * 2
        let canvas = background == .transparent ? "" : "<rect x=\"\(number(-padding))\" y=\"\(number(-padding))\" width=\"\(number(width))\" height=\"\(number(height))\" fill=\"\(c.background)\"/>"
        return """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(number(width))" height="\(number(height))" viewBox="\(number(-padding)) \(number(-padding)) \(number(width)) \(number(height))" role="img" aria-label="\(scene.kind.title)">
        <title>\(scene.kind.title)</title>
        \(canvas)
        <g font-family="-apple-system, BlinkMacSystemFont, sans-serif">\(elements.joined(separator: "\n"))</g>
        </svg>
        """
    }

    private static func text(_ lines: [String], center: CGPoint, size: CGFloat, lineHeight: CGFloat, color: String) -> String {
        InlineText.svg(lines, frame: CGRect(origin: center, size: .zero), size: size, lineHeight: lineHeight, color: color)
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
