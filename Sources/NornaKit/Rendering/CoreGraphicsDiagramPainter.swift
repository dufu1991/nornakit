import AppKit

public enum CoreGraphicsDiagramPainter {
    /// Draw into a flipped AppKit coordinate system, in scene coordinates.
    public static func draw(_ scene: DiagramScene, theme: DiagramTheme, colorStyle: DiagramColorStyle = .neutral, customAccent: DiagramAccentColor = .norna, selectedNode: String? = nil) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let c = theme.colors(for: colorStyle, customAccent: customAccent)
        context.saveGState()
        context.setLineCap(.round)
        context.setLineJoin(.round)
        for primitive in scene.primitives { VectorSceneRenderer.draw(primitive, theme: theme, colorStyle: colorStyle, customAccent: customAccent, selected: selectedNode) }
        for group in scene.groups {
            context.setFillColor(color(c.surfaceAlt).withAlphaComponent(0.5).cgColor)
            context.setStrokeColor(color(group.id == selectedNode ? c.accent : c.border).cgColor)
            context.setLineWidth(group.id == selectedNode ? 2 : 1)
            context.addPath(ScenePath.roundedRectangle(group.frame, radius: DiagramStyle.cornerRadius).cgPath)
            context.drawPath(using: .fillStroke)
        }
        for edge in scene.edges where edge.style != .invisible {
            context.setStrokeColor(color(c.line).cgColor)
            context.setLineWidth(edge.style == .thick ? 2.5 : 1)
            context.setLineDash(phase: 0, lengths: edge.style == .dashed ? [3, 4] : [])
            context.addPath(ScenePath.edge(edge.points).cgPath)
            context.strokePath()
            context.setLineDash(phase: 0, lengths: [])
            context.setLineWidth(1)
            for (marker, points) in [(edge.startMarker, Array(edge.points.reversed())), (edge.endMarker ?? (edge.arrow ? .arrow : .none), edge.points)] where marker != .none {
                context.addPath(ScenePath.marker(marker, points: points).cgPath)
                context.setFillColor(color(marker == .circle ? c.background : c.line).cgColor)
                context.drawPath(using: marker == .cross ? .stroke : .fillStroke)
            }
        }
        for group in scene.groups {
            drawText(group.titleLines, center: CGPoint(x: group.titleFrame.midX, y: group.titleFrame.midY),
                     size: DiagramStyle.fontSize, lineHeight: DiagramStyle.lineHeight, color: color(c.muted))
        }
        for node in scene.nodes {
            let selected = node.id == selectedNode
            context.setFillColor(color(node.appearance.fill ?? c.surface).cgColor)
            context.setStrokeColor(color(selected ? c.accent : node.appearance.stroke ?? c.border).cgColor)
            context.setLineWidth(selected ? 2 : node.appearance.lineWidth ?? 1)
            context.setLineDash(phase: 0, lengths: [])
            context.addPath(ScenePath.node(node).cgPath)
            context.drawPath(using: .fillStroke)
            context.setLineDash(phase: 0, lengths: [])
            context.addPath(ScenePath.detail(node).cgPath)
            context.strokePath()
            let dy = node.shape == .cylinder ? min(12, max(6, node.frame.width / 14)) / 2 : 0
            drawText(node.lines, center: CGPoint(x: node.frame.midX, y: node.frame.midY + dy), size: DiagramStyle.fontSize, lineHeight: DiagramStyle.lineHeight, color: color(node.appearance.color ?? c.foreground))
        }
        for edge in scene.edges where !edge.label.isEmpty && edge.style != .invisible {
            context.setLineDash(phase: 0, lengths: [])
            context.setFillColor(color(c.background).cgColor)
            context.addPath(ScenePath.roundedRectangle(edge.labelFrame, radius: 3).cgPath)
            context.fillPath()
            drawText(edge.label.components(separatedBy: "\n"), center: CGPoint(x: edge.labelFrame.midX, y: edge.labelFrame.midY), size: DiagramStyle.edgeFontSize, lineHeight: DiagramStyle.edgeLineHeight, color: color(c.foreground))
        }
        context.restoreGState()
    }

    public static func color(_ hex: String) -> NSColor {
        let value = UInt32(hex.dropFirst(), radix: 16)!
        return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
                       green: CGFloat((value >> 8) & 255) / 255,
                       blue: CGFloat(value & 255) / 255, alpha: 1)
    }

    private static func drawText(_ lines: [String], center: CGPoint, size: CGFloat, lineHeight: CGFloat, color: NSColor) {
        InlineText.draw(lines, frame: CGRect(origin: center, size: .zero), size: size, lineHeight: lineHeight, color: color)
    }
}
