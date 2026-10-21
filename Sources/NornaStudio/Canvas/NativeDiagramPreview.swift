import AppKit
import NornaKit
import SwiftUI

struct NativeDiagramPreview: NSViewRepresentable {
    let language: StudioLanguage
    let scene: DiagramScene?
    let theme: DiagramTheme
    let colorStyle: DiagramColorStyle
    let customAccent: DiagramAccentColor
    let paletteRevision: Int
    let showGrid: Bool
    let zoomRequest: Int
    let fitRequest: Int
    let onWidthChange: (CGFloat) -> Void

    func makeNSView(context: Context) -> DiagramCanvasView {
        let view = DiagramCanvasView()
        view.onWidthChange = onWidthChange
        view.setAccessibilityElement(true)
        view.setAccessibilityLabel(StudioLocalization.text("Swift 原生图表画布", language: language))
        view.setAccessibilityRole(.image)
        view.toolTip = StudioLocalization.text("拖动平移，双击适应画布，触控板捏合缩放，点击选择节点。", language: language)
        return view
    }

    func updateNSView(_ view: DiagramCanvasView, context: Context) {
        view.onWidthChange = onWidthChange
        view.setAccessibilityLabel(StudioLocalization.text("Swift 原生图表画布", language: language))
        view.toolTip = StudioLocalization.text("拖动平移，双击适应画布，触控板捏合缩放，点击选择节点。", language: language)
        view.setAccessibilityValue(view.selectedNode ?? "未选择节点".studioLocalized)
        if view.scene != scene {
            view.scene = scene
            view.selectedNode = nil
            view.fitDiagram()
        }
        view.theme = theme
        view.colorStyle = colorStyle
        view.customAccent = customAccent
        view.showGrid = showGrid
        if view.lastZoom != zoomRequest {
            view.zoom(by: pow(1.2, Double(zoomRequest - view.lastZoom)), at: CGPoint(x: view.bounds.midX, y: view.bounds.midY))
            view.lastZoom = zoomRequest
        }
        if view.lastFit != fitRequest {
            view.fitDiagram()
            view.lastFit = fitRequest
        }
        view.needsDisplay = true
    }
}

final class DiagramCanvasView: NSView {
    var scene: DiagramScene?
    var theme: DiagramTheme = .appleLight
    var colorStyle: DiagramColorStyle = .themed
    var customAccent: DiagramAccentColor = .norna
    var showGrid = false {
        didSet {
            if showGrid != oldValue { needsDisplay = true }
        }
    }
    var selectedNode: String?
    var lastZoom = 0
    var lastFit = 0
    private var scale: CGFloat = 1
    private var offset = CGPoint.zero
    private var fitting = true
    var onWidthChange: ((CGFloat) -> Void)?
    private var reportedWidth: CGFloat = 0
    private var dragStart: CGPoint?
    private var dragOffset = CGPoint.zero

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func layout() {
        super.layout()
        if fitting { fitDiagram() }
        let width = max(160, floor((bounds.width - 40) / 24) * 24)
        if width != reportedWidth {
            reportedWidth = width
            DispatchQueue.main.async { [weak self] in self?.onWidthChange?(width) }
        }
    }

    func fitDiagram() {
        fitting = true
        guard let scene, bounds.width > 0, bounds.height > 0 else { return }
        scale = max(0.01, min(1.25, min((bounds.width - 40) / scene.size.width, (bounds.height - 40) / scene.size.height)))
        offset = CGPoint(x: (bounds.width - scene.size.width * scale) / 2, y: (bounds.height - scene.size.height * scale) / 2)
        needsDisplay = true
    }

