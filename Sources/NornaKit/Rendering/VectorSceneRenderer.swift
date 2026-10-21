import AppKit

enum VectorSceneRenderer {
    static func path(_ geometry: VectorGeometry) -> CGPath? {
        switch geometry {
        case .rectangle(let r, let radius): return ScenePath.roundedRectangle(r, radius: radius).cgPath
        case .ellipse(let r): return CGPath(ellipseIn: r, transform: nil)
        case .path(let commands): return ScenePath(commands: commands).cgPath
        case .text: return nil
        }
    }

    static func draw(_ primitive: ScenePrimitive, theme: DiagramTheme, colorStyle: DiagramColorStyle = .neutral, customAccent: DiagramAccentColor = .norna, selected: String?) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.setAlpha(primitive.style.opacity)
        if case .text(let text) = primitive.geometry {
            InlineText.draw(text.text.components(separatedBy: "\n"), frame: text.frame, size: text.size,
                lineHeight: text.size * 1.4,
                color: CoreGraphicsDiagramPainter.color(text.color.hex(theme, colorStyle: colorStyle, customAccent: customAccent)!),
                alignment: text.alignment, bold: text.bold, mono: text.mono)
            return
        }
        guard let path = path(primitive.geometry) else { return }
        let fill = primitive.style.fill.hex(theme, colorStyle: colorStyle, customAccent: customAccent)
        let stroke = primitive.id != nil && primitive.id == selected ? theme.colors(for: colorStyle, customAccent: customAccent).accent : primitive.style.stroke.hex(theme, colorStyle: colorStyle, customAccent: customAccent)
        if let fill { context.setFillColor(CoreGraphicsDiagramPainter.color(fill).cgColor) }
        if let stroke { context.setStrokeColor(CoreGraphicsDiagramPainter.color(stroke).cgColor) }
        context.setLineWidth(primitive.id != nil && primitive.id == selected ? 2 : primitive.style.lineWidth)
        context.setLineDash(phase: 0, lengths: primitive.style.dash)
        context.addPath(path)
        if fill != nil && stroke != nil { context.drawPath(using: .fillStroke) }
        else if fill != nil { context.fillPath() }
        else if stroke != nil { context.strokePath() }
    }

    static func svg(_ primitive: ScenePrimitive, theme: DiagramTheme, colorStyle: DiagramColorStyle = .neutral, customAccent: DiagramAccentColor = .norna) -> String {
        let escape = SVGExporter.escape
        let style = primitive.style
        let attributes = "fill=\"\(style.fill.hex(theme, colorStyle: colorStyle, customAccent: customAccent) ?? "none")\" stroke=\"\(style.stroke.hex(theme, colorStyle: colorStyle, customAccent: customAccent) ?? "none")\" stroke-width=\"\(number(style.lineWidth))\" opacity=\"\(number(style.opacity))\" stroke-linecap=\"round\" stroke-linejoin=\"round\""
            + (style.dash.isEmpty ? "" : " stroke-dasharray=\"\(style.dash.map(number).joined(separator: " "))\"")
        let body: String
        switch primitive.geometry {
        case .rectangle(let r, let radius):
            body = "<rect x=\"\(number(r.minX))\" y=\"\(number(r.minY))\" width=\"\(number(r.width))\" height=\"\(number(r.height))\" rx=\"\(number(radius))\" \(attributes)/>"
        case .ellipse(let r):
            body = "<ellipse cx=\"\(number(r.midX))\" cy=\"\(number(r.midY))\" rx=\"\(number(r.width / 2))\" ry=\"\(number(r.height / 2))\" \(attributes)/>"
        case .path(let commands): body = "<path d=\"\(ScenePath(commands: commands).svg)\" \(attributes)/>"
        case .text(let text):
            body = InlineText.svg(text.text.components(separatedBy: "\n"), frame: text.frame, size: text.size,
                lineHeight: text.size * 1.4,
                color: text.color.hex(theme, colorStyle: colorStyle, customAccent: customAccent) ?? theme.colors(for: colorStyle, customAccent: customAccent).foreground,
                alignment: text.alignment, bold: text.bold, mono: text.mono)
        }
        guard let id = primitive.id else { return body }
        return "<g data-id=\"\(escape(id))\"><title>\(escape(primitive.label))</title>\(body)</g>"
    }
}
