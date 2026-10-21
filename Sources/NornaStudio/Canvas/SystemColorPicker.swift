import AppKit
import NornaKit
import SwiftUI

@MainActor
final class SystemColorPicker: NSObject, ObservableObject {
    private var updateColor: ((DiagramAccentColor) -> Void)?

    func show(color: Binding<DiagramAccentColor>) {
        updateColor = { color.wrappedValue = $0 }
        let panel = NSColorPanel.shared
        panel.color = CoreGraphicsDiagramPainter.color(color.wrappedValue.hex)
        panel.showsAlpha = false
        panel.isContinuous = true
        panel.setTarget(self)
        panel.setAction(#selector(changeColor(_:)))
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        guard updateColor != nil else { return }
        NSColorPanel.shared.close()
        updateColor = nil
    }

    @objc private func changeColor(_ sender: NSColorPanel) {
        guard let color = sender.color.usingColorSpace(.sRGB) else { return }
        let channel: (CGFloat) -> UInt8 = { UInt8((min(1, max(0, $0)) * 255).rounded()) }
        updateColor?(DiagramAccentColor(red: channel(color.redComponent), green: channel(color.greenComponent), blue: channel(color.blueComponent)))
    }
}