    func zoom(by factor: CGFloat, at point: CGPoint) {
        fitting = false
        let next = max(0.01, min(6, scale * factor))
        offset = CGPoint(x: point.x - (point.x - offset.x) * next / scale, y: point.y - (point.y - offset.y) * next / scale)
        scale = next
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        CoreGraphicsDiagramPainter.color(theme.background).setFill()
        bounds.fill()
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        if showGrid {
            let increasedContrast = theme == .appleLightHighContrast || theme == .appleDarkHighContrast
            let color = CoreGraphicsDiagramPainter.color(theme.colors(for: colorStyle, customAccent: customAccent).foreground)
            context.setFillColor(color.withAlphaComponent(increasedContrast ? 0.32 : 0.22).cgColor)
            for x in stride(from: CGFloat(10), to: bounds.width, by: 20) {
                for y in stride(from: CGFloat(10), to: bounds.height, by: 20) {
                    context.fillEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
                }
            }
        }
        guard let scene else { return }
        context.saveGState()
        context.translateBy(x: offset.x, y: offset.y)
        context.scaleBy(x: scale, y: scale)
        CoreGraphicsDiagramPainter.draw(scene, theme: theme, colorStyle: colorStyle, customAccent: customAccent, selectedNode: selectedNode)
        context.restoreGState()
        if let selectedNode, let node = scene.nodes.first(where: { $0.id == selectedNode }) {
            let text = "\(node.id) · \(node.label.replacingOccurrences(of: "\n", with: " "))" as NSString
            text.draw(at: CGPoint(x: 16, y: bounds.height - 28), withAttributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: CoreGraphicsDiagramPainter.color(theme.colors(for: colorStyle, customAccent: customAccent).accent),
                .backgroundColor: CoreGraphicsDiagramPainter.color(theme.background)
            ])
        } else if let selectedNode, let group = scene.groups.first(where: { $0.id == selectedNode }) {
            let text = StudioLocalization.format("子图 %@ · %@", group.id, group.label.replacingOccurrences(of: "\n", with: " ")) as NSString
            text.draw(at: CGPoint(x: 16, y: bounds.height - 28), withAttributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: CoreGraphicsDiagramPainter.color(theme.colors(for: colorStyle, customAccent: customAccent).accent),
                .backgroundColor: CoreGraphicsDiagramPainter.color(theme.background)
            ])
        } else if let selectedNode, let primitive = scene.primitives.first(where: { $0.id == selectedNode }) {
            let label = primitive.label.replacingOccurrences(of: "\n", with: " ")
            let text = "\(selectedNode) · \(label)" as NSString
            text.draw(at: CGPoint(x: 16, y: bounds.height - 28), withAttributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: CoreGraphicsDiagramPainter.color(theme.colors(for: colorStyle, customAccent: customAccent).accent),
                .backgroundColor: CoreGraphicsDiagramPainter.color(theme.background)
            ])
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if event.clickCount == 2 { fitDiagram(); return }
        dragStart = convert(event.locationInWindow, from: nil)
        dragOffset = offset
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let point = convert(event.locationInWindow, from: nil)
        fitting = false
        offset = CGPoint(x: dragOffset.x + point.x - start.x, y: dragOffset.y + point.y - start.y)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer { dragStart = nil }
        let point = convert(event.locationInWindow, from: nil)
        guard let start = dragStart, hypot(point.x - start.x, point.y - start.y) < 4 else { return }
        let local = CGPoint(x: (point.x - offset.x) / scale, y: (point.y - offset.y) / scale)
        selectedNode = scene?.nodes.reversed().first(where: { $0.frame.contains(local) })?.id
            ?? scene?.groups.reversed().first(where: { $0.frame.contains(local) })?.id
            ?? scene?.primitives.reversed().first(where: { $0.id != nil && $0.bounds.contains(local) })?.id
        setAccessibilityValue(selectedNode ?? "未选择节点".studioLocalized)
        needsDisplay = true
    }

    override func magnify(with event: NSEvent) {
        zoom(by: max(0.1, 1 + event.magnification), at: convert(event.locationInWindow, from: nil))
    }

    override func scrollWheel(with event: NSEvent) {
        if !event.modifierFlags.intersection([.command, .control]).isEmpty {
            zoom(by: exp(event.scrollingDeltaY * 0.015), at: convert(event.locationInWindow, from: nil))
        } else {
            fitting = false
            offset.x += event.scrollingDeltaX
            offset.y += event.scrollingDeltaY
            needsDisplay = true
        }
    }

    override func keyDown(with event: NSEvent) {
        switch event.charactersIgnoringModifiers {
        case "+", "=": zoom(by: 1.2, at: CGPoint(x: bounds.midX, y: bounds.midY))
        case "-": zoom(by: 1 / 1.2, at: CGPoint(x: bounds.midX, y: bounds.midY))
        case "0": fitDiagram()
        default: super.keyDown(with: event)
        }
    }
}
